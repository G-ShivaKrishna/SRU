import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveBytesToLocalFile(Uint8List bytes, String fileName) async {
  if (Platform.isAndroid || Platform.isIOS) {
    Directory downloadsDir = Directory('/storage/emulated/0/Download');
    if (!await downloadsDir.exists()) {
      downloadsDir = Directory('/sdcard/Download');
    }
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    final filePath = '${downloadsDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  final outputPath = await FilePicker.platform.saveFile(
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [fileName.split('.').last],
  );
  if (outputPath == null) return null;

  final file = File(outputPath);
  await file.writeAsBytes(bytes);
  return outputPath;
}
