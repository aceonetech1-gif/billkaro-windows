import 'dart:io';
import 'dart:isolate';

import 'package:billkaro/app/services/download/download_notification_service.dart';
import 'package:billkaro/utils/download_path_util.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Saves files on a background isolate and notifies when the download finishes.
///
/// Use this for invoice / PDF / Excel exports instead of writing on the UI
/// isolate and calling [showSuccess].
class FileDownloadService {
  FileDownloadService._();
  static final FileDownloadService instance = FileDownloadService._();

  /// Writes [bytes] to the downloads folder on a background isolate.
  ///
  /// Returns the saved [File], or `null` if the write failed.
  /// When [notify] is true, shows a download notification (not a success snackbar).
  Future<File?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String? preferredDirectory,
    bool notify = true,
    String notificationTitle = 'Download complete',
    String? notificationBody,
    int? notificationId,
  }) async {
    if (bytes.isEmpty) {
      debugPrint('❌ [DOWNLOAD] empty bytes for $fileName');
      return null;
    }

    try {
      final dir = await DownloadPathUtil.resolveSaveDirectory(
        preferredPath: preferredDirectory,
      );
      await Directory(dir).create(recursive: true);

      final safeName = _sanitizeFileName(fileName);
      final saved = await Isolate.run(
        () => _writeBytesToDisk(
          directory: dir,
          fileName: safeName,
          bytes: bytes,
        ),
      );

      final savedPath = saved['path']!;
      final savedName = saved['fileName']!;

      final file = File(savedPath);
      if (!await file.exists()) {
        debugPrint('❌ [DOWNLOAD] file missing after write: $savedPath');
        return null;
      }

      if (notify) {
        await DownloadNotificationService.instance.notifyComplete(
          fileName: savedName,
          filePath: savedPath,
          title: notificationTitle,
          body: notificationBody ?? 'Tap to open $savedName',
          notificationId: notificationId,
        );
      }

      return file;
    } catch (e, st) {
      debugPrint('❌ [DOWNLOAD] save failed: $e\n$st');
      rethrow;
    }
  }

  static String _sanitizeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'download';
    return trimmed.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  }
}

/// Top-level so [Isolate.run] can execute it on a background isolate.
Future<Map<String, String>> _writeBytesToDisk({
  required String directory,
  required String fileName,
  required Uint8List bytes,
}) async {
  Object? lastError;

  for (final candidate in _candidateFileNames(fileName)) {
    final filePath = p.join(directory, candidate);
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);

      final handle = await file.open(mode: FileMode.writeOnly);
      try {
        await handle.writeFrom(bytes);
        await handle.flush();
      } finally {
        await handle.close();
      }

      return {'path': filePath, 'fileName': candidate};
    } on FileSystemException catch (e) {
      lastError = e;
      if (_isLockedOrBusyError(e)) {
        continue;
      }
      rethrow;
    }
  }

  if (lastError != null) {
    throw lastError;
  }

  throw FileSystemException(
    'Cannot write file because it is in use by another process',
    p.join(directory, fileName),
  );
}

bool _isLockedOrBusyError(FileSystemException error) {
  final code = error.osError?.errorCode;
  // 32 = Windows sharing violation, 13 = permission denied (often locked file)
  if (code == 32 || code == 13) return true;

  final message = error.message.toLowerCase();
  return message.contains('being used by another process') ||
      message.contains('access is denied');
}

List<String> _candidateFileNames(String fileName) {
  final ext = p.extension(fileName);
  final base = p.basenameWithoutExtension(fileName);
  final stamp = DateTime.now().millisecondsSinceEpoch;

  final names = <String>[
    fileName,
    '$base-$stamp$ext',
  ];

  for (var i = 1; i <= 20; i++) {
    names.add('$base ($i)$ext');
  }

  return names;
}
