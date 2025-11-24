import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record_and_push/dictation/ui/view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../backend/application.dart';
import '../backend/core.dart';

class _DictationProjectionImpl extends DictationProjection {
  Dictation _dictation;

  _DictationProjectionImpl(Dictation initialDictation) : _dictation = initialDictation;

  @override
  Dictation get snapshot => _dictation;

  void _update(Dictation dictation) {
    if (_dictation.id == dictation.id) {
      _dictation = dictation;
      notifyListeners();
    }
  }
}

class SpeechToTextRecordingService extends ChangeNotifier implements RecordingService {
  late final SpeechToText _speechToText;

  StreamController<String>? _textController;
  Completer<void>? _recordingCompleter;

  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  SpeechToTextRecordingService(this._speechToText) {
    _speechToText.statusListener = _onStatusChanged;
    _speechToText.errorListener = _onError;
  }

  @override
  Stream<String> record() async* {
    // Wait for any existing recording to complete
    if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
      throw Exception('Recording is already in progress.');
    }

    // Create new completer for this recording session
    _recordingCompleter = Completer<void>();

    // Update state and notify
    _isRecording = true;
    notifyListeners();

    try {
      _textController = StreamController<String>.broadcast();

      await _startListeningWithTimeout(Duration(seconds: 10)); // TODO configurable
      yield* _textController!.stream;
    } finally {
      // Ensure completer is completed even if an exception occurs
      if (!_recordingCompleter!.isCompleted) {
        _recordingCompleter!.complete();
      }

      // Clear state and notify
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> _startListeningWithTimeout(Duration timeout) async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: timeout,
      pauseFor: Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          onDevice: false,
          listenMode: ListenMode.dictation
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_textController != null && !_textController!.isClosed) {
      _textController!.add(result.recognizedWords);
    }
  }

  void _onStatusChanged(String status) {
    if (status == 'done' || status == 'notListening') {
      _handleListeningComplete();
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (_textController != null && !_textController!.isClosed) {
      // Check if this is a timeout error
      if (error.errorMsg.contains('timeout') || error.errorMsg.contains('no-speech')) {
        _textController!.addError(Exception('Speech recognition timeout: ${error.errorMsg}'));
      } else {
        _textController!.addError(Exception('Speech recognition error: ${error.errorMsg}'));
      }
    }
    _handleListeningComplete();
  }

  void _handleListeningComplete() {
    if (_textController != null && !_textController!.isClosed) {
      _textController!.close();
    }

    // Complete the recording session
    if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
      _recordingCompleter!.complete();
    }
  }

  @override
  Future<void> stop() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    if (_textController != null && !_textController!.isClosed) {
      await _textController!.close();
    }

    // Complete the recording session
    if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
      _recordingCompleter!.complete();
    }

    // Clear state and notify
    _isRecording = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _textController?.close();

    // Complete any pending recording session
    if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
      _recordingCompleter!.complete();
    }

    _speechToText.statusListener = null;
    _speechToText.errorListener = null;

    super.dispose();
  }
}

class HttpDictationPublisherService {
  final Dio _dio;

  HttpDictationPublisherService(this._dio);

  @override
  Future<void> publish(String id, String text) async {

    try {
      await _dio.post(
        'some endpoint', // todo
        data: {
          'id': id,
          'text': text,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on DioException catch (e) {
      throw Exception('Failed to publish: ${e.message}');
    }
  }
}

class _InMemoryDictationListProjection extends DictationListProjection {
  final InMemoryDictationRepository _repo;
  final bool Function(DictationView)? _predicate;

  _InMemoryDictationListProjection(this._repo, [this._predicate]);

  @override
  List<DictationProjection> get snapshot {
    if (_predicate == null) {
      return _repo._sortedProjections;
    }
    return _repo._getFilteredProjections(_predicate!);
  }

  void _update() {
    notifyListeners();
  }
}

class InMemoryDictationRepository implements DictationRepository {
  final Map<String, Dictation> _dictations = {};
  final Map<String, _DictationProjectionImpl> _projections = {};

  // All dictations projection and its cached future
  _InMemoryDictationListProjection? _allProjection;
  Future<DictationListProjection>? _allFuture;

  // Status-specific projections and their cached futures
  final Map<DictationStatus, _InMemoryDictationListProjection> _statusProjections = {};
  final Map<DictationStatus, Future<DictationListProjection>> _statusFutures = {};

  @override
  Future<void> init() {
    return Future.value();
  }

  List<DictationProjection> get _sortedProjections {
    final projections = _projections.values.toList()
      ..sort((a, b) => b.snapshot.createdAt.compareTo(a.snapshot.createdAt));
    return List.unmodifiable(projections);
  }

  List<DictationProjection> _getFilteredProjections(bool Function(DictationView) predicate) {
    final projections = _projections.values
        .where((projection) => predicate(projection.snapshot))
        .toList()
      ..sort((a, b) => b.snapshot.createdAt.compareTo(a.snapshot.createdAt));
    return List.unmodifiable(projections);
  }

  @override
  Future<DictationProjection> save(Dictation dictation) {
    return Future.sync(() {
      final String id = dictation.id;
      final DictationStatus newStatus = dictation.status;
      final DictationStatus? oldStatus = _dictations[id]?.status;

      _dictations[id] = dictation;

      final projection = _projections.putIfAbsent(id, () => _DictationProjectionImpl(dictation));
      projection._update(dictation);

      _allProjection?._update();

      // Update status-specific projections
      if (oldStatus != newStatus) {
        // If status changed from something, notify the old status projection
        if (oldStatus != null && _statusProjections.containsKey(oldStatus)) {
          _statusProjections[oldStatus]!._update();
        }

        // Notify the new status projection
        if (_statusProjections.containsKey(newStatus)) {
          _statusProjections[newStatus]!._update();
        }
      } else if (oldStatus == null) {
        // New dictation added - notify the status projection
        if (_statusProjections.containsKey(newStatus)) {
          _statusProjections[newStatus]!._update();
        }
      }

      return projection;
    });
  }

  @override
  Future<void> delete(String id) {
    return Future.sync(() {
      final deletedDictation = _dictations[id];

      _dictations.remove(id);
      _projections[id]?.dispose();
      _projections.remove(id);

      _allProjection?._update();

      // Notify the status projection that had this dictation
      if (deletedDictation != null && _statusProjections.containsKey(deletedDictation.status)) {
        _statusProjections[deletedDictation.status]!._update();
      }
    });
  }

  @override
  Future<DictationListProjection> getAll() {
    if (_allFuture == null) {
      _allProjection = _InMemoryDictationListProjection(this);
      _allFuture = Future.value(_allProjection!);
    }
    return _allFuture!;
  }

  @override
  Future<DictationListProjection> getByStatus(DictationStatus status) {
    return _statusFutures.putIfAbsent(status, () {
      final projection = _statusProjections.putIfAbsent(
        status,
        () => _InMemoryDictationListProjection(this,
                (dictation) => dictation.status == status),
      );
      return Future.value(projection);
    });
  }

  @override
  Future<DictationProjection?> getById(String id) {
    return Future.value(_projections[id]);
  }

  void dispose() {
    for (final projection in _projections.values) {
      projection.dispose();
    }
    _projections.clear();
    _allProjection?.dispose();

    for (final statusProjection in _statusProjections.values) {
      statusProjection.dispose();
    }
    _statusProjections.clear();
  }
}
