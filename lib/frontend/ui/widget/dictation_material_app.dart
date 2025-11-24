import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../other/navigating_dictation_recording_observer.dart';
import '../view_model.dart';
import 'dictation_list_screen.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

StatelessWidget createDictationMaterialApp() {
  final viewModel = GetIt.I<DictationApplicationViewModel>();
  final isRecordingNotifier = ValueNotifier<bool>(viewModel.isRecording);

  // Sync view model's isRecording to notifier
  viewModel.addListener(() {
    isRecordingNotifier.value = viewModel.isRecording;
  });

  final recordingObserver = NavigatingDictationRecordingObserver.create(
      _navigatorKey,
      isRecordingNotifier,
      () => const DictationListScreen()
  );

  return _DictationMaterialApp(recordingObserver);
}

class _DictationMaterialApp extends StatelessWidget {
  final NavigatingDictationRecordingObserver recordingObserver;

  const _DictationMaterialApp(this.recordingObserver);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // todo add back when navigator is needed
      // navigatorKey: _navigatorKey,
      home: const DictationListScreen(),
    );
  }
}