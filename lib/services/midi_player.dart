import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:flutter_midi/flutter_midi_windows.dart';

/// Sdílené MIDI přehrávání hmatu pro editor i seznam uložených akordů.
/// Na Windows jde napřímo přes winmm FFI, jinde přes MethodChannel + sf2.
class MidiChordPlayer {
  final FlutterMidi _flutterMidi = FlutterMidi();
  bool ready = false;
  String? error;

  String get errorText {
    final e = error;
    if (e == null) return '';
    return e.startsWith('error: ') ? e.substring('error: '.length) : e;
  }

  Future<String?> _prepare(ByteData sf2) {
    if (Platform.isWindows) return FlutterMidiWindowsPlugin.openOut();
    return _flutterMidi.prepare(sf2: sf2, name: 'guitar.sf2');
  }

  Future<String?> playNote(int midi) {
    if (Platform.isWindows) return FlutterMidiWindowsPlugin.playNote(midi);
    return _flutterMidi.playMidiNote(midi: midi);
  }

  Future<String?> stopNote(int midi) {
    if (Platform.isWindows) return FlutterMidiWindowsPlugin.stopNote(midi);
    return _flutterMidi.stopMidiNote(midi: midi);
  }

  Future<bool> ensureReady({Future<ByteData> Function()? loadSf2}) async {
    if (ready) return true;
    try {
      String? res;
      if (Platform.isWindows) {
        res = await FlutterMidiWindowsPlugin.openOut();
      } else {
        final byte = loadSf2 != null
            ? await loadSf2()
            : await rootBundle.load('assets/guitar.sf2');
        res = await _prepare(byte);
      }
      debugPrint('MIDI prepare: $res');
      ready = (res == 'ok');
      error = ready ? null : res;
      return ready;
    } on MissingPluginException catch (e) {
      ready = false;
      error = 'MIDI plugin není registrován: $e';
      return false;
    } catch (e) {
      ready = false;
      error = e.toString();
      return false;
    }
  }

  /// Přehraje pozice [positions] (6 strun, -1 = nehrát, 0 = prázdná).
  Future<void> playPositions(
    List<int> positions,
    List<int> baseNotes,
  ) async {
    final played = <int>[];
    try {
      for (int i = 0; i < 6 && i < positions.length; i++) {
        final fret = positions[i];
        if (fret == -1) continue;
        final midi = baseNotes[i] + (fret == 0 ? 0 : fret);
        final res = await playNote(midi);
        if (res == 'not_open' || (res?.startsWith('error') ?? false)) {
          throw Exception(res);
        }
        played.add(midi);
        await Future.delayed(const Duration(milliseconds: 120));
      }
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      for (final m in played) {
        try {
          await stopNote(m);
        } catch (_) {}
      }
    }
  }
}
