import 'dart:async';

import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:watch_it/watch_it.dart';

import '../backend/application.dart';
import 'infrastructure.dart';
import 'ui.dart';

// Custom exception for speech to text initialization errors
class SpeechToTextInitializationException implements Exception {
  final String message;
  SpeechToTextInitializationException(this.message);

  @override
  String toString() => 'SpeechToTextInitializationException: $message';
}

final GetIt getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Register external dependencies first
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  final dio = Dio();
  getIt.registerSingleton<Dio>(dio);

  // --- SpeechToText Initialization ---
  final speechToText = SpeechToText();

  // Request microphone permission
  final permissionStatus = await Permission.microphone.request();
  if (!permissionStatus.isGranted) {
    throw SpeechToTextInitializationException(
        'Microphone permission not granted.');
  }

  // Initialize speech to text
  final hasPermission = await speechToText.initialize(
    onError: (error) =>
        throw SpeechToTextInitializationException(error.errorMsg),
  );

  if (!hasPermission) {
    throw SpeechToTextInitializationException(
        'Speech recognition permission not granted.');
  }

  getIt.registerSingleton<SpeechToText>(speechToText);
  // --- End of SpeechToText Initialization ---


  getIt.registerSingleton<DictationRepository>(
    InMemoryDictationRepository(),
  );

  // Create RecordingService first so PlatformEnvironment can use it
  final recordingService = SpeechToTextRecordingService(speechToText);

  getIt.registerSingleton<RecordingService>(recordingService);

  // Register the DictationApplication
  getIt.registerSingleton<DictationApplication>(
    DictationApplication(
      getIt<DictationRepository>(),
    ),
  );

  // Register and initialize the DictationViewModel
  final viewModel = ObservingDictationApplicationViewModel(
    getIt<DictationApplication>(),
    recordingService,
  );
  await viewModel.initialize(); // Setup all listeners here
  getIt.registerSingleton<DictationApplicationViewModel>(viewModel);
}

// Cleanup function to dispose resources
Future<void> disposeDependencyInjection() async {
  // Dispose view model
  if (getIt.isRegistered<DictationApplicationViewModel>()) {
    final viewModel = getIt<DictationApplicationViewModel>();
    if (viewModel is ObservingDictationApplicationViewModel) {
      viewModel.dispose();
    }
  }

  // Dispose repository if it has a dispose method
  final repo = getIt<DictationRepository>();
  if (repo is InMemoryDictationRepository) {
    repo.dispose();
  }

  // Dispose services
  if (getIt.isRegistered<RecordingService>()) {
    final service = getIt<RecordingService>();
    if (service is SpeechToTextRecordingService) {
      service.dispose();
    }
  }

  // Reset GetIt
  await getIt.reset();
}
