import 'package:flutter/material.dart';
import '../models/app_models.dart';

/// Library modal showing saved recordings
class LibraryModal extends StatelessWidget {
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

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
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
                    Icon(
                      Icons.folder_open,
                      color: const Color(0xFFD946EF),
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
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: Colors.grey[400]),
                ),
              ],
            ),
          ),

          // Recordings list
          Expanded(
            child: recordings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: recordings.length,
                    itemBuilder: (context, index) {
                      final recording = recordings[index];
                      final isActive = currentRecordingId == recording.id;

                      return GestureDetector(
                        onTap: () => onRecordingSelected(recording),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(
                                    0xFFD946EF,
                                  ).withValues(alpha: 0.15)
                                : const Color(
                                    0xFF18181B,
                                  ).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? const Color(
                                      0xFFD946EF,
                                    ).withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFD946EF,
                                      ).withValues(alpha: 0.15),
                                      blurRadius: 15,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Recording info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RECORDING_${recording.id.substring(0, 4).toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                        color: isActive
                                            ? const Color(0xFFD946EF)
                                            : Colors.grey[300],
                                      ),
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

                              const SizedBox(width: 12),

                              // Delete button
                              IconButton(
                                onPressed: () =>
                                    onDeleteRecording(recording.id),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
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
