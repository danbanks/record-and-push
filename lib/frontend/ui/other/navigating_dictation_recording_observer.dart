import 'package:flutter/material.dart';

class NavigatingDictationRecordingObserver {
  bool _existingPushedRecordingView = false;

  NavigatingDictationRecordingObserver._();

  factory NavigatingDictationRecordingObserver.create(GlobalKey<NavigatorState> navigatorKey,
                                                      ValueNotifier<bool> isRecordingNotifier,
                                                      Widget Function() recordingWidgetSupplier) {
    final recordingObserver = NavigatingDictationRecordingObserver._();

    isRecordingNotifier.addListener(() {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      final isRecording = isRecordingNotifier.value;
      final recordingWidgetAlreadyRendered = false; // TODO

      if (isRecording && !recordingWidgetAlreadyRendered) {
        recordingObserver._existingPushedRecordingView = true;
        navigator.push(
          MaterialPageRoute(
            builder: (_) => recordingWidgetSupplier(),
          ),
        );
      } else if (!isRecording && recordingObserver._existingPushedRecordingView) {
        recordingObserver._existingPushedRecordingView = false;
        navigator.pop();
      }
    });

    // TODO throw exceptions if navigator == null or navigator can't pop but _existingPushedRecordingView == true
    return recordingObserver;
  }
}