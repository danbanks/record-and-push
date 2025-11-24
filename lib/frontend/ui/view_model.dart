import 'package:flutter/foundation.dart';

import '../../backend/application.dart';
import '../../backend/core.dart';

enum DictationViewStatus {
  draft,
  recordingLocally,
  recording,
  publishing,
  published,
}

class DictationViewModel extends ChangeNotifier {
  final DictationProjection _projection;
  bool _recordingLocally;

  DictationViewModel(
    this._projection, {
    bool recordingLocally = false,
    bool publishingLocally = false,
  })  : _recordingLocally = recordingLocally {
    _projection.addListener(_onProjectionChanged);
  }

  void _onProjectionChanged() {
    notifyListeners();
  }

  // Forward DictationView properties from the projection
  String get id => _projection.snapshot.id;
  String get text => _projection.snapshot.text;
  DateTime get createdAt => _projection.snapshot.createdAt;
  DateTime? get publishedAt => _projection.snapshot.publishedAt;

  DictationViewStatus get status {
    switch (_projection.snapshot.status) {
      case DictationStatus.draft:
        return DictationViewStatus.draft;
      case DictationStatus.recording:
        return _recordingLocally
            ? DictationViewStatus.recordingLocally
            : DictationViewStatus.recording;
      case DictationStatus.publishing:
        return DictationViewStatus.publishing;
      case DictationStatus.published:
        return DictationViewStatus.published;
    }
  }

  // Forward DictationView computed properties
  bool get canRecord => _projection.snapshot.canRecord;
  bool get canPublish => _projection.snapshot.canPublish;
  bool get isRecording => _projection.snapshot.isRecording;
  bool get isPublishing => _projection.snapshot.isPublishing;

  void setRecordingLocally(bool value) {
    if (_recordingLocally != value) {
      _recordingLocally = value;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _projection.removeListener(_onProjectionChanged);
    super.dispose();
  }
}


abstract class RecordingService extends ChangeNotifier {
  bool get isRecording;

  Stream<String> record();
  Future<void> stop();
}

abstract class DictationApplicationViewModel extends ChangeNotifier {
  // Reactive state
  List<DictationViewModel> get allDictations;
  DictationViewModel? get locallyRecordingDictation;
  bool get isRecording;

  // Commands
  Future<void> recordNewDictation();
  Future<void> recordOnExistingDictation(String dictationId);
  Future<void> stopRecording();
  Future<void> publishDictation(String dictationId);
}

class ObservingDictationApplicationViewModel extends DictationApplicationViewModel {
  final DictationApplication _application;
  final RecordingService _recordingService;

  DictationListProjection? _allDictationsProjection;
  final Map<String, DictationViewModel> _viewModels = {};
  List<DictationViewModel> _allDictations = [];
  DictationViewModel? _locallyRecordingDictation;

  ObservingDictationApplicationViewModel(
    this._application,
    this._recordingService,
  );

  // Setup listeners (called from config.dart)
  Future<void> initialize() async {
    // Listen to all dictations
    _allDictationsProjection = await _application.getAllDictations();
    _allDictationsProjection!.addListener(_onAllDictationsChanged);
    _onAllDictationsChanged(); // Initial update

    // Listen to recording service state changes
    _recordingService.addListener(_onRecordingServiceChanged);
  }

  void _onAllDictationsChanged() {
    final projections = _allDictationsProjection!.snapshot;

    // Create or update view models for each projection
    final updatedViewModels = <DictationViewModel>[];
    for (final projection in projections) {
      final id = projection.snapshot.id;

      // Reuse existing view model or create new one
      final viewModel = _viewModels.putIfAbsent(
        id,
        () => DictationViewModel(projection),
      );

      updatedViewModels.add(viewModel);
    }

    // Remove and dispose view models for deleted dictations
    final currentIds = projections.map((p) => p.snapshot.id).toSet();
    _viewModels.removeWhere((id, viewModel) {
      if (!currentIds.contains(id)) {
        viewModel.dispose();
        return true;
      }
      return false;
    });

    _allDictations = updatedViewModels;
    notifyListeners();
  }

  void _onRecordingServiceChanged() {
    // When recording service stops, clear the locally recording dictation
    if (!_recordingService.isRecording && _locallyRecordingDictation != null) {
      _locallyRecordingDictation!.setRecordingLocally(false);
      _locallyRecordingDictation = null;
    }

    // Forward RecordingService changes to our listeners
    notifyListeners();
  }

  @override
  List<DictationViewModel> get allDictations => _allDictations;

  @override
  DictationViewModel? get locallyRecordingDictation => _locallyRecordingDictation;

  @override
  bool get isRecording => _recordingService.isRecording;

  @override
  Future<void> recordNewDictation() async {
    final projection = await _application.recordNewDictation(
      _recordingService.record(),
    );

    // Create view model for the new dictation
    final id = projection.snapshot.id;
    final viewModel = _viewModels.putIfAbsent(
      id,
      () => DictationViewModel(projection),
    );

    // Mark this dictation as recording locally
    viewModel.setRecordingLocally(true);
    _locallyRecordingDictation = viewModel;

    notifyListeners();
  }

  @override
  Future<void> recordOnExistingDictation(String dictationId) async {
    // Find the view model from our list
    final viewModel = _viewModels[dictationId];
    if (viewModel == null) {
      throw Exception('Dictation not found');
    }

    // Mark this dictation as recording locally
    viewModel.setRecordingLocally(true);
    _locallyRecordingDictation = viewModel;
    notifyListeners();

    final textStream = _recordingService.record();
    await _application.recordOnExistingDictation(dictationId, textStream);
  }

  @override
  Future<void> stopRecording() async {
    await _recordingService.stop();

    // Clear recording locally flag on the previously recording dictation
    if (_locallyRecordingDictation != null) {
      _locallyRecordingDictation!.setRecordingLocally(false);
      _locallyRecordingDictation = null;
    }

    notifyListeners();
  }

  @override
  Future<void> publishDictation(String dictationId) async {
    await _application.publishDictation(dictationId);
  }

  @override
  void dispose() {
    _allDictationsProjection?.removeListener(_onAllDictationsChanged);
    _recordingService.removeListener(_onRecordingServiceChanged);

    // Dispose all view models
    for (final viewModel in _viewModels.values) {
      viewModel.dispose();
    }
    _viewModels.clear();

    super.dispose();
  }
}
