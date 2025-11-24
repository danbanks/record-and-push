import 'package:flutter/foundation.dart';
import 'package:watch_it/watch_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:record_and_push/dictation/core.dart';
import 'package:record_and_push/dictation/application.dart';
import 'package:record_and_push/dictation/infrastructure.dart';

final GetIt getIt = GetIt.instance;

// Simplified setup for testing that skips SpeechToText
Future<void> setupTestDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  final dio = Dio();
  getIt.registerSingleton<Dio>(dio);

  // Use mock values for testing
  final isRecordingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<UsageContext> usageContext = ValueNotifier(UsageContext.normal);

  getIt.registerSingleton<PlatformEnvironment>(
    PlatformEnvironment(usageContext, isRecordingNotifier),
  );

  // Register repositories and services as needed for your tests
  // ... rest of setup without SpeechToText
}