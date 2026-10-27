public without sharing class LibraryBranchService {
  private static final String BRANCH_OPERATION = 'Library Branch';
  private static final String INVENTORY_OPERATION = 'Branch Inventory';
  private static final String TRANSFER_OPERATION = 'Branch Transfer';

  public class BranchDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String code;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String address;
    @AuraEnabled
    public String timezone;
    @AuraEnabled
    public Integer copyCount;
  }
  public class TransferDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id copyId;
    @AuraEnabled
    public Id sourceBranchId;
    @AuraEnabled
    public Id destinationBranchId;
    @AuraEnabled
    public String status;
  }

  public static Id createBranch(
    String code,
    String name,
    String address,
    String timezone
  ) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    if (String.isBlank(code) || String.isBlank(name))
      throw new AuraHandledException('Branch code and name are required.');
    Library_Scan_Transaction__c row = new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'BRANCH:' + code.trim().toUpperCase(),
      Operation__c = BRANCH_OPERATION,
      Status__c = 'Active',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'c' => code.trim().toUpperCase().left(20),
            'n' => name.trim().left(80),
            'a' => String.isBlank(address) ? null : address.trim().left(100),
            't' => String.isBlank(timezone) ? 'UTC' : timezone.trim().left(40)
          }
        )
        .left(255)
    );
    try {
      Database.insert(row, AccessLevel.SYSTEM_MODE);
    } catch (DmlException error) {
      throw new AuraHandledException('A branch with that code already exists.');
    }
    return row.Id;
  }

  public static List<BranchDTO> getBranches(String sessionToken) {
    LibraryMemberSessionService.getCurrentMember(sessionToken);
    return listBranches();
  }

  public static List<BranchDTO> getManagedBranches() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    return listBranches();
  }

  private static List<BranchDTO> listBranches() {
    Map<Id, Integer> counts = new Map<Id, Integer>();
    for (Library_Scan_Transaction__c row : [
      SELECT Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :INVENTORY_OPERATION AND Status__c = 'Assigned'
      LIMIT 2000
    ]) {
      Id branchId = parseId(parse(row.Result_Message__c).get('b'));
      if (branchId != null)
        counts.put(
          branchId,
          (counts.containsKey(branchId) ? counts.get(branchId) : 0) + 1
        );
    }
    List<BranchDTO> result = new List<BranchDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :BRANCH_OPERATION AND Status__c = 'Active'
      ORDER BY Created_At__c ASC
      LIMIT 200
    ]) {
      Map<String, Object> payload = parse(row.Result_Message__c);
      BranchDTO dto = new BranchDTO();
      dto.id = row.Id;
      dto.code = stringValue(payload.get('c'));
      dto.name = stringValue(payload.get('n'));
      dto.address = stringValue(payload.get('a'));
      dto.timezone = stringValue(payload.get('t'));
      dto.copyCount = counts.containsKey(row.Id) ? counts.get(row.Id) : 0;
      result.add(dto);
    }
    return result;
  }

  public static Id assignCopy(Id copyId, Id branchId) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    verifyCopy(copyId);
    verifyBranch(branchId);
    String key = 'BRANCH_INV:' + String.valueOf(copyId);
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id
      FROM Library_Scan_Transaction__c
      WHERE Idempotency_Key__c = :key AND Operation__c = :INVENTORY_OPERATION
      LIMIT 1
    ];
    Library_Scan_Transaction__c row = rows.isEmpty()
      ? new Library_Scan_Transaction__c(
          Idempotency_Key__c = key,
          Operation__c = INVENTORY_OPERATION,
          Created_At__c = System.now()
        )
      : rows[0];
    row.Status__c = 'Assigned';
    row.Result_Message__c = JSON.serialize(
        new Map<String, Object>{
          'c' => String.valueOf(copyId),
          'b' => String.valueOf(branchId)
        }
      )
      .left(255);
    Database.upsert(row, AccessLevel.SYSTEM_MODE);
    return row.Id;
  }

  public static TransferDTO requestTransfer(Id copyId, Id destinationBranchId) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    verifyCopy(copyId);
    verifyBranch(destinationBranchId);
    Library_Scan_Transaction__c inventory = inventoryRow(copyId);
    Id sourceBranchId = parseId(parse(inventory.Result_Message__c).get('b'));
    if (sourceBranchId == null || sourceBranchId == destinationBranchId)
      throw new AuraHandledException('Choose a different destination branch.');
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Operation__c = :TRANSFER_OPERATION
        AND Status__c IN ('Requested', 'In Transit')
      LIMIT 2000
    ])
      if (parseId(parse(row.Result_Message__c).get('c')) == copyId)
        throw new AuraHandledException(
          'This copy already has an active transfer.'
        );
    Library_Scan_Transaction__c transfer = new Library_Scan_Transaction__c(
      Idempotency_Key__c = 'TRANSFER:' +
        String.valueOf(copyId) +
        ':' +
        String.valueOf(Crypto.getRandomLong()),
      Operation__c = TRANSFER_OPERATION,
      Status__c = 'Requested',
      Created_At__c = System.now(),
      Result_Message__c = JSON.serialize(
          new Map<String, Object>{
            'c' => String.valueOf(copyId),
            's' => String.valueOf(sourceBranchId),
            'd' => String.valueOf(destinationBranchId)
          }
        )
        .left(255)
    );
    Database.insert(transfer, AccessLevel.SYSTEM_MODE);
    return toTransfer(transfer);
  }

  public static void shipTransfer(Id transferId) {
    updateTransfer(transferId, 'In Transit');
  }
  public static void receiveTransfer(Id transferId) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Library_Scan_Transaction__c transfer = transferRow(transferId);
    Map<String, Object> payload = parse(transfer.Result_Message__c);
    Id copyId = parseId(payload.get('c'));
    Id destination = parseId(payload.get('d'));
    assignCopy(copyId, destination);
    transfer.Status__c = 'Received';
    Database.update(transfer, AccessLevel.SYSTEM_MODE);
  }
  public static List<TransferDTO> getTransfers() {
    LibraryPolicyService.require('Manage_Library_Catalog');
    List<TransferDTO> result = new List<TransferDTO>();
    for (Library_Scan_Transaction__c row : [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Operation__c = :TRANSFER_OPERATION
      ORDER BY Created_At__c DESC
      LIMIT 200
    ])
      result.add(toTransfer(row));
    return result;
  }

  private static void updateTransfer(Id transferId, String status) {
    LibraryPolicyService.require('Manage_Library_Catalog');
    Library_Scan_Transaction__c row = transferRow(transferId);
    if (row.Status__c != 'Requested' && status == 'In Transit')
      throw new AuraHandledException(
        'Only requested transfers can be shipped.'
      );
    row.Status__c = status;
    Database.update(row, AccessLevel.SYSTEM_MODE);
  }
  private static Library_Scan_Transaction__c transferRow(Id id) {
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Status__c, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE Id = :id AND Operation__c = :TRANSFER_OPERATION
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('The transfer could not be found.');
    return rows[0];
  }
  private static Library_Scan_Transaction__c inventoryRow(Id copyId) {
    List<Library_Scan_Transaction__c> rows = [
      SELECT Id, Result_Message__c
      FROM Library_Scan_Transaction__c
      WHERE
        Idempotency_Key__c = :('BRANCH_INV:' + String.valueOf(copyId))
        AND Operation__c = :INVENTORY_OPERATION
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('Assign the copy to a branch first.');
    return rows[0];
  }
  private static void verifyCopy(Id copyId) {
    if (
      copyId == null ||
      [SELECT COUNT() FROM Book_Copy__c WHERE Id = :copyId] == 0
    )
      throw new AuraHandledException('The copy could not be found.');
  }
  private static void verifyBranch(Id branchId) {
    if (
      branchId == null ||
      [
        SELECT COUNT()
        FROM Library_Scan_Transaction__c
        WHERE
          Id = :branchId
          AND Operation__c = :BRANCH_OPERATION
          AND Status__c = 'Active'
      ] == 0
    )
      throw new AuraHandledException('The branch could not be found.');
  }
  private static TransferDTO toTransfer(Library_Scan_Transaction__c row) {
    Map<String, Object> p = parse(row.Result_Message__c);
    TransferDTO dto = new TransferDTO();
    dto.id = row.Id;
    dto.copyId = parseId(p.get('c'));
    dto.sourceBranchId = parseId(p.get('s'));
    dto.destinationBranchId = parseId(p.get('d'));
    dto.status = row.Status__c;
    return dto;
  }
  private static Map<String, Object> parse(String raw) {
    if (String.isBlank(raw))
      return new Map<String, Object>();
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(raw);
    } catch (Exception ignored) {
      return new Map<String, Object>();
    }
  }
  private static Id parseId(Object value) {
    try {
      return value == null ? null : Id.valueOf(String.valueOf(value));
    } catch (Exception ignored) {
      return null;
    }
  }
  private static String stringValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
