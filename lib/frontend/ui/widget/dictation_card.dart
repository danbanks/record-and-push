import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:watch_it/watch_it.dart';

import '../../../backend/core.dart';
import '../view_model.dart';

class DictationCard extends WatchingWidget {
  final DictationViewModel dictation;
  final VoidCallback? onTap;

  const DictationCard({
    super.key,
    required this.dictation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    watch(dictation);

    final colorScheme = _getStatusColorScheme(dictation.status);
    final icon = _getStatusIcon(dictation.status);
    final statusLabel = _getStatusLabel(dictation.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
        color: colorScheme['background'],
        border: Border.all(
          color: colorScheme['border']!,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dictation.status == DictationViewStatus.recordingLocally
                  ? _buildGlowingRedDot()
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(153), // Replaced withOpacity
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.grey[700]),
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dictation ${dictation.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(dictation.createdAt.millisecondsSinceEpoch),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dictation.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(204),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  dictation.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Map<String, Color> _getStatusColorScheme(DictationViewStatus status) {
    // Color scheme implementation...
    switch (status) {
      case DictationViewStatus.draft:
        return {'background': Colors.grey[100]!, 'border': Colors.grey[300]!};
      case DictationViewStatus.recordingLocally:
      case DictationViewStatus.recording:
        return {'background': Colors.red[50]!, 'border': Colors.red[400]!};
      case DictationViewStatus.publishingLocally:
      case DictationViewStatus.publishing:
        return {
          'background': Colors.yellow[50]!,
          'border': Colors.yellow[400]!
        };
      case DictationViewStatus.published:
        return {'background': Colors.green[50]!, 'border': Colors.green[400]!};
    }
  }

  IconData _getStatusIcon(DictationViewStatus status) {
    // Icon selection implementation...
    switch (status) {
      case DictationViewStatus.draft:
      case DictationViewStatus.recordingLocally:
      case DictationViewStatus.recording:
        return LucideIcons.mic;
      case DictationViewStatus.published:
        return LucideIcons.circleCheck;
      case DictationViewStatus.publishingLocally:
      case DictationViewStatus.publishing:
        return LucideIcons.upload;
    }
  }

  String _getStatusLabel(DictationViewStatus status) {
    // Label implementation...
    switch (status) {
      case DictationViewStatus.draft:
        return 'Draft';
      case DictationViewStatus.recordingLocally:
      case DictationViewStatus.recording:
        return 'Recording...';
      case DictationViewStatus.publishingLocally:
      case DictationViewStatus.publishing:
        return 'Publishing...';
      case DictationViewStatus.published:
        return 'Published';
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat.yMMMd().add_jms().format(date);
  }

  Widget _buildGlowingRedDot() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(153),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.red[600],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withAlpha(179),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 0),
              ),
              BoxShadow(
                color: Colors.red.withAlpha(102),
                spreadRadius: 4,
                blurRadius: 12,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
