import 'package:cloud_firestore/cloud_firestore.dart';

import 'request_verification_logic.dart';
import 'offline_book_operation.dart';

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

  Future<RequestVerification> verifyBook(OfflineBookOperation command) async {
    try {
      final doc = await firestore
          .doc('stores/$storeId/audit/${command.markerId}')
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) {
        return const RequestVerification(
          status: RequestVerificationStatus.notFound,
        );
      }
      final value = doc.data()?['value'];
      if (value is Map &&
          value['id'] == command.markerId &&
          value['actor'] == command.actorId &&
          value['operationType'] == command.type &&
          value['operationPayload'] == command.encode()) {
        return RequestVerification(
          status: RequestVerificationStatus.confirmed,
          orderId: command.target,
        );
      }
    } catch (_) {
      // An unavailable server is not evidence that an operation is absent.
    }
    return const RequestVerification(
      status: RequestVerificationStatus.uncertain,
    );
  }

  Future<RequestVerification> verify(String requestId) async {
    // Kiểm tra requestId trước khi truy vấn Firebase.
    if (requestId.trim().isEmpty || requestId.contains('/')) {
      return const RequestVerification(
        status: RequestVerificationStatus.uncertain,
        message: 'requestId không hợp lệ',
      );
    }

    try {
      final store = firestore.collection('stores').doc(storeId);

      // Luôn đọc từ máy chủ, không dùng dữ liệu cache.
      final requestSnapshot = await store
          .collection('requests')
          .doc(requestId)
          .get(const GetOptions(source: Source.server));

      // Máy chủ xác nhận chưa có request.
      if (!requestSnapshot.exists) {
        return const RequestVerification(
          status: RequestVerificationStatus.notFound,
        );
      }

      final requestData = requestSnapshot.data();
      final requestValue = requestData?['value'];

      // Kiểm tra cấu trúc request trước khi đọc orderId.
      if (requestValue is! Map ||
          requestValue['id'] != requestId ||
          requestValue['orderId'] is! String ||
          (requestValue['orderId'] as String).isEmpty) {
        return const RequestVerification(
          status: RequestVerificationStatus.uncertain,
          message: 'Bản ghi request không hợp lệ',
        );
      }

      final orderId = requestValue['orderId'] as String;

      // Kiểm tra hóa đơn tương ứng trực tiếp trên máy chủ.
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

      // Dùng chung logic xác minh đã có bài test riêng.
      final result = RequestVerificationLogic.check(
        requestId: requestId,
        requestValue: Map<String, dynamic>.from(requestValue),
        orderValue: orderValue is Map
            ? Map<String, dynamic>.from(orderValue)
            : null,
      );

      if (result != RequestCheckResult.confirmed) {
        return const RequestVerification(
          status: RequestVerificationStatus.uncertain,
          message: 'Request và hóa đơn không khớp',
        );
      }

      // Chỉ xác nhận khi request và hóa đơn khớp nhau.
      return RequestVerification(
        status: RequestVerificationStatus.confirmed,
        orderId: orderId,
      );
    } catch (error) {
      // Mất mạng, thiếu quyền hoặc lỗi Firebase:
      // không được suy luận rằng giao dịch chưa tồn tại.
      return RequestVerification(
        status: RequestVerificationStatus.uncertain,
        message: error.toString(),
      );
    }
  }
}
