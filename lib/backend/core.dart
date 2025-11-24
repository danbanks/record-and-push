import 'dart:async';

import 'package:uuid/uuid.dart';

typedef NotePublisher = Future<void> Function(String id, String text);

class InvalidNoteStateException implements Exception {
  final String message;
  InvalidNoteStateException(this.message);

  @override
  String toString() => message;
}

// Domain value objects
enum NoteStatus {
  draft,
  recording,
  publishing,
  published,
}

class NoteSnapshot {
  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final NoteStatus status;
  final int version;

  const NoteSnapshot({
    required this.id,
    required this.text,
    required this.createdAt,
    this.publishedAt,
    required this.status,
    required this.version,
  });

  // Business rules
  bool get canRecord => status == NoteStatus.draft;

  bool get canPublish => status == NoteStatus.draft &&
      text.isNotEmpty;

  bool get isRecording => status == NoteStatus.recording;

  bool get isPublishing => status == NoteStatus.publishing;
}

abstract class NoteView extends NoteSnapshot {
  final List<NoteEvent> events;

  const NoteView._({
    required super.id,
    required super.text,
    required super.createdAt,
    super.publishedAt,
    required super.status,
    required super.version,
    required this.events,
  }) : super();
}

// Domain events
abstract class DomainEvent {
  final int version;
  const DomainEvent(this.version);
}

abstract class NoteEvent extends DomainEvent {
  final String noteId;
  const NoteEvent(this.noteId, int version) : super(version);
}

class NoteCreated extends NoteEvent {
  final NoteSnapshot snapshot;
  const NoteCreated(super.noteId, super.version, this.snapshot);
}

class NoteRecordingStarted extends NoteEvent {
  const NoteRecordingStarted(super.noteId, super.version);
}

class NoteTextAppended extends NoteEvent {
  final String appendedText;
  const NoteTextAppended(super.noteId, super.version, this.appendedText);
}

class NoteRecordingCompleted extends NoteEvent {
  const NoteRecordingCompleted(super.noteId, super.version);
}

class NotePublishingStarted extends NoteEvent {
  const NotePublishingStarted(super.noteId, super.version);
}

class NotePublished extends NoteEvent {
  final DateTime publishedAt;
  const NotePublished(super.noteId, super.version, this.publishedAt);
}

// Domain entities
class Note extends NoteView {
  Note._({
    required super.id,
    required super.text,
    required super.createdAt,
    super.publishedAt,
    required super.status,
    required super.version,
    required super.events,
  }) : super._();

  factory Note.create() {
    final id = const Uuid().v4();
    final initialSnapshot = NoteSnapshot(
      id: id,
      text: '',
      createdAt: DateTime.now(),
      publishedAt: null,
      status: NoteStatus.draft,
      version: 1,
    );
    final createdEvent = NoteCreated(id, 1, initialSnapshot);

    return Note._(
      id: id,
      text: '',
      createdAt: initialSnapshot.createdAt,
      publishedAt: null,
      status: NoteStatus.draft,
      version: 1,
      events: [createdEvent],
    );
  }

  Note _applyEvent(NoteEvent event) {
    // Skip if event version is old
    if (event.version <= version) {
      return this;
    }

    // Validate event version is consecutive
    if (event.version != version + 1) {
      throw InvalidNoteStateException(
        'Events must be consecutive. Expected version ${version + 1} but got ${event.version}'
      );
    }

    // Apply event based on type with business validation
    String text = this.text;
    DateTime? publishedAt = this.publishedAt;
    NoteStatus status = this.status;

    if (event is NoteRecordingStarted) {
      if (!canRecord) {
        throw InvalidNoteStateException(
          'Cannot apply NoteRecordingStarted: canRecord is false (current status: $status)'
        );
      }
      status = NoteStatus.recording;
    } else if (event is NoteTextAppended) {
      if (!isRecording) {
        throw InvalidNoteStateException(
          'Cannot apply NoteTextAppended: not currently recording (current status: $status)'
        );
      }
      text += event.appendedText;
    } else if (event is NoteRecordingCompleted) {
      if (!isRecording) {
        throw InvalidNoteStateException(
          'Cannot apply NoteRecordingCompleted: not currently recording (current status: $status)'
        );
      }
      status = NoteStatus.draft;
    } else if (event is NotePublishingStarted) {
      if (!canPublish) {
        throw InvalidNoteStateException(
          'Cannot apply NotePublishingStarted: canPublish is false (current status: $status, text isEmpty: ${text.isEmpty})'
        );
      }
      status = NoteStatus.publishing;
    } else if (event is NotePublished) {
      if (!isPublishing) {
        throw InvalidNoteStateException(
          'Cannot apply NotePublished: not currently publishing (current status: $status)'
        );
      }
      status = NoteStatus.published;
      publishedAt = event.publishedAt;
    }

    return Note._(
      id: id,
      text: text,
      createdAt: createdAt,
      publishedAt: publishedAt,
      status: status,
      version: event.version,
      events: [...events, event],
    );
  }

  Note _applyEvents(List<NoteEvent> events) {
    Note current = this;
    for (final event in events) {
      current = current._applyEvent(event);
    }
    return current;
  }

  Stream<Note> append(Stream<String> textStream) {
    if (!canRecord) {
      throw InvalidNoteStateException(
        'Cannot record note with status: $status'
      );
    }

    final controller = StreamController<Note>();

    // Start with recording status
    int currentVersion = version + 1;
    final recordingStartedEvent = NoteRecordingStarted(id, currentVersion);
    final recordingStartedEntity = _copyWith(
      status: NoteStatus.recording,
      version: currentVersion,
      newEvent: recordingStartedEvent,
    );
    controller.add(recordingStartedEntity);

    StreamSubscription<String>? recordingSubscription;
    // todo make joining with previous text more sophisticated (e.g. add period then space if appropriate)
    final existingText = '$text ';
    String latestTranscribedText = existingText;
    Note latestEntity = recordingStartedEntity;

    void cleanup() {
      recordingSubscription?.cancel();
    }

    // Start recording
    recordingSubscription = textStream.listen(
          (transcribedText) {
        final appendedText = transcribedText;
        latestTranscribedText = existingText + transcribedText;
        currentVersion++;
        final event = NoteTextAppended(id, currentVersion, appendedText);
        latestEntity = latestEntity._copyWith(
          text: latestTranscribedText,
          status: NoteStatus.recording,
          version: currentVersion,
          newEvent: event,
        );
        controller.add(latestEntity);
      },
      onDone: () {
        cleanup();
        currentVersion++;
        final event = NoteRecordingCompleted(id, currentVersion);
        final completedEntity = latestEntity._copyWith(
          text: latestTranscribedText,
          status: NoteStatus.draft,
          version: currentVersion,
          newEvent: event,
        );
        controller.add(completedEntity);
        controller.close();
      },
      onError: (error) {
        cleanup();
        controller.addError(error);
        controller.close();
      },
    );

    return controller.stream;
  }

  Stream<Note> publish(NotePublisher notePublisher) {
    if (!canPublish) {
      throw InvalidNoteStateException(
        'Cannot publish note with status: $status or empty text'
      );
    }

    final controller = StreamController<Note>();

    // Start with publishing status
    int currentVersion = version + 1;
    final publishingStartedEvent = NotePublishingStarted(id, currentVersion);
    final publishingEntity = _copyWith(
      status: NoteStatus.publishing,
      version: currentVersion,
      newEvent: publishingStartedEvent,
    );

    controller.add(publishingEntity);

    // Perform async publishing
    notePublisher.call(id, text).then((_) {
      currentVersion++;
      final publishedAt = DateTime.now();
      final publishedEvent = NotePublished(id, currentVersion, publishedAt);
      final publishedEntity = publishingEntity._copyWith(
        status: NoteStatus.published,
        publishedAt: publishedAt,
        version: currentVersion,
        newEvent: publishedEvent,
      );
      controller.add(publishedEntity);
      controller.close();
    }).catchError((error) {
      controller.addError(error);
      controller.close();
    });

    return controller.stream;
  }

  Note _copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    DateTime? publishedAt,
    NoteStatus? status,
    int? version,
    NoteEvent? newEvent,
  }) {
    final updatedEvents = newEvent != null
        ? [...events, newEvent]
        : events;
    return Note._(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      status: status ?? this.status,
      version: version ?? this.version,
      events: updatedEvents,
    );
  }
}