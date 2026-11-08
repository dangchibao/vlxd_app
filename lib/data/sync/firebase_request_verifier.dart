import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestVerificationStatus { confirmed, notFound, uncertain }

class RequestVerification {
  final RequestVerificationStatus status;
  final String? orderId;
  final String? message;

  const RequestVerification({required this.status, this.orderId, this.message});
}

class FirebaseRequestVerifier {
  final FirebaseFirestore firestore;
  final String storeId;

  FirebaseRequestVerifier(this.firestore, {this.storeId = 'bay-hai'});

  Future<RequestVerification> verify(String requestId) async {
    if (requestId.trim().isEmpty || requestId.contains('/')) {
      return const RequestVerification(
        status: RequestVerificationStatus.uncertain,
        message: 'requestId không hợp lệ',
      );
    }

    try {
      final store = firestore.collection('stores').doc(storeId);

      // Bắt buộc đọc trực tiếp từ máy chủ.
      final requestSnapshot = await store
          .collection('requests')
          .doc(requestId)
          .get(const GetOptions(source: Source.server));

      if (!requestSnapshot.exists) {
        return const RequestVerification(
          status: RequestVerificationStatus.notFound,
        );
      }

      final requestData = requestSnapshot.data();
      final value = requestData?['value'];

      if (value is! Map ||
          value['id'] != requestId ||
          value['orderId'] is! String) {
        return const RequestVerification(
          status: RequestVerificationStatus.uncertain,
          message: 'Bản ghi request không hợp lệ',
        );
      }

      final orderId = value['orderId'] as String;

      final orderSnapshot = await store
          .collection('orders')
          .doc(orderId)
          .get(const GetOptions(source: Source.server));

      if (!orderSnapshot.exists) {
        return const RequestVerification(
          status: RequestVerificationStatus.uncertain,
          message: 'Request tồn tại nhưng thiếu hóa đơn',
        );
      }

      final orderData = orderSnapshot.data();
      final orderValue = orderData?['value'];

      if (orderValue is! Map ||
          orderValue['id'] != orderId ||
          orderValue['requestId'] != requestId) {
        return const RequestVerification(
          status: RequestVerificationStatus.uncertain,
          message: 'Request và hóa đơn không khớp',
        );
      }

      return RequestVerification(
        status: RequestVerificationStatus.confirmed,
        orderId: orderId,
      );
    } catch (error) {
      // Mất mạng, hết quyền hoặc lỗi server:
      // tuyệt đối không suy luận là chưa có đơn.
      return RequestVerification(
        status: RequestVerificationStatus.uncertain,
        message: error.toString(),
      );
    }
  }
}
