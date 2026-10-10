import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';

void main() {
  // Musí být první: inicializuje ServicesBinding/BinaryMessenger,
  // jinak jakýkoliv MethodChannel (vč. auto-registrace dartPluginClass
  // FlutterMidiWindowsPlugin) padne na "Null check operator used on a null value".
  WidgetsFlutterBinding.ensureInitialized();
  // POZOR: FlutterMidiWindowsPlugin.registerWith() se NEVOLÁ ručně.
  // Windows plugin je deklarován jako dartPluginClass a registruje ho
  // automaticky Flutter tooling až po inicializaci bindingu.
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
    content: 'Posaďte se na židli s rovnými zády. Kytaru položte výřezem na pravé stehno. Pravou ruku nechte volně viset přes tělo kytary.',
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown, brightness: Brightness.dark),
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
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const LessonsListPage()));
              setState(() {}); // Obnovit po návratu
            },
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Editor akordů'),
            subtitle: const Text('Vytvořte si vlastní hmaty'),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const ChordEditorPage()));
              setState(() {});
            },
          ),
          if (mySavedChords.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Uložené akordy', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...mySavedChords.map((chord) => ListTile(
              title: Text(chord.name),
              trailing: const Icon(Icons.volume_up),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Akord ${chord.name} vybrán.')),
                );
              },
            )),
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
            subtitle: Text(lesson.content, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LessonDetailPage(lesson: lesson)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Vytvořit novou lekci',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddLessonPage()));
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Detail lekce
class LessonDetailPage extends StatelessWidget {
  final Lesson lesson;
  const LessonDetailPage({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(lesson.content, style: Theme.of(context).textTheme.bodyLarge),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _titleFocusNode.requestFocus());
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
                    myCustomLessons.add(Lesson(
                      title: _titleController.text,
                      content: _contentController.text,
                    ));
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
  final List<int> _fingerPositions = List.filled(6, -1);
  final List<String> _stringNames = ['E tlusté', 'A', 'D', 'G', 'H', 'e tenké'];
  final List<int> _midiBaseNotes = [40, 45, 50, 55, 59, 64];

  @override
  void initState() {
    super.initState();
    _setupMidi();
  }

  Future<void> _setupMidi() async {
    try {
      ByteData byte = await rootBundle.load("assets/guitar.sf2");
      _flutterMidi.prepare(sf2: byte, name: "guitar.sf2");
    } catch (e) {
      debugPrint("MIDI nenastaveno: $e");
    }
  }

  void _togglePosition(int sIdx, int fret) {
    setState(() {
      _fingerPositions[sIdx] = (_fingerPositions[sIdx] == fret) ? -1 : fret;
    });
  }

  void _setBarre(int fret) {
    setState(() {
      bool allSet = _fingerPositions.every((p) => p == fret);
      for (int i = 0; i < 6; i++) {
        _fingerPositions[i] = allSet ? -1 : fret;
      }
    });
  }

  Future<void> _playChord() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Přehrávám akord...'), duration: Duration(seconds: 1)),
    );

    for (int i = 0; i < 6; i++) {
      int fret = _fingerPositions[i];
      if (fret != -1) {
        _flutterMidi.playMidiNote(midi: _midiBaseNotes[i] + fret);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  String _getChordDescription() {
    List<String> desc = [];
    for (int i = 0; i < 6; i++) {
      String pos = _fingerPositions[i] == -1 ? 'nehraje' : (_fingerPositions[i] == 0 ? 'prázdná' : '${_fingerPositions[i]}. pražec');
      desc.add('${_stringNames[i]}: $pos');
    }
    return desc.join(', ');
  }

  void _readChord() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Popis hmatu'),
        content: Text(_getChordDescription()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zavřít')),
        ],
      ),
    );
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušit')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                mySavedChords.add(SavedChord(controller.text, _fingerPositions));
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
          IconButton(icon: const Icon(Icons.play_arrow), tooltip: 'Přehrát', onPressed: _playChord),
          IconButton(icon: const Icon(Icons.save), tooltip: 'Uložit', onPressed: _saveChordDialog),
          IconButton(icon: const Icon(Icons.volume_up), tooltip: 'Popsat', onPressed: _readChord),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Table(
              border: TableBorder.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const Center(child: Text('B')),
                    ...List.generate(5, (fIdx) => Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: OutlinedButton(
                        onPressed: () => _setBarre(fIdx + 1),
                        child: Text('${fIdx + 1}'),
                      ),
                    )),
                  ],
                ),
                TableRow(
                  children: [
                    const Center(child: Text('Str.')),
                    ...List.generate(5, (i) => Center(child: Text('${i + 1}'))),
                  ],
                ),
                ...List.generate(6, (sIdx) {
                  return TableRow(
                    children: [
                      Center(child: Text(_stringNames[sIdx].split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold))),
                      ...List.generate(5, (fIdx) {
                        final fret = fIdx + 1;
                        final isPressed = _fingerPositions[sIdx] == fret;
                        return InkWell(
                          onTap: () => _togglePosition(sIdx, fret),
                          child: Semantics(
                            label: 'Struna ${_stringNames[sIdx]}, pražec $fret',
                            selected: isPressed,
                            button: true,
                            child: Container(
                              height: 45,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPressed ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                              ),
                              child: isPressed ? Icon(Icons.circle, color: Theme.of(context).colorScheme.onPrimary, size: 14) : null,
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
}
