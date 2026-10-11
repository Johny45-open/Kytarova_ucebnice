import 'chord_logic.dart';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/chord_storage.dart';
import 'services/feedback.dart';
import 'services/midi_player.dart';
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

// SavedChord žije v chord_logic.dart (JSON + popis pro čtečku).
// Re-export pro zpětnou kompatibilitu testů importujících main.dart.

/// Globální úložiště dat (pro ukázku)
List<Lesson> myCustomLessons = [
  Lesson(
    title: '1. Jak držet kytaru',
    content:
        'Posaďte se na židli s rovnými zády. Kytaru položte výřezem na pravé stehno. Pravou ruku nechte volně viset přes tělo kytary.',
  ),
];
List<SavedChord> mySavedChords = [];
List<ChordFolder> myChordFolders = [];

/// Uloží celou knihovnu (složky + akordy). Nikdy nepadá, jen zaloguje.
Future<void> persistLibrary() async {
  try {
    await ChordStorage().saveLibrary(
      ChordLibrary(folders: myChordFolders, chords: mySavedChords),
    );
  } catch (e) {
    debugPrint('Uložení knihovny selhalo: $e');
  }
}

class KytarovaUcebniceApp extends StatelessWidget {
  const KytarovaUcebniceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kytarová učebnice',
      locale: const Locale('cs'),
      supportedLocales: const [Locale('cs')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  bool _chordsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChords();
  }

  Future<void> _loadChords() async {
    try {
      final library = await ChordStorage().loadLibrary();
      myChordFolders = library.folders;
      mySavedChords = library.chords;
    } catch (_) {
      myChordFolders = [];
      mySavedChords = [];
    }
    if (mounted) setState(() => _chordsLoading = false);
  }

  Future<void> _openSavedChords() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedChordsPage()),
    );
    if (mounted) setState(() {});
  }

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
          ListTile(
            leading: const Icon(Icons.library_music),
            title: const Text('Uložené akordy'),
            subtitle: Text(
              _chordsLoading
                  ? 'Načítám…'
                  : mySavedChords.isEmpty && myChordFolders.isEmpty
                  ? 'Zatím žádné uložené akordy'
                  : _librarySubtitle(),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openSavedChords,
          ),
        ],
      ),
    );
  }

  String _chordCountWord(int n) {
    if (n == 1) return 'akord';
    if (n >= 2 && n <= 4) return 'akordy';
    return 'akordů';
  }

  String _folderCountWord(int n) {
    if (n == 1) return 'složka';
    if (n >= 2 && n <= 4) return 'složky';
    return 'složek';
  }

  String _librarySubtitle() {
    final c = mySavedChords.length;
    final f = myChordFolders.length;
    final chords = '$c ${_chordCountWord(c)}';
    if (f == 0) return '$chords k dispozici';
    return '$chords v $f ${_folderCountWord(f)}';
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
  String? _titleError;

  @override
  void initState() {
    super.initState();
    // Automatický fokus na název při otevření
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _titleFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      // Chyba zůstane v errorText -> čtečka ji přečte, dialog se nezavře.
      setState(() => _titleError = 'Zadejte název lekce');
      _titleFocusNode.requestFocus();
      return;
    }
    myCustomLessons.add(
      Lesson(title: title, content: _contentController.text),
    );
    Navigator.pop(context);
    // SnackBar se ukáže až na předchozí stránce; context této stránky
    // je po popu mrtvý, proto hlášku nezobrazujeme zde.
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
              decoration: InputDecoration(
                labelText: 'Název lekce',
                errorText: _titleError,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
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
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stránka pro tvorbu vlastních akordů.
/// [initial] = načtený uložený akord k úpravě; null = nový hmat.
/// [folderId] = složka pro nový akord (z detailu složky); null = Bez složky.
class ChordEditorPage extends StatefulWidget {
  final SavedChord? initial;
  final String? folderId;
  const ChordEditorPage({super.key, this.initial, this.folderId});

  @override
  State<ChordEditorPage> createState() => _ChordEditorPageState();
}

class _ChordEditorPageState extends State<ChordEditorPage> {
  final MidiChordPlayer _midi = MidiChordPlayer();
  final TtsService _tts = TtsService();
  bool get _midiReady => _midi.ready;
  String? get _midiError => _midi.error?.toString();
  final ChordLogic _logic = ChordLogic();
  static const int _visibleFrets = 7;
  static const int _maxStartFret = 24 - _visibleFrets + 1; // 18
  int _startFret = 1;

  void _changeRange(int delta) {
    setState(() {
      // Volný posun po 1 pražci, aby šly vedle sebe zobrazit např.
      // pražce 5–8 (G dur hmatem D dur: 5, 7, 8, 7).
      _startFret = (_startFret + delta).clamp(1, _maxStartFret);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      for (int i = 0; i < 6; i++) {
        _logic.fingerPositions[i] = widget.initial!.positions[i];
      }
      // Pokud je hmat mimo výchozí výřez, posunout výřez na první hmat.
      final pressed = _logic.fingerPositions
          .where((p) => p > 0)
          .toList();
      if (pressed.isNotEmpty) {
        final minFret = pressed.reduce((a, b) => a < b ? a : b);
        _startFret = minFret.clamp(1, _maxStartFret);
        // Aby byl celý hmat vidět, když začíná nad 1.
        if (_startFret > 1 && _startFret + _visibleFrets - 1 < pressed.reduce((a,b)=>a>b?a:b)) {
          _startFret = (pressed.reduce((a,b)=>a>b?a:b) - _visibleFrets + 1).clamp(1, _maxStartFret);
        }
      }
    }
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

  Future<void> _setupMidi() async {
    final ok = await _midi.ensureReady(
      loadSf2: Platform.isWindows ? null : () => rootBundle.load('assets/guitar.sf2'),
    );
    if (!ok) debugPrint('MIDI nenastaveno: ${_midi.error}');
    // Žádný SnackBar při otevření stránky (padal framework během
    // transition). Chyba se ukáže jako inline pruh ve stránce (viz build)
    // a SnackBar až po explicitním tapnutí na Přehrát. Jen překreslit.
    if (mounted) setState(() {});
  }

  /// Chyba bez strohého prefixu 'error: ' pro zobrazení uživateli.
  String get _midiErrorText => _midi.errorText;

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
                child: Text(
                  '$fret',
                  semanticsLabel: 'Barré pražec $fret',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
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

    try {
      await _midi.playPositions(
        _logic.fingerPositions,
        _logic.midiBaseNotes,
      );
    } on MissingPluginException catch (e) {
      _midi.ready = false;
      _midi.error = 'MIDI plugin není registrován: $e';
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akord nelze přehrát: ${_midi.error}')),
        );
      }
    } catch (e) {
      _midi.ready = false;
      _midi.error = e.toString();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akord nelze přehrát: $_midiErrorText')),
        );
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
          // SelectableText je Tab-fokusovatelný, čtečka ho přečte celá.
          content: SelectableText(text),
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
              autofocus: true,
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
    final forbidden = mySavedChords
        .where((c) => c != widget.initial)
        .map((c) => c.name)
        .toSet();
    showDialog<String>(
      context: context,
      builder: (_) => _ChordNameDialog(
        title: 'Uložit akord',
        label: 'Název akordu',
        confirmLabel: 'Uložit',
        initial: widget.initial?.name ?? '',
        forbiddenNames: forbidden,
      ),
    ).then((name) async {
      if (name == null) return;
      if (widget.initial != null) {
        widget.initial!.name = name;
        widget.initial!.positions.setAll(0, _logic.fingerPositions);
      } else {
        mySavedChords.add(
          SavedChord(
            name,
            _logic.fingerPositions,
            folderId: widget.folderId,
          ),
        );
      }
      await persistLibrary();
      if (!mounted) return;
      await showFeedback(context, 'Akord $name byl uložen.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final editingName = widget.initial?.name;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editingName == null ? 'Editor akordů' : 'Úprava: $editingName',
        ),
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
                        ExcludeSemantics(
                          child: Icon(
                            Icons.volume_off,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
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
                  onPressed: _startFret > 1 ? () => _changeRange(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Předchozí pražec',
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Rozsah: $_startFret–${_startFret + _visibleFrets - 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed:
                      _startFret < _maxStartFret ? () => _changeRange(1) : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Další pražec',
                ),
              ],
            ),
            const Divider(),
            // Struny – horizontální scroll pro velké písmo / malé displeje.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: Table(
              border: TableBorder.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const Center(child: Text('Str.')),
                    ...List.generate(
                      _visibleFrets,
                      (i) => Center(child: Text('${_startFret + i}')),
                    ),
                  ],
                ),
                ...List.generate(6, (sIdx) {
                  return TableRow(
                    children: [
                      // První sloupec: jedno standardní tlačítko. Plný label
                      // přes Text.semanticsLabel, žádný Semantics wrapper.
                      TextButton(
                        onPressed: () => _showStatusDialog(sIdx),
                        child: Text(
                          '${_logic.stringNames[sIdx].split(' ')[0]} (${_logic.fingerPositions[sIdx] == -1 ? 'X' : (_logic.fingerPositions[sIdx] == 0 ? 'O' : _logic.fingerPositions[sIdx])})',
                          semanticsLabel:
                              'Struna ${_logic.stringNames[sIdx]}, aktuální stav: ${_logic.fingerPositions[sIdx] == -1 ? 'nehraje X' : (_logic.fingerPositions[sIdx] == 0 ? 'prázdná O' : 'pražec ${_logic.fingerPositions[sIdx]}')}. Klepněte pro změnu stavu.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...List.generate(_visibleFrets, (fIdx) {
                        final fret = _startFret + fIdx;
                        final isPressed = _logic.fingerPositions[sIdx] == fret;

                        // Jedno standardní tlačítko (návrat k osvědčenému
                        // vzoru z dřívější verze): Tab + Enter/Mezerník +
                        // focus ring + čtečka zdarma. Plný label přes
                        // Text.semanticsLabel, stav přes pozadí + puntík.
                        // Žádný Semantics wrapper ani InkWell.
                        return OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isPressed
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            minimumSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _logic.setPosition(
                                sIdx,
                                (_logic.fingerPositions[sIdx] == fret)
                                    ? -1
                                    : fret,
                              );
                            });
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$fret',
                                semanticsLabel:
                                    'Struna ${_logic.stringNames[sIdx]}, pražec $fret, ${isPressed ? "vybráno" : "nevybráno"}',
                              ),
                              if (isPressed)
                                ExcludeSemantics(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
                ),
              ),
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
        content: RadioGroup<int>(
          groupValue: _logic.fingerPositions[sIdx],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _logic.setPosition(sIdx, v));
            Navigator.pop(context);
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nativní přepínače: Tab + šipky/Mezerník + focus ring +
              // ohlášení stavu čtečkou zdarma. ListTile s onTap by Tab
              // přeskočil (staví na InkWell).
              RadioListTile<int>(
                title: Text('X – nehrát'),
                value: -1,
              ),
              RadioListTile<int>(
                title: Text('O – prázdná struna'),
                value: 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
        ],
      ),
    );
  }
}

/// Seznam uložených akordů: načtení do editoru, přehrání, přejmenování,
/// smazání. Každý řádek má plný popis hmatu pro čtečku.
class SavedChordsPage extends StatefulWidget {
  const SavedChordsPage({super.key});

  @override
  State<SavedChordsPage> createState() => _SavedChordsPageState();
}

class _SavedChordsPageState extends State<SavedChordsPage>
    with ChordActions<SavedChordsPage> {
  @override
  void dispose() {
    disposeActions();
    super.dispose();
  }

  Future<void> _openFolder(ChordFolder folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FolderDetailPage(folder: folder)),
    );
    await persistLibrary();
    if (mounted) setState(() {});
  }

  void _createFolder() {
    final forbidden = myChordFolders.map((f) => f.name).toSet();
    showDialog<String>(
      context: context,
      builder: (_) => _ChordNameDialog(
        title: 'Nová složka',
        label: 'Název složky',
        confirmLabel: 'Vytvořit',
        initial: '',
        forbiddenNames: forbidden,
        emptyErrorText: 'Zadejte název složky',
        duplicateErrorText: 'Tato složka už existuje',
      ),
    ).then((name) async {
      if (name == null) return;
      myChordFolders.add(
        ChordFolder(id: ChordStorage.newFolderId(), name: name),
      );
      await persistLibrary();
      if (!mounted) return;
      setState(() {});
      await showFeedback(context, 'Složka $name vytvořena.');
    });
  }

  void _renameFolder(ChordFolder folder) {
    final forbidden =
        myChordFolders.where((f) => f != folder).map((f) => f.name).toSet();
    final oldName = folder.name;
    showDialog<String>(
      context: context,
      builder: (_) => _ChordNameDialog(
        title: 'Přejmenovat složku $oldName',
        label: 'Nový název složky',
        confirmLabel: 'Přejmenovat',
        initial: oldName,
        forbiddenNames: forbidden,
        emptyErrorText: 'Zadejte název složky',
        duplicateErrorText: 'Tato složka už existuje',
      ),
    ).then((name) async {
      if (name == null) return;
      folder.name = name;
      await persistLibrary();
      if (!mounted) return;
      setState(() {});
      await showFeedback(context, 'Složka přejmenována na $name.');
    });
  }

  void _deleteFolder(ChordFolder folder) {
    final name = folder.name;
    final count =
        mySavedChords.where((c) => c.folderId == folder.id).length;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Smazat složku $name?'),
        content: Text(
          count == 0
              ? 'Složka je prázdná.'
              : 'Složka obsahuje $count ${pluralCs(count, 'akord', 'akordy', 'akordů')}. Akordy zůstanou v Bez složky.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              myChordFolders.remove(folder);
              for (final c in mySavedChords) {
                if (c.folderId == folder.id) c.folderId = null;
              }
              await persistLibrary();
              if (!mounted) return;
              setState(() {});
              await showFeedback(
                context,
                'Složka $name smazána. Akordy zůstaly v Bez složky.',
              );
            },
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = myChordFolders;
    final unfiled =
        mySavedChords.where((c) => c.folderId == null).toList();
    final isEmpty = folders.isEmpty && mySavedChords.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uložené akordy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Vytvořit složku',
            onPressed: _createFolder,
          ),
        ],
      ),
      body: isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Zatím nemáte žádné uložené akordy.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.music_note),
                      label: const Text('Otevřít editor akordů'),
                      onPressed: () => _openNewChord(),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.create_new_folder),
                      label: const Text('Vytvořit složku'),
                      onPressed: _createFolder,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              children: [
                if (folders.isNotEmpty) ...[
                  const _SectionHeader('Složky'),
                  ...folders.map(_folderTile),
                ],
                if (unfiled.isNotEmpty) ...[
                  const _SectionHeader('Bez složky'),
                  ...unfiled.map(
                    (chord) => ChordTile(
                      chord: chord,
                      playing: _playing,
                      onOpen: () => _openForEdit(chord),
                      onPlay: () => _playChord(chord),
                      onDescribe: () => _describe(chord),
                      onRename: () => _renameChord(chord),
                      onMove: () => _moveChord(chord),
                      onDelete: () => _deleteChord(chord),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _folderTile(ChordFolder folder) {
    final count =
        mySavedChords.where((c) => c.folderId == folder.id).length;
    final countText = '$count ${pluralCs(count, 'akord', 'akordy', 'akordů')}';
    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(folder.name),
      subtitle: Text(
        countText,
        semanticsLabel: 'Složka ${folder.name}, $countText',
      ),
      onTap: () => _openFolder(folder),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Přejmenovat složku ${folder.name}',
            onPressed: () => _renameFolder(folder),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Smazat složku ${folder.name}',
            onPressed: () => _deleteFolder(folder),
          ),
        ],
      ),
    );
  }
}

/// Nadpis sekce v seznamu (složky / bez složky). `header: true` umožní
/// čtečce navigovat po nadpisech.

/// České skloňování podle počtu: 1 akord, 2–4 akordy, 5+ akordů.
String pluralCs(int n, String one, String few, String many) {
  if (n == 1) return one;
  if (n >= 2 && n <= 4) return few;
  return many;
}

/// Sdílené akce nad akordem pro seznam i detail složky:
/// otevření v editoru, přehrání, popis, přejmenování, přesun, smazání.
/// Všechna potvrzení jdou přes showFeedback (SnackBar + announce čtečce).
mixin ChordActions<T extends StatefulWidget> on State<T> {
  final MidiChordPlayer _midi = MidiChordPlayer();
  final TtsService _tts = TtsService();
  bool _playing = false;

  void disposeActions() {
    _tts.stop();
  }

  Future<void> _openNewChord({String? folderId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChordEditorPage(folderId: folderId),
      ),
    );
    await persistLibrary();
    if (mounted) setState(() {});
  }

  Future<void> _openForEdit(SavedChord chord) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChordEditorPage(initial: chord)),
    );
    await persistLibrary();
    if (mounted) setState(() {});
  }

  Future<void> _playChord(SavedChord chord) async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      final ok = await _midi.ensureReady(
        loadSf2: Platform.isWindows ? null : () => rootBundle.load('assets/guitar.sf2'),
      );
      if (!ok) {
        if (!mounted) return;
        await showFeedback(
          context,
          'Akord ${chord.name} nelze přehrát: ${_midi.errorText.isNotEmpty ? _midi.errorText : 'MIDI není připraveno'}',
        );
        return;
      }
      if (!mounted) return;
      await showFeedback(context, 'Přehrávám akord ${chord.name}…');
      await _midi.playPositions(
        chord.positions,
        ChordLogic().midiBaseNotes,
      );
    } catch (e) {
      if (!mounted) return;
      await showFeedback(
        context,
        'Akord ${chord.name} nelze přehrát: $e',
      );
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _describe(SavedChord chord) {
    _tts.speak('${chord.name}. ${chord.fullDescription}');
  }

  void _renameChord(SavedChord chord) {
    final forbidden = mySavedChords
        .where((c) => c != chord)
        .map((c) => c.name)
        .toSet();
    final oldName = chord.name;
    showDialog<String>(
      context: context,
      builder: (_) => _ChordNameDialog(
        title: 'Přejmenovat akord $oldName',
        label: 'Nový název akordu',
        confirmLabel: 'Přejmenovat',
        initial: oldName,
        forbiddenNames: forbidden,
      ),
    ).then((name) async {
      if (name == null) return;
      chord.name = name;
      await persistLibrary();
      if (!mounted) return;
      setState(() {});
      await showFeedback(context, 'Akord přejmenován na $name.');
    });
  }

  void _deleteChord(SavedChord chord) {
    final name = chord.name;
    final desc = chord.fullDescription;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Smazat $name?'),
        content: Text('Hmat: $desc'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              mySavedChords.remove(chord);
              await persistLibrary();
              if (!mounted) return;
              setState(() {});
              await showFeedback(context, 'Akord $name smazán.');
            },
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
  }

  /// Přesun akordu do složky. Nativní RadioListTile (Tab + šipky +
  /// ohlášení stavu zdarma); šipka rovnou vybírá a zavírá. Prázdný
  /// řetězec = Bez složky (null by splývalo se zrušením dialogu).
  void _moveChord(SavedChord chord) {
    final folders = List<ChordFolder>.from(myChordFolders);
    showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Přesunout akord ${chord.name} do složky'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: chord.folderId ?? '',
              onChanged: (v) {
                if (v == null) return;
                Navigator.pop(dialogContext, v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RadioListTile<String>(
                    title: Text('Bez složky'),
                    value: '',
                  ),
                  for (final f in folders)
                    RadioListTile<String>(
                      title: Text(f.name),
                      value: f.id,
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Zrušit'),
          ),
        ],
      ),
    ).then((value) async {
      if (value == null) return; // zrušeno křížkem / šipkou zpět
      final target = value.isEmpty ? null : value;
      if (target == chord.folderId) return; // beze změny → ticho
      chord.folderId = target;
      await persistLibrary();
      if (!mounted) return;
      setState(() {});
      var where = 'Bez složky';
      for (final f in folders) {
        if (f.id == target) where = f.name;
      }
      await showFeedback(
        context,
        'Akord ${chord.name} přesunut do $where.',
      );
    });
  }
}

/// Jeden řádek akordu: jméno + hmat pro čtečku, akce Přehrát / Popsat /
/// Přesunout / Přejmenovat / Smazat. Použito v seznamu i detailu složky.
class ChordTile extends StatelessWidget {
  final SavedChord chord;
  final bool playing;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onDescribe;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  const ChordTile({
    super.key,
    required this.chord,
    required this.playing,
    required this.onOpen,
    required this.onPlay,
    required this.onDescribe,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(chord.name),
      // Subtitle nese hmat; čtečka přečte plný text i při
      // zkrácení na 2 řádky. SemanticsLabel dává věty.
      subtitle: Text(
        chord.shortDescription,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: chord.fullDescription,
      ),
      onTap: onOpen,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Přehrát akord ${chord.name}',
            onPressed: playing ? null : onPlay,
          ),
          IconButton(
            icon: const Icon(Icons.description),
            tooltip: 'Popsat hmat ${chord.name}',
            onPressed: onDescribe,
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_move),
            tooltip: 'Přesunout akord ${chord.name} do složky',
            onPressed: onMove,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Přejmenovat akord ${chord.name}',
            onPressed: onRename,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Smazat akord ${chord.name}',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Detail složky: akordy v ní + nový akord rovnou do složky.
class FolderDetailPage extends StatefulWidget {
  final ChordFolder folder;
  const FolderDetailPage({super.key, required this.folder});

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage>
    with ChordActions<FolderDetailPage> {
  @override
  void dispose() {
    disposeActions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chords =
        mySavedChords.where((c) => c.folderId == widget.folder.id).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nový akord do složky ${widget.folder.name}',
            onPressed: () => _openNewChord(folderId: widget.folder.id),
          ),
        ],
      ),
      body: chords.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Složka je prázdná. Nový hmat do ní přidáte tlačítkem plus nahoře.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: chords.length,
              itemBuilder: (context, index) {
                final chord = chords[index];
                return ChordTile(
                  chord: chord,
                  playing: _playing,
                  onOpen: () => _openForEdit(chord),
                  onPlay: () => _playChord(chord),
                  onDescribe: () => _describe(chord),
                  onRename: () => _renameChord(chord),
                  onMove: () => _moveChord(chord),
                  onDelete: () => _deleteChord(chord),
                );
              },
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Sdílený dialog pro zadání názvu akordu (uložení i přejmenování).
/// Vlastní controller (vytvořen v initState, zrušen v dispose), takže
/// přežije i zavírací animaci dialogu. Vrací očištěný název, nebo null
/// při zrušení. Chyby hlásí přes errorText, který čtečka přečte.
class _ChordNameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirmLabel;
  final String initial;
  final Set<String> forbiddenNames;
  final String emptyErrorText;
  final String duplicateErrorText;
  const _ChordNameDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initial,
    required this.forbiddenNames,
    this.emptyErrorText = 'Zadejte název akordu',
    this.duplicateErrorText = 'Tento název už existuje',
  });

  @override
  State<_ChordNameDialog> createState() => _ChordNameDialogState();
}

class _ChordNameDialogState extends State<_ChordNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final n = _controller.text.trim();
    if (n.isEmpty) {
      setState(() => _error = widget.emptyErrorText);
      return;
    }
    if (widget.forbiddenNames.contains(n)) {
      setState(() => _error = widget.duplicateErrorText);
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
        ),
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        ElevatedButton(
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
