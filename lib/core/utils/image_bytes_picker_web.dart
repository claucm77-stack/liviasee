// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image.dart';

Future<PickedImageBytes?> pickImageBytes() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';
  html.document.body?.append(input);

  try {
    final changeFuture = input.onChange.first;
    input.click();
    await changeFuture;
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) return null;

    final reader = html.FileReader();
    final loadFuture = reader.onLoad.first;
    reader.readAsArrayBuffer(file);
    await loadFuture;
    final result = reader.result;
    final Uint8List bytes;
    if (result is ByteBuffer) {
      bytes = Uint8List.view(result);
    } else if (result is Uint8List) {
      bytes = result;
    } else if (result is List<int>) {
      bytes = Uint8List.fromList(result);
    } else {
      throw StateError(
          'El navegador no devolvió bytes válidos para la imagen.');
    }

    return PickedImageBytes(
      bytes: bytes,
      fileName: file.name,
      mimeType: file.type.isEmpty ? 'image/jpeg' : file.type,
    );
  } finally {
    input.remove();
  }
}
