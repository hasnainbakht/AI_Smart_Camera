// history_screen.dart
//
// Reads captures from app-local storage via CaptureStorageService.
// No gallery permission required.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/capture_storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<CaptureEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    final entries = await CaptureStorageService.instance.loadAll();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _deleteEntry(CaptureEntry entry) async {
    final confirmed = await _showDeleteDialog(entry);
    if (!confirmed) return;

    final success = await CaptureStorageService.instance.delete(entry);
    if (success) {
      setState(() => _entries.removeWhere((e) => e.id == entry.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete image'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteDialog(CaptureEntry entry) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Image',
                style: TextStyle(color: Colors.white)),
            content: const Text(
              'This will permanently delete the image from the app.',
              style: TextStyle(color: Colors.white60),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatDate(DateTime dt) {
    final y  = dt.year.toString();
    final mo = dt.month.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final h  = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d  $h:$mi';
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/home'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.white10,
                      blurRadius: 6,
                      offset: Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadEntries,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined,
                color: Colors.white24, size: 52),
            SizedBox(height: 16),
            Text(
              'No captures yet',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'Photos taken with this app will appear here',
              style: TextStyle(color: Colors.white24, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _HistoryTile(
          entry: entry,
          formattedDate: _formatDate(entry.createdAt),
          onDelete: () => _deleteEntry(entry),
        );
      },
    );
  }
}

// ─── Tile ────────────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final CaptureEntry entry;
  final String formattedDate;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.entry,
    required this.formattedDate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(entry.imagePath);

    return GestureDetector(
      onTap: () {
        // Optional: context.push('/preview', extra: entry);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Colors.white10,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            // ── Thumbnail ────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: file.existsSync()
                  ? Image.file(
                      file,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      frameBuilder: (ctx, child, frame, _) =>
                          frame == null ? _thumbPlaceholder() : child,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),

            const SizedBox(width: 12),

            // ── Info ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13),
                  ),
                  if (entry.placementScore != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          'Score: ${entry.placementScore!.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.amber, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Delete ───────────────────────────────────────────
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Icon(Icons.image, color: Colors.white24, size: 28),
      );
}