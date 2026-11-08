enum RequestCheckResult { confirmed, notFound, uncertain }

class RequestVerificationLogic {
  static RequestCheckResult check({
    required String requestId,
    required Map<String, dynamic>? requestValue,
    required Map<String, dynamic>? orderValue,
  }) {
    if (requestId.trim().isEmpty) {
      return RequestCheckResult.uncertain;
    }

    if (requestValue == null) {
      return RequestCheckResult.notFound;
    }

    final orderId = requestValue['orderId'];

    if (requestValue['id'] != requestId ||
        orderId is! String ||
        orderId.isEmpty) {
      return RequestCheckResult.uncertain;
    }

    if (orderValue == null) {
      return RequestCheckResult.uncertain;
    }

    if (orderValue['id'] != orderId || orderValue['requestId'] != requestId) {
      return RequestCheckResult.uncertain;
    }

    return RequestCheckResult.confirmed;
  }
}
