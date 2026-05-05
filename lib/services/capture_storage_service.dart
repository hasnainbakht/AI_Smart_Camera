// capture_storage_service.dart
//
// Saves captured images into the app's private documents directory.
// No gallery / photo library permission required at all.
//
// Folder structure:
//   <documentsDir>/captures/
//     camera_1733571000000.jpg
//     camera_1733571000000.json   ← metadata sidecar
//     ...
//
// Usage (in your camera screen):
//   await CaptureStorageService.instance.saveCapture(
//     sourcePath: file.path,
//     filters: { 'brightness': 0.5, ... },
//     placementScore: 87,
//     guidanceStatus: 'good',
//   );

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// ─── Data model ────────────────────────────────────────────────────────────────

class CaptureEntry {
  final String id;          // e.g. "camera_1733571000000"
  final String imagePath;   // absolute path to the .jpg
  final DateTime createdAt;
  final Map<String, dynamic> filters;
  final num? placementScore;
  final String? guidanceStatus;

  const CaptureEntry({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    required this.filters,
    this.placementScore,
    this.guidanceStatus,
  });

  factory CaptureEntry.fromJson(Map<String, dynamic> json, String imagePath) {
    return CaptureEntry(
      id: json['id'] as String,
      imagePath: imagePath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      filters: Map<String, dynamic>.from(json['filters'] as Map? ?? {}),
      placementScore: json['placementScore'] as num?,
      guidanceStatus: json['guidanceStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'filters': filters,
        if (placementScore != null) 'placementScore': placementScore,
        if (guidanceStatus != null) 'guidanceStatus': guidanceStatus,
      };
}

// ─── Service ───────────────────────────────────────────────────────────────────

class CaptureStorageService {
  CaptureStorageService._();
  static final CaptureStorageService instance = CaptureStorageService._();

  Directory? _capturesDir;

  /// Returns (and creates) the captures directory inside app documents.
  Future<Directory> get capturesDir async {
    if (_capturesDir != null) return _capturesDir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'captures'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _capturesDir = dir;
    return dir;
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Copies [sourcePath] into the captures folder and writes a metadata sidecar.
  /// Returns the saved [CaptureEntry] or null on failure.
  Future<CaptureEntry?> saveCapture({
    required String sourcePath,
    Map<String, dynamic> filters = const {},
    num? placementScore,
    String? guidanceStatus,
  }) async {
    try {
      final dir = await capturesDir;
      final id = 'camera_${DateTime.now().millisecondsSinceEpoch}';
      final destImagePath = p.join(dir.path, '$id.jpg');
      final destMetaPath  = p.join(dir.path, '$id.json');

      // Copy image
      await File(sourcePath).copy(destImagePath);

      // Write sidecar JSON
      final entry = CaptureEntry(
        id: id,
        imagePath: destImagePath,
        createdAt: DateTime.now(),
        filters: filters,
        placementScore: placementScore,
        guidanceStatus: guidanceStatus,
      );
      await File(destMetaPath)
          .writeAsString(jsonEncode(entry.toJson()), flush: true);

      debugPrint('[CaptureStorage] Saved: $destImagePath');
      return entry;
    } catch (e) {
      debugPrint('[CaptureStorage] Save error: $e');
      return null;
    }
  }

  // ── Load all ────────────────────────────────────────────────────────────────

  /// Returns all captures sorted newest first.
  Future<List<CaptureEntry>> loadAll() async {
    try {
      final dir = await capturesDir;
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => p.extension(f.path) == '.jpg')
          .toList();

      final List<CaptureEntry> entries = [];

      for (final imageFile in files) {
        final id = p.basenameWithoutExtension(imageFile.path);
        final metaFile = File(p.join(dir.path, '$id.json'));

        if (await metaFile.exists()) {
          try {
            final json =
                jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
            entries.add(CaptureEntry.fromJson(json, imageFile.path));
          } catch (_) {
            // Corrupt sidecar — add entry with just the image info
            entries.add(CaptureEntry(
              id: id,
              imagePath: imageFile.path,
              createdAt:
                  await imageFile.lastModified(),
              filters: {},
            ));
          }
        } else {
          // No sidecar — still show the image
          entries.add(CaptureEntry(
            id: id,
            imagePath: imageFile.path,
            createdAt: await imageFile.lastModified(),
            filters: {},
          ));
        }
      }

      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (e) {
      debugPrint('[CaptureStorage] Load error: $e');
      return [];
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  /// Deletes the image file and its sidecar JSON.
  Future<bool> delete(CaptureEntry entry) async {
    try {
      final dir = await capturesDir;
      final imageFile = File(entry.imagePath);
      final metaFile  = File(p.join(dir.path, '${entry.id}.json'));

      if (await imageFile.exists()) await imageFile.delete();
      if (await metaFile.exists())  await metaFile.delete();

      debugPrint('[CaptureStorage] Deleted: ${entry.id}');
      return true;
    } catch (e) {
      debugPrint('[CaptureStorage] Delete error: $e');
      return false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Total number of captures saved.
  Future<int> get count async => (await loadAll()).length;

  /// Total disk space used by captures in bytes.
  Future<int> get totalBytes async {
    final dir = await capturesDir;
    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}