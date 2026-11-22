import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compress a product photo for the existing Firestore/base64 data model.
/// The existing app budgets 40 KB per image to accommodate up to 11 images,
/// stock lots and other fields within a single product document.
/// No network access, uploads, Firestore writes, or image metadata retention.
String encodeProductPhotoForFirestore(
  Uint8List original, {
  int maxBytes = 40000,
}) {
  if (maxBytes < 1000) {
    throw ArgumentError.value(maxBytes, 'maxBytes', 'Giới hạn ảnh quá nhỏ.');
  }
  if (original.isEmpty) {
    throw StateError('Ảnh trống. Hãy chọn lại ảnh.');
  }

  img.Image? decoded;
  try {
    decoded = img.decodeImage(original);
  } catch (_) {
    // Invalid or unsupported image types should produce a clear user error.
  }
  if (decoded == null) {
    throw StateError(
      'Không đọc được ảnh này. Hãy chọn JPG, PNG hoặc WebP. '
      'Nếu ảnh iPhone là HEIC/HEIF, hãy xuất thành JPG rồi thử lại.',
    );
  }

  // Respect EXIF orientation before processing; encoder output is JPEG.
  final upright = img.bakeOrientation(decoded);
  final longestSide = math.max(upright.width, upright.height);
  if (longestSide <= 0) {
    throw StateError('Kích thước ảnh không hợp lệ.');
  }
  const sides = [480, 400, 320, 280, 240, 200, 160, 128, 96];
  const qualities = [82, 72, 62, 52, 42, 32, 22, 14];

  for (final side in sides) {
    final scale = math.min(1.0, side / longestSide);
    final width = math.max(1, (upright.width * scale).round());
    final height = math.max(1, (upright.height * scale).round());
    final resized = img.copyResize(
      upright,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    // Flatten alpha onto white (transparent product PNGs) and strip EXIF,
    // location and other image metadata by building a fresh RGB canvas.
    final rgb = img.Image(width: width, height: height, numChannels: 3);
    img.fill(rgb, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(rgb, resized);

    for (final quality in qualities) {
      final jpeg = img.encodeJpg(rgb, quality: quality);
      if (jpeg.length <= maxBytes) {
        return base64Encode(jpeg);
      }
    }
  }
  throw StateError(
    'Không thể nén ảnh dưới 40 KB. Hãy chọn ảnh đơn giản hơn '
    'hoặc dùng dịch vụ lưu ảnh riêng.',
  );
}
