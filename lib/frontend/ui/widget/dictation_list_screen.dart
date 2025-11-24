import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:watch_it/watch_it.dart';

import '../../../backend/application.dart';
import '../view_model.dart';
import 'create_dictation_card.dart';
import 'dictation_card.dart';

class DictationListScreen extends WatchingWidget {
  const DictationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = watchIt<DictationApplicationViewModel>();

    final appBar = AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: const Text('Dictations'),
      leading: const Icon(LucideIcons.mic, color: Colors.black87),
      actions: [],
    );

    final allDictationList = viewModel.allDictations;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: appBar,
      body: _buildListView(context, allDictationList, viewModel),
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<DictationViewModel> dictationList,
    DictationApplicationViewModel viewModel,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dictationList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: CreateDictationCard(
              onTap: () => viewModel.recordNewDictation(),
            ),
          );
        }

        final dictation = dictationList[index - 1];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: DictationCard(
            dictation: dictation,
            onTap: () {
              if (dictation.status == DictationViewStatus.recordingLocally) {
                // Stop recording if this dictation is currently being recorded locally
                viewModel.stopRecording();
              } else if (dictation.canRecord) {
                // Start recording if it's in a recordable state
                viewModel.recordOnExistingDictation(dictation.id);
              }
            },
          ),
        );
      },
    );
  }
}
