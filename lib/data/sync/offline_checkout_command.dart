import 'dart:convert';

class OfflineCheckoutLine {
  final String productId;
  final int area;
  final String note;
  final num quotedPrice;
  final num quotedRatio;

  const OfflineCheckoutLine({
    required this.productId,
    required this.area,
    required this.note,
    required this.quotedPrice,
    required this.quotedRatio,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'area': area,
    'note': note,
    'quotedPrice': quotedPrice,
    'quotedRatio': quotedRatio,
  };

  factory OfflineCheckoutLine.fromJson(Map<String, dynamic> json) {
    return OfflineCheckoutLine(
      productId: json['productId'] as String,
      area: json['area'] as int,
      note: json['note'] as String,
      quotedPrice: json['quotedPrice'] as num,
      quotedRatio: json['quotedRatio'] as num,
    );
  }
}

class OfflineCheckoutCommand {
  final String requestId;
  final String actorId;
  final String customerId;
  final List<OfflineCheckoutLine> lines;
  final int paid;
  final int ship;
  final bool hold;
  final String negativeReason;
  final DateTime createdAt;

  const OfflineCheckoutCommand({
    required this.requestId,
    required this.actorId,
    required this.customerId,
    required this.lines,
    required this.paid,
    required this.ship,
    required this.hold,
    required this.negativeReason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'version': 1,
    'requestId': requestId,
    'actorId': actorId,
    'customerId': customerId,
    'lines': lines.map((line) => line.toJson()).toList(),
    'paid': paid,
    'ship': ship,
    'hold': hold,
    'negativeReason': negativeReason,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory OfflineCheckoutCommand.decode(String value) {
    final json = Map<String, dynamic>.from(jsonDecode(value) as Map);

    if (json['version'] != 1) {
      throw const FormatException('Phiên bản lệnh không hỗ trợ');
    }

    return OfflineCheckoutCommand(
      requestId: json['requestId'] as String,
      actorId: json['actorId'] as String,
      customerId: json['customerId'] as String,
      lines: (json['lines'] as List)
          .map(
            (line) => OfflineCheckoutLine.fromJson(
              Map<String, dynamic>.from(line as Map),
            ),
          )
          .toList(),
      paid: json['paid'] as int,
      ship: json['ship'] as int,
      hold: json['hold'] as bool,
      negativeReason: json['negativeReason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
