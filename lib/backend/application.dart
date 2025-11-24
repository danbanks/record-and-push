import 'dart:async';

import 'package:flutter/foundation.dart';

import 'core.dart';

abstract class NoteListProjection extends ChangeNotifier {
  List<NoteProjection> get snapshot;
}

abstract class NoteRepository {
  Future<void> init();
  Future<NoteProjection> save(Note note);
  Future<void> delete(String id);
  Future<NoteListProjection> getAll();
  Future<NoteListProjection> getByStatus(NoteStatus status);
  Future<NoteProjection?> getById(String id);
}

abstract class NoteProjection extends ChangeNotifier {
  Note get snapshot;
}

class NoteApplication {
  final NoteRepository _noteRepository;

  NoteApplication(
    this._noteRepository
  );

  Future<NoteProjection> recordNewNote(Stream<String> textStream) async {
    final note = Note.create();
    final projection = await _noteRepository.save(note);

    _startRecording(note, textStream);

    return projection;
  }

  Future<void> recordOnExistingNote(String noteId, Stream<String> text) async {
    final noteProjection = await _noteRepository.getById(noteId);
    if (noteProjection == null) {
      throw Exception('Note not found');
    }
    final note = noteProjection.snapshot;

    if (!note.canRecord) {
      throw Exception('Cannot record in current state');
    }

    await _startRecording(note, text);
  }

  Future<void> _startRecording(Note targetNote, Stream<String> text) async {

    /* TODO
           Stop saving on every additional word appended to note. This
         is too heavy for any repo implementation that is not in-memory.
          */
    await for (final updatedNote in targetNote.append(text)) {
      await _noteRepository.save(updatedNote);
    }
  }

  Future<void> publishNote(String noteId) async {
    final noteProjection = await _noteRepository.getById(noteId);
    if (noteProjection == null) {
      throw Exception('Note not found');
    }
    final note = noteProjection.snapshot;

    if (!note.canPublish) {
      throw Exception('Cannot publish in current state');
    }

    // Start publishing in background
    _startPublishing(note);
  }

  void _startPublishing(Note note) async {
    // todo actually publish somewhere
    await for (final updatedNote in note.publish((id, text) => Future.value(null))) {
      await _noteRepository.save(updatedNote);
    }
  }

  Future<NoteListProjection> getAllNotes() {
    return _noteRepository.getAll();
  }

  Future<NoteListProjection> getNotesByStatus(NoteStatus status) {
    return _noteRepository.getByStatus(status);
  }
}
