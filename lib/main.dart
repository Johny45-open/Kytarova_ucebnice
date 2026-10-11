import 'chord_logic.dart';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:flutter_midi/flutter_midi_windows.dart';
import 'services/tts_service.dart';

void main() {
  // Musí být první: inicializuje ServicesBinding/BinaryMessenger,
  // jinak jakýkoliv MethodChannel (vč. auto-registrace dartPluginClass
  // FlutterMidiWindowsPlugin) padne na "Null check operator used on a null value".
  WidgetsFlutterBinding.ensureInitialized();
  // Windows plugin je deklarován jako dartPluginClass a registruje ho
  // automaticky Flutter tooling. Pro jistotu se na Windows ještě
  // explicitně registruje v _setupMidi() (opakovaná registrace nevadí).
  runApp(const KytarovaUcebniceApp());
}

/// Model pro lekci
class Lesson {
  final String title;
  final String content;
  Lesson({required this.title, required this.content});
}

/// Model pro uložený akord
class SavedChord {
  final String name;
  final List<int> positions;
  SavedChord(this.name, List<int> pos) : positions = List.from(pos);
}

/// Globální úložiště dat (pro ukázku)
List<Lesson> myCustomLessons = [
  Lesson(
    title: '1. Jak držet kytaru',
    content:
        'Posaďte se na židli s rovnými zády. Kytaru položte výřezem na pravé stehno. Pravou ruku nechte volně viset přes tělo kytary.',
  ),
];
List<SavedChord> mySavedChords = [];

class KytarovaUcebniceApp extends StatelessWidget {
  const KytarovaUcebniceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kytarová učebnice',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainMenuPage(),
    );
  }
}

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kytarová učebnice')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Lekce'),
            subtitle: Text('${myCustomLessons.length} lekcí k dispozici'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LessonsListPage(),
                ),
              );
              setState(() {}); // Obnovit po návratu
            },
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Editor akordů'),
            subtitle: const Text('Vytvořte si vlastní hmaty'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChordEditorPage(),
                ),
              );
              setState(() {});
            },
          ),
          if (mySavedChords.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Uložené akordy',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...mySavedChords.map(
              (chord) => ListTile(
                title: Text(chord.name),
                trailing: const Icon(Icons.volume_up),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Akord ${chord.name} vybrán.')),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Seznam lekcí s možností přidání
class LessonsListPage extends StatefulWidget {
  const LessonsListPage({super.key});

  @override
  State<LessonsListPage> createState() => _LessonsListPageState();
}

class _LessonsListPageState extends State<LessonsListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moje lekce')),
      body: ListView.builder(
        itemCount: myCustomLessons.length,
        itemBuilder: (context, index) {
          final lesson = myCustomLessons[index];
          return ListTile(
            title: Text(lesson.title),
            subtitle: Text(
              lesson.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LessonDetailPage(lesson: lesson),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Vytvořit novou lekci',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddLessonPage()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Detail lekce s hlasovým předčítáním (TtsService).
class LessonDetailPage extends StatefulWidget {
  final Lesson lesson;
  const LessonDetailPage({super.key, required this.lesson});

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  final TtsService _tts = TtsService();

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _readLesson() async {
    await _tts.speak('${widget.lesson.title}. ${widget.lesson.content}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Přečíst lekci',
            onPressed: _readLesson,
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'Zastavit čtení',
            onPressed: _tts.stop,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lesson.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              widget.lesson.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stránka pro přidání nové lekce
class AddLessonPage extends StatefulWidget {
  const AddLessonPage({super.key});

  @override
  State<AddLessonPage> createState() => _AddLessonPageState();
}

class _AddLessonPageState extends State<AddLessonPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Automatický fokus na název při otevření
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _titleFocusNode.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vytvořit lekci')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              decoration: const InputDecoration(
                labelText: 'Název lekce',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Obsah lekce (teorie)',
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Uložit lekci'),
                onPressed: () {
                  if (_titleController.text.isNotEmpty) {
                    myCustomLessons.add(
                      Lesson(
                        title: _titleController.text,
                        content: _contentController.text,
                      ),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lekce byla uložena.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stránka pro tvorbu vlastních akordů
class ChordEditorPage extends StatefulWidget {
  const ChordEditorPage({super.key});

  @override
  State<ChordEditorPage> createState() => _ChordEditorPageState();
}

class _ChordEditorPageState extends State<ChordEditorPage> {
  final _flutterMidi = FlutterMidi();
  final TtsService _tts = TtsService();
  bool _midiReady = false;
  String? _midiError;
  final ChordLogic _logic = ChordLogic();
  int _startFret = 1;

  void _changeRange(int delta) {
    setState(() {
      _startFret = (_startFret + delta).clamp(1, 21);
      // Zarovnání na začátky rozsahů (1, 6, 11, 16, 21)
      if (_startFret > 1) {
         _startFret = (((_startFret - 1) / 5).floor() * 5) + 1;
      } else {
         _startFret = 1;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // MIDI start až po prvním framu: _setupMidi sahá na stav a dřív
    // zobrazoval SnackBar během push-transition, což na Windows padalo
    // na "Null check operator used on a null value" ve frameworku.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setupMidi();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speakDescription(String text) => _tts.speak(text);

  /// Na Windows volá winmm FFI napřímo (MethodChannel tam nemá nativní
  /// protistranu a končil by vždy MissingPluginException). Na ostatních
  /// platformách jde přes MethodChannel + sf2 soubor.
  Future<String?> _midiPrepare(ByteData sf2) {
    if (Platform.isWindows) return FlutterMidiWindowsPlugin.openOut();
    return _flutterMidi.prepare(sf2: sf2, name: 'guitar.sf2');
  }

  Future<String?> _midiPlay(int midi) {
    if (Platform.isWindows) return FlutterMidiWindowsPlugin.playNote(midi);
    return _flutterMidi.playMidiNote(midi: midi);
  }

  Future<String?> _midiStop(int midi) {
    if (Platform.isWindows) return FlutterMidiWindowsPlugin.stopNote(midi);
    return _flutterMidi.stopMidiNote(midi: midi);
  }

  Future<void> _setupMidi() async {
    try {
      String? res;
      if (Platform.isWindows) {
        // winmm nepotřebuje sf2, stačí otevřít MIDI mapper.
        // sf2 asset se nenačítá, aby chyba v balíčku neblokovala zvuk.
        res = await FlutterMidiWindowsPlugin.openOut();
      } else {
        ByteData byte = await rootBundle.load('assets/guitar.sf2');
        res = await _midiPrepare(byte);
      }
      debugPrint('MIDI prepare: $res');
      _midiReady = (res == 'ok');
      _midiError = _midiReady ? null : res;
    } on MissingPluginException catch (e) {
      _midiReady = false;
      _midiError = 'MIDI plugin není registrován: $e';
      debugPrint(_midiError);
    } catch (e) {
      _midiReady = false;
      _midiError = e.toString();
      debugPrint('MIDI nenastaveno: $e');
    }
    // Žádný SnackBar při otevření stránky (padal framework během
    // transition). Chyba se ukáže jako inline pruh ve stránce (viz build)
    // a SnackBar až po explicitním tapnutí na Přehrát. Jen překreslit.
    if (mounted) setState(() {});
  }

  /// Chyba bez strohého prefixu 'error: ' pro zobrazení uživateli.
  String get _midiErrorText {
    final e = _midiError;
    if (e == null) return '';
    return e.startsWith('error: ') ? e.substring('error: '.length) : e;
  }

  void _setBarre(int fret) {
    setState(() {
      _logic.setBarre(fret);
    });
  }

  void _setBarreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vybrat barré pražec'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
            itemCount: 24,
            itemBuilder: (context, index) {
              final fret = index + 1;
              return TextButton(
                onPressed: () {
                  _setBarre(fret);
                  Navigator.pop(context);
                },
                child: Text('$fret'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
        ],
      ),
    );
  }

  Future<void> _playChord() async {
    if (!_midiReady) {
      await _setupMidi(); // jeden pokus o zotavení
      if (!_midiReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Akord nelze přehrát: ${_midiErrorText.isNotEmpty ? _midiErrorText : 'MIDI není připraveno'}',
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Přehrávám akord...'),
        duration: Duration(seconds: 1),
      ),
    );

    final List<int> played = [];
    try {
      for (int i = 0; i < 6; i++) {
        int fret = _logic.fingerPositions[i];
        if (fret == -1) continue; // X
        // Pokud 0, prázdná struna -> fret 0
        final midi = _logic.midiBaseNotes[i] + (fret == 0 ? 0 : fret);
        final res = await _midiPlay(midi);
        debugPrint('play $midi -> $res');
        if (res == 'not_open' || (res?.startsWith('error') ?? false)) {
          throw Exception(res);
        }
        played.add(midi);
        await Future.delayed(const Duration(milliseconds: 120));
      }
      await Future.delayed(const Duration(milliseconds: 600));
    } on MissingPluginException catch (e) {
      _midiReady = false;
      _midiError = 'MIDI plugin není registrován: $e';
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akord nelze přehrát: $_midiError')),
        );
      }
    } catch (e) {
      _midiReady = false;
      _midiError = e.toString();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akord nelze přehrát: $_midiErrorText')),
        );
      }
    } finally {
      for (final m in played) {
        try {
          await _midiStop(m);
        } catch (_) {}
      }
    }
  }

  void _readChord() {
    final text = _logic.getChordDescription();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Popis hmatu'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () {
                _speakDescription(text);
              },
              child: const Text('Přehrát popis'),
            ),
            TextButton(
              onPressed: () {
                _tts.stop();
              },
              child: const Text('Zastavit'),
            ),
            TextButton(
              onPressed: () {
                _tts.stop();
                Navigator.pop(dialogContext);
              },
              child: const Text('Zavřít'),
            ),
          ],
        );
      },
    ).then((_) {
      _tts.stop();
    });
  }

  void _saveChordDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uložit akord'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Název akordu'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                mySavedChords.add(
                  SavedChord(controller.text, _logic.fingerPositions),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Akord byl uložen.')),
                );
              }
            },
            child: const Text('Uložit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor akordů'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Přehrát',
            onPressed: _playChord,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Uložit',
            onPressed: _saveChordDialog,
          ),
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Popsat',
            onPressed: _readChord,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_midiError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.volume_off,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Zvuk není dostupný: $_midiErrorText',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
  // Barré ovládání
            const Text('Barré:'),
            OutlinedButton(
              onPressed: _setBarreDialog,
              child: const Text('Vybrat barré (1-24)'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _setBarre(-1),
                  child: const Text('Zrušit barré (X)'),
                ),
              ],
            ),
            const Divider(),
            // Ovládání rozsahu
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _startFret > 1 ? () => _changeRange(-5) : null,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Předchozí rozsah',
                ),
                Text(
                  'Rozsah: $_startFret–${(_startFret + 4).clamp(1, 24)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _startFret < 21 ? () => _changeRange(5) : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Další rozsah',
                ),
              ],
            ),
            const Divider(),
            // Struny
            Table(
              border: TableBorder.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const Center(child: Text('Str.')),
                    ...List.generate(
                      _startFret == 21 ? 4 : 5,
                      (i) => Center(child: Text('${_startFret + i}')),
                    ),
                  ],
                ),
                ...List.generate(6, (sIdx) {
                  return TableRow(
                    children: [
                      // První sloupec: Název struny + interakce pro X/O
                      Semantics(
                        label:
                            'Struna ${_logic.stringNames[sIdx]}, aktuální stav: ${_logic.fingerPositions[sIdx] == -1 ? 'nehraje X' : (_logic.fingerPositions[sIdx] == 0 ? 'prázdná O' : 'pražec ${_logic.fingerPositions[sIdx]}')}. Klepněte pro změnu stavu.',
                        button: true,
                        child: TextButton(
                          onPressed: () => _showStatusDialog(sIdx),
                          child: Text(
                            '${_logic.stringNames[sIdx].split(' ')[0]} (${_logic.fingerPositions[sIdx] == -1 ? 'X' : (_logic.fingerPositions[sIdx] == 0 ? 'O' : _logic.fingerPositions[sIdx])})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      ...List.generate(_startFret == 21 ? 4 : 5, (fIdx) {
                        final fret = _startFret + fIdx;
                        final isPressed = _logic.fingerPositions[sIdx] == fret;
                        
                        return Semantics(
                          label: 'Struna ${_logic.stringNames[sIdx]}, pražec $fret, ${isPressed ? "vybráno" : "nevybráno"}',
                          button: true,
                          onTap: () {
                            setState(() {
                              _logic.setPosition(
                                sIdx,
                                (_logic.fingerPositions[sIdx] == fret)
                                    ? -1
                                    : fret,
                              );
                            });
                          },
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _logic.setPosition(
                                  sIdx,
                                  (_logic.fingerPositions[sIdx] == fret)
                                      ? -1
                                      : fret,
                                );
                              });
                            },
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text('$fret'),
                                  if (isPressed)
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(int sIdx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Struna ${_logic.stringNames[sIdx]}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('X – nehrát'),
              onTap: () {
                setState(() => _logic.setPosition(sIdx, -1));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('O – prázdná struna'),
              onTap: () {
                setState(() => _logic.setPosition(sIdx, 0));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
