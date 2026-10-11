import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Sdílený hlasový výstup, vzor dle mluvici_pristupna_minutka a
/// pristupna_mluvici_hraci_kostka: nejdřív setLanguage, pak
/// rate/volume/pitch. Žádné awaitSpeakCompletion, getVoices ani
/// isLanguageAvailable gate (ty na Windows/Android blokovaly mluvení).
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('cs-CZ');
    } catch (e) {
      debugPrint('TTS setLanguage selhalo: $e');
    }
    try {
      await _tts.setSpeechRate(0.5);
    } catch (e) {
      debugPrint('TTS setSpeechRate selhalo: $e');
    }
    try {
      await _tts.setVolume(1.0);
    } catch (e) {
      debugPrint('TTS setVolume selhalo: $e');
    }
    try {
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS setPitch selhalo: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak selhalo: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop selhalo: $e');
    }
  }
}
