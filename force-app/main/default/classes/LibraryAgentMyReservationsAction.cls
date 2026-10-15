global with sharing class LibraryAgentMyReservationsAction {
  global class Request {
    @InvocableVariable(required=true)
    global String sessionToken;
  }
  global class ReservationResult {
    @InvocableVariable
    public String reservationId;
    @InvocableVariable
    public String bookTitle;
    @InvocableVariable
    public String status;
    @InvocableVariable
    public Datetime reservationDate;
    @InvocableVariable
    public Decimal queuePosition;
    @InvocableVariable
    public Datetime readyDate;
    @InvocableVariable
    public Datetime expiryDate;
  }

  @InvocableMethod(
    label='Get My Reservations'
    description='Use only when the currently authenticated member asks about their own reservations. Invoke this action before answering; identity is derived from the server-validated session token and never accepts a Member ID.'
  )
  global static List<ReservationResult> execute(List<Request> requests) {
    String token = requests == null || requests.isEmpty()
      ? null
      : requests[0].sessionToken;
    List<ReservationResult> output = new List<ReservationResult>();
    for (
      LibraryMemberSessionController.ReservationDTO reservation : LibraryMemberSessionController.getMyReservations(
        token
      )
    ) {
      ReservationResult result = new ReservationResult();
      result.reservationId = String.valueOf(reservation.id);
      result.bookTitle = reservation.bookName;
      result.status = reservation.status;
      result.reservationDate = reservation.reservationDate;
      result.queuePosition = reservation.queuePosition;
      result.readyDate = reservation.readyDate;
      result.expiryDate = reservation.expiryDate;
      output.add(result);
    }
    return output;
  }
}
