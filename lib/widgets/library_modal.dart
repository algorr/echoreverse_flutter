import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/app_models.dart';
import '../utils/snackbar_helper.dart';

/// Library modal showing saved recordings
class LibraryModal extends StatefulWidget {
  final List<StoredRecording> recordings;
  final String? currentRecordingId;
  final ValueChanged<StoredRecording> onRecordingSelected;
  final ValueChanged<String> onDeleteRecording;
  final VoidCallback onClose;

  const LibraryModal({
    super.key,
    required this.recordings,
    required this.currentRecordingId,
    required this.onRecordingSelected,
    required this.onDeleteRecording,
    required this.onClose,
  });

  @override
  State<LibraryModal> createState() => _LibraryModalState();
}

class _LibraryModalState extends State<LibraryModal> {
  late List<StoredRecording> _localRecordings;

  @override
  void initState() {
    super.initState();
    _localRecordings = List.from(widget.recordings);
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleShare(StoredRecording recording) async {
    try {
      final file = File(recording.reversedPath);
      final exists = await file.exists();

      if (!exists) {
        if (mounted) {
          AppSnackBar.show(context, message: 'File not found', type: SnackBarType.error);
        }
        return;
      }

      // Copy to temp directory with a clean filename for sharing
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final shareFileName = 'reverso_$timestamp.wav';
      final tempFile = File('${tempDir.path}/$shareFileName');
      await file.copy(tempFile.path);

      // Get screen size for share position (required for iPad)
      final box = context.findRenderObject() as RenderBox?;
      final sharePosition = box != null
          ? Rect.fromLTWH(
              box.localToGlobal(Offset.zero).dx + box.size.width / 2,
              box.localToGlobal(Offset.zero).dy,
              1,
              1,
            )
          : const Rect.fromLTWH(100, 100, 1, 1);

      await Share.shareXFiles(
        [XFile(tempFile.path, name: shareFileName, mimeType: 'audio/wav')],
        subject: 'Reverso Audio',
        sharePositionOrigin: sharePosition,
      );

      // Clean up temp file after sharing (with delay)
      Future.delayed(const Duration(seconds: 5), () async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, message: 'Share failed', type: SnackBarType.error);
      }

    }
  }

  void _handleDelete(String recordingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red[400], size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Recording?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This recording will be permanently deleted. This action cannot be undone.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog

              // Update local state first
              setState(() {
                _localRecordings.removeWhere((r) => r.id == recordingId);
              });

              // Then notify parent
              widget.onDeleteRecording(recordingId);

              // Show success message
              AppSnackBar.show(context, message: 'Recording deleted', type: SnackBarType.success);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.folder_open,
                      color: Color(0xFFD946EF),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ARCHIVE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, color: Colors.grey[400]),
                ),
              ],
            ),
          ),

          // Recordings list
          Expanded(
            child: _localRecordings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _localRecordings.length,
                    itemBuilder: (context, index) {
                      final recording = _localRecordings[index];
                      final isActive = widget.currentRecordingId == recording.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFD946EF).withValues(alpha: 0.15)
                              : const Color(0xFF18181B).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFFD946EF).withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD946EF).withValues(alpha: 0.15),
                                    blurRadius: 15,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Recording info - tappable to select
                            Expanded(
                              child: GestureDetector(
                                onTap: () => widget.onRecordingSelected(recording),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'REC_${recording.id.substring(0, 4).toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                            color: isActive
                                                ? const Color(0xFFD946EF)
                                                : Colors.grey[300],
                                          ),
                                        ),
                                        if (recording.effectLabel != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF22D3EE),
                                                  Color(0xFFD946EF),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              recording.effectLabel!.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatTimestamp(recording.timestamp)} • ${_formatTime(recording.duration)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Active badge
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD946EF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),

                            const SizedBox(width: 8),

                            // Share button
                            Material(
                              color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () => _handleShare(recording),
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.ios_share,
                                    color: Color(0xFF22D3EE),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Delete button
                            Material(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () => _handleDelete(recording.id),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.album, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'NO DATA FOUND',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              letterSpacing: 2,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
