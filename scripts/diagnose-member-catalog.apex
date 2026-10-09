User memberUser = [SELECT Id,Username FROM User WHERE Id='005gK00008TFOSpQAP' LIMIT 1];
System.runAs(memberUser) {
    try {
        List<Book__c> books = LibraryMemberController.searchCatalog(null, null, null, 20, 1);
        System.debug(LoggingLevel.ERROR, 'MEMBER_CATALOG_COUNT=' + books.size());
        if (!books.isEmpty()) System.debug(LoggingLevel.ERROR, 'MEMBER_CATALOG_FIRST=' + books[0].Name);
    } catch (Exception ex) {
        System.debug(LoggingLevel.ERROR, 'MEMBER_CATALOG_ERROR=' + ex.getTypeName() + ': ' + ex.getMessage());
    }
}
