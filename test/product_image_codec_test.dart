import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vlxd_app/utils/product_image_codec.dart';

void main() {
  test('Ảnh nhiều chi tiết tự nén và giữ tỉ lệ trong 40 KB', () {
    final photo = img.Image(width: 500, height: 360);
    // Deterministic high-entropy pixels: unlike repeating stripes, this
    // fixture produces a PNG well above 40 KB and tests real compression.
    var seed = 0x5A17C3D9;
    for (var y = 0; y < photo.height; y++) {
      for (var x = 0; x < photo.width; x++) {
        seed ^= (seed << 13) & 0xFFFFFFFF;
        seed ^= seed >> 17;
        seed ^= (seed << 5) & 0xFFFFFFFF;
        seed &= 0xFFFFFFFF;
        photo.setPixelRgb(
          x,
          y,
          (seed >> 16) & 255,
          (seed >> 8) & 255,
          seed & 255,
        );
      }
    }
    final raw = Uint8List.fromList(img.encodePng(photo));
    expect(raw.length, greaterThan(40000));

    final encoded = encodeProductPhotoForFirestore(raw);
    final compressed = base64Decode(encoded);
    expect(compressed.length, lessThanOrEqualTo(40000));
    final result = img.decodeJpg(compressed);
    expect(result, isNotNull);
    expect(result!.width / result.height, closeTo(500 / 360, 0.03));
  });

  test('Không nhận ảnh rỗng hoặc định dạng không hỗ trợ', () {
    expect(
      () => encodeProductPhotoForFirestore(Uint8List(0)),
      throwsA(isA<StateError>()),
    );
    expect(
      () => encodeProductPhotoForFirestore(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<StateError>()),
    );
  });

  test('Ảnh PNG trong suốt vẫn thành JPEG hợp lệ, dưới 40 KB', () {
    final original = img.Image(width: 160, height: 140, numChannels: 4);
    img.fill(original, color: img.ColorRgba8(255, 255, 255, 0));
    for (var y = 20; y < 120; y++) {
      for (var x = 20; x < 140; x++) {
        original.setPixelRgba(x, y, 40, 120, 220, 200);
      }
    }
    final encoded = encodeProductPhotoForFirestore(
      Uint8List.fromList(img.encodePng(original)),
    );
    final bytes = base64Decode(encoded);
    expect(bytes.length, lessThanOrEqualTo(40000));
    expect(img.decodeJpg(bytes), isNotNull);
  });
}
