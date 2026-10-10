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
        return _sendNote(
          (call.arguments as Map)['note'] as int,
          true,
        );
      case 'stop_midi_note':
        return _sendNote(
          (call.arguments as Map)['note'] as int,
          false,
        );
      default:
        throw MissingPluginException();
    }
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
      final phmo = calloc<IntPtr>();
      try {
        final result = midiOutOpen(phmo, 0xFFFFFFFF, 0, 0, 0);
        if (result != 0) return 'error: $result';
        _hMidiOut = phmo.value;
        midiOutShortMsg(_hMidiOut, 0xC0 | (24 << 8));
        return 'ok';
      } finally {
        calloc.free(phmo);
      }
    } catch (e) {
      return 'error: $e';
    }
  }

  static String _sendNote(int note, bool noteOn) {
    if (_hMidiOut == 0) return 'not_open';
    final lib = _loadWinmm();
    if (lib == null) return 'error: winmm.dll not available';
    try {
      final midiOutShortMsg = lib.lookupFunction<
          Uint32 Function(IntPtr, Uint32),
          int Function(int, int)>('midiOutShortMsg');
      final int status = noteOn ? 0x90 : 0x80;
      final int velocity = noteOn ? 100 : 0;
      midiOutShortMsg(_hMidiOut, status | (note << 8) | (velocity << 16));
      return 'ok';
    } catch (e) {
      return 'error: $e';
    }
  }
}
