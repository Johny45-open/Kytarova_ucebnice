import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Jednotné potvrzování akcí: vizuální SnackBar + explicitní oznámení
/// pro odečítač obrazovky.
///
/// Proč obojí: SnackBar samotný čtečka po zavření dialogu často neohlásí
/// (událost zavření dialogu ho přehluší, typicky NVDA na Windows).
/// `SemanticsService.announce` je jediná spolehlivá cesta, jak čtečce
/// na všech platformách říct jednu větu. TTS (flutter_tts) se na
/// potvrzení nepoužívá, aby nemluvily dva hlasy přes sebe.
Future<void> showFeedback(BuildContext context, String message) async {
  if (!context.mounted) return;
  final view = View.of(context);
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  // Nejdřív nechat čtečku doříct zavření dialogu, pak teprve oznámit
  // výsledek. Bez prodlevy NVDA oznámení spolkne.
  await Future.delayed(const Duration(milliseconds: 300));
  try {
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
  } catch (_) {
    // Oznámení je best-effort; SnackBar zůstává.
  }
}
