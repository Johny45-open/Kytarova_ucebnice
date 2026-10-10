import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';

class FlutterMidiWindowsPlugin {
  FlutterMidiWindowsPlugin._();

  static int _hMidiOut = 0;
  static DynamicLibrary? _winmmLib;

  /// Líně načte winmm.dll až při prvním reálném použití na Windows.
  /// Dřívější top-level `DynamicLibrary.open('winmm.dll')` padalo už při
  /// importu na Androidu/webu, kde DLL neexistuje.
  static DynamicLibrary? _loadWinmm() {
    if (_winmmLib != null) return _winmmLib;
    try {
      _winmmLib = DynamicLibrary.open('winmm.dll');
    } catch (_) {
      _winmmLib = null;
    }
    return _winmmLib;
  }

  static void registerWith() {
    MethodChannel('flutter_midi').setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'prepare_midi':
      case 'change_sound':
        return _openMidiOut();
      case 'play_midi_note':
        return _sendNote(_parseNote(call.arguments), true);
      case 'stop_midi_note':
        return _sendNote(_parseNote(call.arguments), false);
      default:
        throw MissingPluginException();
    }
  }

  /// Přímé Dart API pro Windows — obchází MethodChannel.
  ///
  /// DŮVOD: [FlutterMidi] volá `MethodChannel('flutter_midi').invokeMethod`,
  /// což jde vždy do nativního enginu. Na Windows ale žádný nativní kód
  /// neexistuje (dartPluginClass) a `registerWith()`/`setMethodCallHandler`
  /// obsluhuje jen směr nativ → Dart, takže `prepare_midi` končilo vždy
  /// `MissingPluginException`. Aplikace proto na Windows volá tyto metody
  /// přímo (jsou synchronní FFI, Future jen pro jednotné await).
  static Future<String> openOut() async => _openMidiOut();

  static Future<String> playNote(int note) async => _sendNote(note, true);

  static Future<String> stopNote(int note) async => _sendNote(note, false);

  static int _parseNote(Object? arguments) {
    if (arguments is Map) {
      final raw = arguments['note'];
      if (raw is num) return raw.toInt();
    }
    throw ArgumentError('play/stop_midi_note: chybí int "note"');
  }

  static String _openMidiOut() {
    final lib = _loadWinmm();
    if (lib == null) return 'error: winmm.dll not available';
    try {
      final midiOutOpen = lib.lookupFunction<
          Uint32 Function(Pointer<IntPtr>, Uint32, IntPtr, IntPtr, Uint32),
          int Function(Pointer<IntPtr>, int, int, int, int)>('midiOutOpen');
      final midiOutClose = lib.lookupFunction<Uint32 Function(IntPtr),
          int Function(int)>('midiOutClose');
      final midiOutShortMsg = lib.lookupFunction<Uint32 Function(IntPtr, Uint32),
          int Function(int, int)>('midiOutShortMsg');

      if (_hMidiOut != 0) {
        try {
          midiOutClose(_hMidiOut);
        } catch (_) {}
        _hMidiOut = 0;
      }

      // Zjisti, kolik je v systému MIDI výstupů. Když GS Wavetable chybí
      // nebo je zakázaný, vrátí midiOutOpen chybu 2 (BADDEVICEID) — pak
      // zkusíme ještě jednotlivá zařízení a když nic není, vrátíme
      // srozumitelnou hlášku místo strohého "error: 2".
      int numDevs = 0;
      try {
        final midiOutGetNumDevs =
            lib.lookupFunction<Uint32 Function(), int Function()>(
                'midiOutGetNumDevs');
        numDevs = midiOutGetNumDevs();
      } catch (_) {}

      // 0xFFFFFFFF = MIDI_MAPPER (výchozí zařízení), pak 0..n.
      final candidates = <int>[0xFFFFFFFF];
      for (int i = 0; i < numDevs; i++) {
        candidates.add(i);
      }

      String lastError =
          'V systému není žádné MIDI výstupní zařízení (Microsoft GS Wavetable Synth chybí nebo je zakázaný). Povolte jej ve Správci zařízení a zkuste to znovu.';
      for (final dev in candidates) {
        final phmo = calloc<IntPtr>();
        try {
          final result = midiOutOpen(phmo, dev, 0, 0, 0);
          if (result != 0) {
            lastError = result == 2
                ? 'V systému není žádné MIDI výstupní zařízení (Microsoft GS Wavetable Synth chybí nebo je zakázaný). Povolte jej ve Správci zařízení a zkuste to znovu.'
                : 'MIDI zařízení nelze otevřít (chyba $result).';
            continue;
          }
          _hMidiOut = phmo.value;
          midiOutShortMsg(_hMidiOut, 0xC0 | (24 << 8));
          return 'ok';
        } finally {
          calloc.free(phmo);
        }
      }
      return 'error: $lastError';
    } catch (e) {
      return 'error: $e';
    }
  }

  static String _sendNote(int note, bool noteOn) {
    if (_hMidiOut == 0) return 'not_open';
    if (note < 0 || note > 127) return 'error: note out of range: $note';
    final lib = _loadWinmm();
    if (lib == null) return 'error: winmm.dll not available';
    try {
      final midiOutShortMsg = lib.lookupFunction<
          Uint32 Function(IntPtr, Uint32),
          int Function(int, int)>('midiOutShortMsg');
      final int status = noteOn ? 0x90 : 0x80;
      final int velocity = noteOn ? 100 : 0;
      final int res = midiOutShortMsg(
          _hMidiOut, status | (note << 8) | (velocity << 16));
      if (res != 0) return 'error: midiOutShortMsg=$res';
      return 'ok';
    } catch (e) {
      return 'error: $e';
    }
  }

  /// Uzavře výstup (voláno např. při dalším prepare, aby nevisel handle).
  static String close() {
    final lib = _loadWinmm();
    if (lib == null || _hMidiOut == 0) {
      _hMidiOut = 0;
      return 'ok';
    }
    try {
      final midiOutClose = lib.lookupFunction<Uint32 Function(IntPtr),
          int Function(int)>('midiOutClose');
      final int res = midiOutClose(_hMidiOut);
      _hMidiOut = 0;
      return res == 0 ? 'ok' : 'error: $res';
    } catch (e) {
      _hMidiOut = 0;
      return 'error: $e';
    }
  }
}
