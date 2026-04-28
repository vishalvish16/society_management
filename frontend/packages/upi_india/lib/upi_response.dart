// Class to process the response of upi request.
class UpiResponse {
  /// It is the Transaction ID from the response.
  String? transactionId;

  /// responseCode is the UPI Response code.
  String? responseCode;

  /// approvalRefNo is the UPI Approval reference number (beneficiary).
  String? approvalRefNo;

  /// status gives the status of Transaction: success, failure, submitted.
  /// DO NOT use the string directly. Instead use [UpiPaymentStatus]
  String? status;

  /// txnRef gives the Transaction Reference ID passed in input.
  String? transactionRefId;

  UpiResponse(String responseString) {
    final parts = responseString.split('&');
    for (final part in parts) {
      final kv = part.split('=');
      if (kv.isEmpty) continue;
      final key = kv[0];
      final value = kv.length > 1 ? kv[1] : '';

      if (key.toLowerCase() == "txnid") {
        transactionId = _getValue(value);
      } else if (key.toLowerCase() == "responsecode") {
        responseCode = _getValue(value);
      } else if (key.toLowerCase() == "approvalrefno") {
        approvalRefNo = _getValue(value);
      } else if (key.toLowerCase() == "status") {
        if (value.toLowerCase().contains("success")) {
          status = UpiPaymentStatus.SUCCESS;
        } else if (value.toLowerCase().contains("fail")) {
          status = UpiPaymentStatus.FAILURE;
        } else if (value.toLowerCase().contains("submit")) {
          status = UpiPaymentStatus.SUBMITTED;
        } else {
          status = UpiPaymentStatus.OTHER;
        }
      } else if (key.toLowerCase() == "txnref") {
        transactionRefId = _getValue(value);
      }
    }
  }

  String? _getValue(String? s) {
    if (s == null) return s;
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower == 'null' || lower == 'undefined') return null;
    return s;
  }
}

// This class is to match the status of transaction.
// It is advised to use this class to compare the status rather than doing string comparision.
class UpiPaymentStatus {
  static const String SUCCESS = 'success';
  static const String SUBMITTED = 'submitted';
  static const String FAILURE = 'failure';
  static const String OTHER = 'other';
}

