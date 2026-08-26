import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SongbookApp());
}

/// Defines available song-sorting options for the application list view.
enum SortOption { numberAsc, numberDesc, az, za, key }

/// Strips accents (including Polish diacritics), punctuation, and normalises spacing.
String normaliseSearchText(String input) {
  const diacriticsMap = {
    'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n', 'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
    'Ą': 'a', 'Ć': 'c', 'Ę': 'e', 'Ł': 'l', 'Ń': 'n', 'Ó': 'o', 'Ś': 's', 'Ź': 'z', 'Ż': 'z',
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y', 'ñ': 'n', 'ç': 'c',
    'À': 'a', 'Á': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a', 'Å': 'a',
    'È': 'e', 'É': 'e', 'Ê': 'e', 'Ë': 'e',
    'Ì': 'i', 'Í': 'i', 'Î': 'i', 'Ï': 'i',
    'Ò': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o',
    'Ù': 'u', 'Ú': 'u', 'Û': 'u', 'Ü': 'u',
    'Ý': 'y', 'Ñ': 'n', 'Ç': 'c',
  };

  String output = input.toLowerCase();

  diacriticsMap.forEach((key, value) {
    output = output.replaceAll(key.toLowerCase(), value);
  });

  output = output
      .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return output;
}

/// Centralized application color palette matching a custom dark UI theme specification.
class AppColors {
  static const Color primary = Color(0xFF1E6091);
  static const Color background = Color(0xFF1A1F26);
  static const Color panel = Color(0xFF242B35);
}

/// SharedPreferences persistent memory keys.
class AppPrefs {
  static const String customLists = 'saved_custom_song_lists';
  static const String fontSize = 'saved_global_font_size';
  static const String langEn = 'saved_global_language_en';
  static const String sortOption = 'saved_sort_option';
}

/// Represents a custom user-created song playlist/collection.
class CustomSongList {
  final String id;
  String name;
  List<String> songIds;

  CustomSongList({
    required this.id,
    required this.name,
    required this.songIds,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'songIds': songIds,
      };

  factory CustomSongList.fromMap(Map<String, dynamic> map) {
    return CustomSongList(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      songIds: List<String>.from(map['songIds'] ?? []),
    );
  }
}

/// Root Application configuration widget.
class SongbookApp extends StatelessWidget {
  const SongbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sing For Joy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          trackVisibility: WidgetStateProperty.all(false),
          thickness: WidgetStateProperty.all(3.5),
          radius: const Radius.circular(8),
          trackColor: WidgetStateProperty.all(Colors.transparent),
          trackBorderColor: WidgetStateProperty.all(Colors.transparent),
          thumbColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.45)),
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Initial boot splash screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF216093),
      body: SafeArea(
        child: Center(
          child: Image.asset(
            'assets/SingForJoy.png',
            width: 120,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.music_note, size: 80, color: Colors.white);
            },
          ),
        ),
      ),
    );
  }
}

/// Primary viewport controller.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  List<Map<String, String>> songs = [];
  List<CustomSongList> customLists = [];

  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();

  bool isGlobalEnglish = true;
  double globalFontSize = 18.0;
  SortOption _currentSort = SortOption.numberAsc;

  @override
  void initState() {
    super.initState();
    loadSongData();
    loadSavedSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _updatePreference<T>(String key, T value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (value is bool) await prefs.setBool(key, value);
      else if (value is double) await prefs.setDouble(key, value);
      else if (value is int) await prefs.setInt(key, value);
      else if (value is List<String>) await prefs.setStringList(key, value);
      else if (value is String) await prefs.setString(key, value);
    } catch (e) {
      debugPrint("Error updating persistent preference '$key': $e");
    }
  }

  Future<void> _saveCustomLists() async {
    final listMaps = customLists.map((l) => l.toMap()).toList();
    final jsonStr = jsonEncode(listMaps);
    await _updatePreference(AppPrefs.customLists, jsonStr);
  }

  Future<void> loadSavedSettings() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final savedListsJson = prefs.getString(AppPrefs.customLists);

      List<CustomSongList> loadedLists = [];
      if (savedListsJson != null && savedListsJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedListsJson);
          loadedLists = decoded.map((item) => CustomSongList.fromMap(item)).toList();
        } catch (e) {
          debugPrint("Error parsing saved lists: $e");
        }
      }

      setState(() {
        customLists = loadedLists;
        globalFontSize = prefs.getDouble(AppPrefs.fontSize) ?? 18.0;
        isGlobalEnglish = prefs.getBool(AppPrefs.langEn) ?? true;

        int sortIndex = prefs.getInt(AppPrefs.sortOption) ?? 0;
        if (sortIndex >= 0 && sortIndex < SortOption.values.length) {
          _currentSort = SortOption.values[sortIndex];
        }
      });
    } catch (e) {
      debugPrint("Error reading persistent memory disk: $e");
    }
  }

  Future<void> loadSongData() async {
    try {
      final String fileContent = await rootBundle.loadString('assets/songs.txt');
      final List<String> rawSongBlocks = fileContent.split('---');

      List<Map<String, String>> parsedSongs = [];
      final metaKeys = ['id:', 'title_en:', 'title_pl:', 'key:'];
      final lyricKeys = ['lyrics_en:', 'lyrics_pl:'];

      for (var block in rawSongBlocks) {
        if (block.trim().isEmpty) continue;

        Map<String, String> songData = {
          'id': '',
          'title_en': 'Unknown Title',
          'title_pl': 'Nieznany Tytuł',
          'key': '?',
          'lyrics_en': '',
          'lyrics_pl': ''
        };

        List<String> lines = block.split(RegExp(r'\r?\n'));
        String currentKey = '';
        StringBuffer lyricsBuffer = StringBuffer();
        bool capturingLyrics = false;

        void commitLyrics() {
          if (currentKey.isNotEmpty) {
            songData[currentKey] = lyricsBuffer.toString().trim();
          }
        }

        for (var rawLine in lines) {
          String line = rawLine.trim();
          String? matchedMeta = metaKeys.where((k) => line.startsWith(k)).firstOrNull;
          String? matchedLyric = lyricKeys.where((k) => line.startsWith(k)).firstOrNull;

          if (matchedMeta != null) {
            if (capturingLyrics) commitLyrics();
            capturingLyrics = false;
            songData[matchedMeta.replaceAll(':', '')] = line.substring(matchedMeta.length).trim();
          } else if (matchedLyric != null) {
            if (capturingLyrics) commitLyrics();
            currentKey = matchedLyric.replaceAll(':', '');
            lyricsBuffer.clear();
            capturingLyrics = true;
          } else if (capturingLyrics) {
            final lowerLine = line.toLowerCase();
            if (!lowerLine.contains('no english lyrics') &&
                !lowerLine.contains('no lyrics available') &&
                !lowerLine.contains('brak polskiego tekstu')) {
              lyricsBuffer.writeln(rawLine);
            }
          }
        }

        if (capturingLyrics) commitLyrics();

        if (songData['id']!.isNotEmpty) {
          parsedSongs.add(songData);
        }
      }

      if (mounted) {
        setState(() => songs = parsedSongs);
      }
    } catch (e) {
      debugPrint("Error loading or parsing songs file: $e");
    }
  }

  bool isSongSavedAnywhere(String songId) {
    return customLists.any((l) => l.songIds.contains(songId));
  }

  void _showCreateListDialog({Function(CustomSongList)? onCreated}) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isGlobalEnglish ? "Create New List" : "Utwórz nową listę",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: isGlobalEnglish ? "List name" : "Nazwa listy",
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                foregroundColor: Colors.white60,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(isGlobalEnglish ? "Cancel" : "Anuluj", style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                foregroundColor: AppColors.primary,
              ),
              onPressed: () {
                final trimmed = nameController.text.trim();
                if (trimmed.isNotEmpty) {
                  final newList = CustomSongList(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: trimmed,
                    songIds: [],
                  );
                  setState(() {
                    customLists.add(newList);
                  });
                  _saveCustomLists();
                  Navigator.pop(dialogContext);
                  if (onCreated != null) onCreated(newList);
                }
              },
              child: Text(isGlobalEnglish ? "Save" : "Zapisz", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  void _showEditListDialog(CustomSongList list) {
    final nameController = TextEditingController(text: list.name);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isGlobalEnglish ? "Rename List" : "Zmień nazwę listy",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: isGlobalEnglish ? "List name" : "Nazwa listy",
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                foregroundColor: Colors.white60,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(isGlobalEnglish ? "Cancel" : "Anuluj", style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                foregroundColor: AppColors.primary,
              ),
              onPressed: () {
                final trimmed = nameController.text.trim();
                if (trimmed.isNotEmpty) {
                  setState(() {
                    list.name = trimmed;
                  });
                  _saveCustomLists();
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(isGlobalEnglish ? "Save" : "Zapisz", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  void _showAddSongToListSheet(String songId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isGlobalEnglish ? "Save to List" : "Zapisz do listy",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            splashFactory: NoSplash.splashFactory,
                            foregroundColor: AppColors.primary,
                          ),
                          onPressed: () {
                            _showCreateListDialog(onCreated: (newList) {
                              setSheetState(() {});
                            });
                          },
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            isGlobalEnglish ? "New List" : "Nowa lista",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                    const Divider(color: Colors.white10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: customLists.length,
                        itemBuilder: (context, idx) {
                          final list = customLists[idx];
                          final bool isPresent = list.songIds.contains(songId);

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            checkColor: Colors.white,
                            title: Text(list.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                            subtitle: Text(
                              "${list.songIds.length} ${isGlobalEnglish ? (list.songIds.length == 1 ? 'song' : 'songs') : (list.songIds.length == 1 ? 'pieśń' : 'pieśni')}",
                              style: const TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                            value: isPresent,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  if (!list.songIds.contains(songId)) list.songIds.add(songId);
                                } else {
                                  list.songIds.remove(songId);
                                }
                              });
                              _saveCustomLists();
                              setSheetState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteList(int index) {
    setState(() {
      customLists.removeAt(index);
    });
    _saveCustomLists();
  }

  Future<void> toggleGlobalLanguage() async {
    setState(() => isGlobalEnglish = !isGlobalEnglish);
    await _updatePreference(AppPrefs.langEn, isGlobalEnglish);
  }

  Future<void> saveNewFontSize(double newSize) async {
    setState(() => globalFontSize = newSize);
    await _updatePreference(AppPrefs.fontSize, globalFontSize);
  }

  void _showSortPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        Widget buildOption(String title, SortOption value, IconData baseIcon, [IconData? dirIcon]) {
          bool isSelected = _currentSort == value;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(baseIcon, color: isSelected ? AppColors.primary : Colors.white54, size: 22),
                  if (dirIcon != null) ...[
                    const SizedBox(width: 2),
                    Icon(dirIcon, color: isSelected ? AppColors.primary : Colors.white54, size: 14),
                  ]
                ],
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.white70,
              ),
            ),
            trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _currentSort = value);
              _updatePreference(AppPrefs.sortOption, value.index);
              Navigator.pop(context);
            },
          );
        }

        final List<Map<String, dynamic>> sortOptionsList = [
          {'en': "Number (Ascending)", 'pl': "Numer (Rosnąco)", 'val': SortOption.numberAsc, 'icon': Icons.tag, 'dir': Icons.arrow_downward},
          {'en': "Number (Descending)", 'pl': "Numer (Malejąco)", 'val': SortOption.numberDesc, 'icon': Icons.tag, 'dir': Icons.arrow_upward},
          {'en': "Title (A-Z)", 'pl': "Tytuł (A-Z)", 'val': SortOption.az, 'icon': Icons.sort_by_alpha, 'dir': Icons.arrow_downward},
          {'en': "Title (Z-A)", 'pl': "Tytuł (Z-A)", 'val': SortOption.za, 'icon': Icons.sort_by_alpha, 'dir': Icons.arrow_upward},
          {'en': "Key", 'pl': "Tonacja", 'val': SortOption.key, 'icon': Icons.music_note, 'dir': null},
        ];

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGlobalEnglish ? "Sort Options" : "Opcje sortowania",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  ...sortOptionsList.map((opt) => buildOption(
                        isGlobalEnglish ? opt['en'] as String : opt['pl'] as String,
                        opt['val'] as SortOption,
                        opt['icon'] as IconData,
                        opt['dir'] as IconData?,
                      )),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToLyrics(Map<String, String> song, String songId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LyricsPage(
          song: song,
          preferredLanguageEnglish: isGlobalEnglish,
          isBookmarked: isSongSavedAnywhere(songId),
          currentFontSize: globalFontSize,
          onFontSizeChanged: saveNewFontSize,
          onBookmarkToggle: () => _showAddSongToListSheet(songId),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _navigateToListDetails(CustomSongList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongListDetailPage(
          songList: list,
          allSongs: songs,
          isGlobalEnglish: isGlobalEnglish,
          globalFontSize: globalFontSize,
          onSaveList: _saveCustomLists,
          onFontSizeChanged: saveNewFontSize,
          onSongTap: (song, id) => _navigateToLyrics(song, id),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final normalisedQuery = normaliseSearchText(searchQuery);
    List<Map<String, String>> displayedSongs = normalisedQuery.isNotEmpty
        ? songs.where((song) => song.values.any((val) => normaliseSearchText(val).contains(normalisedQuery))).toList()
        : List.from(songs);

    displayedSongs.sort((a, b) {
      final int idA = int.tryParse(a['id'] ?? '0') ?? 0;
      final int idB = int.tryParse(b['id'] ?? '0') ?? 0;
      final String titleA = (a[isGlobalEnglish ? 'title_en' : 'title_pl'] ?? '').toLowerCase();
      final String titleB = (b[isGlobalEnglish ? 'title_en' : 'title_pl'] ?? '').toLowerCase();

      switch (_currentSort) {
        case SortOption.numberAsc:
          return idA.compareTo(idB);
        case SortOption.numberDesc:
          return idB.compareTo(idA);
        case SortOption.az:
          return titleA.compareTo(titleB);
        case SortOption.za:
          return titleB.compareTo(titleA);
        case SortOption.key:
          return (a['key'] ?? '').compareTo(b['key'] ?? '');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sing For Joy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: toggleGlobalLanguage,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  isGlobalEnglish ? "EN" : "PL",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.sort, color: Colors.white, size: 20),
              onPressed: _showSortPanel,
            )
          else
            IconButton(
              icon: const Icon(Icons.playlist_add, color: Colors.white, size: 24),
              tooltip: isGlobalEnglish ? 'Create New List' : 'Utwórz nową listę',
              onPressed: () => _showCreateListDialog(),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_currentIndex == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (value) => setState(() => searchQuery = value),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: isGlobalEnglish ? 'Search' : 'Wyszukaj',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 18),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 23),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white30, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                                setState(() => searchQuery = "");
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _currentIndex == 0
                  ? (songs.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : displayedSongs.isEmpty
                          ? Center(
                              child: Text(
                                searchQuery.isNotEmpty
                                    ? (isGlobalEnglish ? 'No search results found.' : 'Nie znaleziono wyników wyszukiwania.')
                                    : (isGlobalEnglish ? 'No songs available.' : 'Brak dostępnych pieśni.'),
                                style: const TextStyle(color: Colors.white54),
                              ),
                            )
                          : Scrollbar(
                              controller: _listScrollController,
                              thumbVisibility: true,
                              interactive: true,
                              trackVisibility: false,
                              child: ListView.builder(
                                controller: _listScrollController,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: displayedSongs.length,
                                itemBuilder: (context, index) {
                                  final song = displayedSongs[index];
                                  final String songId = song['id'] ?? '';
                                  final bool isSaved = isSongSavedAnywhere(songId);

                                  return SongTile(
                                    key: ValueKey(songId),
                                    index: index,
                                    song: song,
                                    isSaved: isSaved,
                                    isGlobalEnglish: isGlobalEnglish,
                                    isReorderable: false,
                                    onToggleBookmark: () => _showAddSongToListSheet(songId),
                                    onTap: () => _navigateToLyrics(song, songId),
                                  );
                                },
                              ),
                            ))
                  : (customLists.isEmpty
                      ? Center(
                          child: Text(
                            isGlobalEnglish ? 'No lists created yet.' : 'Brak utworzonych list.',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: customLists.length,
                          itemBuilder: (context, index) {
                            final list = customLists[index];
                            final songCount = list.songIds.length;

                            return Dismissible(
                              key: ValueKey("list_${list.id}"),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
                              ),
                              onDismissed: (direction) => _deleteList(index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Material(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  shadowColor: Colors.black.withValues(alpha: 0.25),
                                  elevation: 2,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _navigateToListDetails(list),
                                    child: Container(
                                      constraints: const BoxConstraints(minHeight: 56),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              list.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "$songCount ${isGlobalEnglish ? (songCount == 1 ? 'song' : 'songs') : (songCount == 1 ? 'pieśń' : 'pieśni')}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white60,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                                            onPressed: () => _showEditListDialog(list),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.white38,
        backgroundColor: AppColors.panel,
        elevation: 10,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.music_note),
            label: isGlobalEnglish ? 'All Songs' : 'Wszystkie',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.queue_music),
            label: isGlobalEnglish ? 'Saved' : 'Zapisane',
          ),
        ],
      ),
    );
  }
}

/// Dedicated page inspecting and managing a single song list.
class SongListDetailPage extends StatefulWidget {
  final CustomSongList songList;
  final List<Map<String, String>> allSongs;
  final bool isGlobalEnglish;
  final double globalFontSize;
  final VoidCallback onSaveList;
  final ValueChanged<double> onFontSizeChanged;
  final Function(Map<String, String> song, String songId) onSongTap;

  const SongListDetailPage({
    super.key,
    required this.songList,
    required this.allSongs,
    required this.isGlobalEnglish,
    required this.globalFontSize,
    required this.onSaveList,
    required this.onFontSizeChanged,
    required this.onSongTap,
  });

  @override
  State<SongListDetailPage> createState() => _SongListDetailPageState();
}

class _SongListDetailPageState extends State<SongListDetailPage> {
  void _onReorderSongs(int oldIndex, int newIndex) {
    setState(() {
      final String item = widget.songList.songIds.removeAt(oldIndex);
      widget.songList.songIds.insert(newIndex, item);
    });
    widget.onSaveList();
  }

  void _removeSongFromList(String songId) {
    setState(() {
      widget.songList.songIds.remove(songId);
    });
    widget.onSaveList();
  }

  void _shareSongList() {
    final songMap = {for (var song in widget.allSongs) song['id'] ?? '': song};
    final displayedSongs = widget.songList.songIds
        .map((id) => songMap[id])
        .whereType<Map<String, String>>()
        .toList();

    if (displayedSongs.isEmpty) return;

    final songLines = displayedSongs.map((song) {
      final String id = song['id'] ?? '';
      final String title = song[widget.isGlobalEnglish ? 'title_en' : 'title_pl'] ?? 'Unknown Title';
      final String key = song['key'] ?? '?';
      return "$id. $title [$key]";
    }).toList();

    final String textToShare = songLines.join('\n');
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      textToShare,
      subject: widget.songList.name,
      sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final songMap = {for (var song in widget.allSongs) song['id'] ?? '': song};
    final displayedSongs = widget.songList.songIds
        .map((id) => songMap[id])
        .whereType<Map<String, String>>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.songList.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white, size: 20),
            tooltip: widget.isGlobalEnglish ? 'Share List' : 'Udostępnij listę',
            onPressed: _shareSongList,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: displayedSongs.isEmpty
            ? Center(
                child: Text(
                  widget.isGlobalEnglish ? 'This list is empty.' : 'Ta lista jest pusta.',
                  style: const TextStyle(color: Colors.white54),
                ),
              )
            : ReorderableListView.builder(
                proxyDecorator: (Widget child, int index, Animation<double> animation) => child,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: displayedSongs.length,
                onReorderItem: _onReorderSongs,
                itemBuilder: (context, index) {
                  final song = displayedSongs[index];
                  final String songId = song['id'] ?? '';

                  return Dismissible(
                    key: ValueKey("list_song_${widget.songList.id}_$songId"),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
                    ),
                    onDismissed: (direction) => _removeSongFromList(songId),
                    child: SongTile(
                      key: ValueKey(songId),
                      index: index,
                      song: song,
                      isSaved: true,
                      isGlobalEnglish: widget.isGlobalEnglish,
                      isReorderable: true,
                      onToggleBookmark: () => _removeSongFromList(songId),
                      onTap: () => widget.onSongTap(song, songId),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Song card item widget.
class SongTile extends StatelessWidget {
  final Map<String, String> song;
  final bool isSaved;
  final bool isGlobalEnglish;
  final bool isReorderable;
  final int index;
  final VoidCallback onToggleBookmark;
  final VoidCallback onTap;

  const SongTile({
    super.key,
    required this.song,
    required this.isSaved,
    required this.isGlobalEnglish,
    this.isReorderable = false,
    this.index = 0,
    required this.onToggleBookmark,
    required this.onTap,
  });

  Widget _buildLanguageBadge(String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        lang,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasEn = song['lyrics_en']?.isNotEmpty ?? false;
    final bool hasPl = song['lyrics_pl']?.isNotEmpty ?? false;
    final String displayTitle = song[isGlobalEnglish ? 'title_en' : 'title_pl'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        shadowColor: Colors.black.withValues(alpha: 0.25),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isReorderable)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                      child: Icon(Icons.drag_handle, color: Colors.white54, size: 22),
                    ),
                  )
                else
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      color: isSaved ? AppColors.primary : Colors.white30,
                      size: 22,
                    ),
                    onPressed: onToggleBookmark,
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${song['id']}. $displayTitle",
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "[${song['key']}]",
                  style: const TextStyle(fontSize: 15, color: Colors.white60, fontWeight: FontWeight.w400),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    if (hasEn) _buildLanguageBadge("EN"),
                    if (hasPl) _buildLanguageBadge("PL"),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lyrics presentation workspace.
class LyricsPage extends StatefulWidget {
  final Map<String, String> song;
  final bool preferredLanguageEnglish;
  final bool isBookmarked;
  final double currentFontSize;
  final ValueChanged<double> onFontSizeChanged;
  final VoidCallback onBookmarkToggle;

  const LyricsPage({
    super.key,
    required this.song,
    required this.preferredLanguageEnglish,
    required this.isBookmarked,
    required this.currentFontSize,
    required this.onFontSizeChanged,
    required this.onBookmarkToggle,
  });

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  late bool isEnglish;
  late double _fontSize;
  final ScrollController _lyricsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    isEnglish = widget.preferredLanguageEnglish;
    _fontSize = widget.currentFontSize;

    if (isEnglish && (widget.song['lyrics_en']?.isEmpty ?? true)) {
      isEnglish = false;
    } else if (!isEnglish && (widget.song['lyrics_pl']?.isEmpty ?? true)) {
      isEnglish = true;
    }
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _shareCurrentSong() {
    final String id = widget.song['id'] ?? '';
    final String title = widget.song[isEnglish ? 'title_en' : 'title_pl'] ?? 'Unknown Title';
    final String key = widget.song['key'] ?? '?';
    final String lyrics = widget.song[isEnglish ? 'lyrics_en' : 'lyrics_pl'] ?? '';

    final String textToShare = "$id. $title [$key]\n\n$lyrics";
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      textToShare,
      sharePositionOrigin: box != null ? (box.localToGlobal(Offset.zero) & box.size) : null,
    );
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.share, color: Colors.white70, size: 22),
                        title: Text(
                          widget.preferredLanguageEnglish ? "Share Song" : "Udostępnij pieśń",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                        onTap: () {
                          Navigator.pop(context);
                          _shareCurrentSong();
                        },
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.preferredLanguageEnglish ? "Text Size Options" : "Opcje rozmiaru tekstu",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${_fontSize.toInt()} px",
                              style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: Colors.white10,
                          thumbColor: Colors.white,
                          overlayColor: AppColors.primary.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          min: 14.0,
                          max: 30.0,
                          value: _fontSize,
                          onChanged: (newValue) {
                            setModalState(() => _fontSize = newValue);
                            setState(() {});
                            widget.onFontSizeChanged(newValue);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          "Sing For Joy v1.0.0\nSupport: marcelpisarskidev@gmail.com",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTitle = widget.song[isEnglish ? 'title_en' : 'title_pl'];
    final currentLyrics = widget.song[isEnglish ? 'lyrics_en' : 'lyrics_pl'];
    final bool isLyricsEmpty = currentLyrics == null || currentLyrics.trim().isEmpty;

    final String displayedLyrics = isLyricsEmpty
        ? (isEnglish ? "(No English translation available.)" : "(Brak polskiego tłumaczenia.)")
        : currentLyrics;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                "${widget.song['id']}. $currentTitle",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              "[${widget.song['key']}]",
              style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isBookmarked ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 20,
            ),
            onPressed: widget.onBookmarkToggle,
          ),
          TextButton(
            style: TextButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() => isEnglish = !isEnglish),
            child: Text(
              isEnglish ? "PL" : "EN",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            onPressed: _showSettingsPanel,
          ),
        ],
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _lyricsScrollController,
          thumbVisibility: true,
          interactive: true,
          trackVisibility: false,
          child: SingleChildScrollView(
            controller: _lyricsScrollController,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              child: SelectableText(
                displayedLyrics,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: 1.6,
                  color: isLyricsEmpty ? Colors.white38 : Colors.white,
                  fontStyle: isLyricsEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}