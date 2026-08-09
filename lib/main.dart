import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Entry point of the Dart application. Establishes the widget tree.
  runApp(const SongbookApp());
}

/// Defines available song-sorting options for the application list view.
enum SortOption { numberAsc, numberDesc, az, za, key }

/// Centralized application color palette matching a custom dark UI theme specification.
class AppColors {
  static const Color primary = Color(0xFF1E6091);     // Primary brand blue color
  static const Color background = Color(0xFF1A1F26);  // Dark canvas background
  static const Color panel = Color(0xFF242B35);       // Slightly lighter dark for cards/sheets
}

/// SharedPreferences persistent memory keys used to save and load user preferences.
/// Storing these as constants avoids hardcoded string typos across different files.
class AppPrefs {
  static const String bookmarks = 'saved_bookmarked_ids';
  static const String fontSize = 'saved_global_font_size';
  static const String langEn = 'saved_global_language_en';
  static const String sortOption = 'saved_sort_option';
}

/// Root Application configuration widget. Sets up global dark theme specifications 
/// and disables default material touch behaviors for a faster UI feel.
class SongbookApp extends StatelessWidget {
  const SongbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sing For Joy',
      debugShowCheckedModeBanner: false, // Hides the red "debug" banner in development
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        
        // Remove default material splash overlays to make list taps feel snappy and instant
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        
        // Configure standard appearance for AppBars throughout the app
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const SplashScreen(), // Directs the app to boot into the Splash Screen first
    );
  }
}

/// Initial boot screen handling cold starts, logo display, and branding
/// before replacing itself with the main application view layout.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Create a 1-second delay simulating background asset preparation before navigating
    Future.delayed(const Duration(seconds: 1), () {
      // 'mounted' checks if the widget is still in the view tree before triggering navigation
      if (mounted) {
        // pushReplacement removes the splash screen from memory so users can't back-button into it
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
      // Background matched exactly to the hex value of the asset image background
      backgroundColor: const Color(0xFF216093), 
      body: SafeArea(
        child: Stack(
          children: [
            // Centered App Logo Image Asset
            Center(
              child: Image.asset(
                'assets/SingForJoy.png',
                width: 120,
              ),
            ),
            
            // Custom Branding Text positioned fixed at the screen bottom
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50.0, left: 16.0, right: 16.0),
                child: const Text(
                  "Built by Marcel Pisarski for Bridgwater Bibleway Believers",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70, 
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary viewport controller hosting local states for indexing tabs, 
/// data ingestion/parsing, sorting, and user preference state tracking.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Navigation State tracking (0: All Songs Tab, 1: Saved Bookmarks Tab)
  int _currentIndex = 0;
  
  // Data State Arrays holding the parsed text content and user favorites
  List<Map<String, String>> songs = [];
  List<String> bookmarkedIds = [];
  
  // Input and scroll state tracking controllers
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();

  // User preference state variables initialized to defaults
  bool isGlobalEnglish = true;
  double globalFontSize = 18.0;
  SortOption _currentSort = SortOption.numberAsc;

  @override
  void initState() {
    super.initState();
    loadSongData();      // Read text asset file data on boot
    loadSavedSettings();  // Read disk configurations via SharedPreferences
  }

  @override
  void dispose() {
    // Always dispose active controllers when destroying widgets to prevent system memory leaks
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  /// Generic, type-safe persistence utility handling basic value writes to local device disk.
  Future<void> _updatePreference<T>(String key, T value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is List<String>) await prefs.setStringList(key, value);
  }

  /// Hydrates the current session state from configurations stored in persistent memory.
  Future<void> loadSavedSettings() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        bookmarkedIds = prefs.getStringList(AppPrefs.bookmarks) ?? [];
        globalFontSize = prefs.getDouble(AppPrefs.fontSize) ?? 18.0;
        isGlobalEnglish = prefs.getBool(AppPrefs.langEn) ?? true;
        
        // Map stored index integers safely back into their respective Enum objects
        int sortIndex = prefs.getInt(AppPrefs.sortOption) ?? 0;
        if (sortIndex >= 0 && sortIndex < SortOption.values.length) {
          _currentSort = SortOption.values[sortIndex];
        }
      });
    } catch (e) {
      debugPrint("Error reading persistent memory disk: $e");
    }
  }

  /// Asynchronously loads, chunks, and parses raw multi-line string blocks from text assets.
  Future<void> loadSongData() async {
    try {
      // Ingest text asset file grouped internally with '---' token dividers
      final String fileContent = await rootBundle.loadString('assets/songs.txt');
      final List<String> rawSongBlocks = fileContent.split('---');

      List<Map<String, String>> parsedSongs = [];
      
      // Known key markers to track metadata vs lyrical strings
      final metaKeys = ['id:', 'title_en:', 'title_pl:', 'key:'];
      final lyricKeys = ['lyrics_en:', 'lyrics_pl:'];

      // Loop over every text block to construct separate structured song maps
      for (var block in rawSongBlocks) {
        if (block.trim().isEmpty) continue; // Skip empty trailing lines

        // Default layout data structure schema fallback
        Map<String, String> songData = {
          'id': '',
          'title_en': 'Unknown Title',
          'title_pl': 'Nieznany Tytuł',
          'key': '?',
          'lyrics_en': '',
          'lyrics_pl': ''
        };

        List<String> lines = block.split('\n');
        String currentKey = '';
        StringBuffer lyricsBuffer = StringBuffer(); // Efficient mutable string accumulator
        bool capturingLyrics = false;

        // Inwardly nested sub-function to commit buffered lyric text strings into the song block map
        void commitLyrics() {
          if (currentKey.isNotEmpty) {
            songData[currentKey] = lyricsBuffer.toString().trim();
          }
        }

        // Sequential parser moving line-by-line down the block
        for (var rawLine in lines) {
          String line = rawLine.trim();
          
          // Verify if line starts with any metadata or lyric token targets
          String? matchedMeta = metaKeys.where((k) => line.startsWith(k)).firstOrNull;
          String? matchedLyric = lyricKeys.where((k) => line.startsWith(k)).firstOrNull;

          if (matchedMeta != null) {
            if (capturingLyrics) commitLyrics(); // Save any previous buffer state
            capturingLyrics = false;
            
            // Extract text string past token boundary length (e.g., 'id: 1' -> '1')
            songData[matchedMeta.replaceAll(':', '')] = line.substring(matchedMeta.length).trim();
          } else if (matchedLyric != null) {
            if (capturingLyrics) commitLyrics();
            currentKey = matchedLyric.replaceAll(':', '');
            lyricsBuffer.clear();
            capturingLyrics = true; // Switch parser flag into multi-line body processing mode
          } else if (capturingLyrics) {
            // Filter placeholder empty-state lines to maintain UI cleanliness
            final lowerLine = line.toLowerCase();
            if (!lowerLine.contains('no english lyrics') &&
                !lowerLine.contains('no lyrics available') &&
                !lowerLine.contains('brak polskiego tekstu')) {
              lyricsBuffer.writeln(rawLine); // Retain raw formatting tabs/indents
            }
          }
        }

        if (capturingLyrics) commitLyrics(); // Final check to capture remaining strings

        // Ensure safety check baseline validation (songs must have an ID to exist)
        if (songData['id']!.isNotEmpty) {
          parsedSongs.add(songData);
        }
      }

      // Update widget tree state with parsed object results
      setState(() => songs = parsedSongs);
    } catch (e) {
      debugPrint("Error loading or parsing songs file: $e");
    }
  }

  /// Appends or removes song item reference keys from the user bookmark array list.
  Future<void> toggleBookmark(String songId) async {
    setState(() {
      bookmarkedIds.contains(songId) ? bookmarkedIds.remove(songId) : bookmarkedIds.add(songId);
    });
    await _updatePreference(AppPrefs.bookmarks, bookmarkedIds);
  }

  /// Swaps interface language context values dynamically.
  Future<void> toggleGlobalLanguage() async {
    setState(() => isGlobalEnglish = !isGlobalEnglish);
    await _updatePreference(AppPrefs.langEn, isGlobalEnglish);
  }

  /// Saves global text size changes to persistent storage.
  Future<void> saveNewFontSize(double newSize) async {
    setState(() => globalFontSize = newSize);
    await _updatePreference(AppPrefs.fontSize, globalFontSize);
  }

  /// Launches an interactive slide-up modal bottom sheet to configure list sorting.
  void _showSortPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to compute accurate flexible height
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Inner builder generator function for styling option buttons
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
              Navigator.pop(context); // Programmatically close modal sheet
            },
          );
        }

        // Configuration mapping array linking internal sort types to matching UI string variants
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
                  // Map options into interactive UI rows dynamically
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

  /// Formulates view stack changes routing users over into dedicated lyrical display pages.
  void _navigateToLyrics(Map<String, String> song, String songId, bool isSaved) async {
    // Await execution pauses until child route dismisses/pops back to this view
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LyricsPage(
          song: song,
          preferredLanguageEnglish: isGlobalEnglish,
          isBookmarked: isSaved,
          currentFontSize: globalFontSize,
          onFontSizeChanged: saveNewFontSize,
          onBookmarkToggle: () => toggleBookmark(songId),
        ),
      ),
    );
    // Explicit refresh ensuring layout list nodes properly mirror updates changed inside child routes
    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    // Pipeline Filtering Stage 1: Filter out items if browsing the Saved/Bookmarks tab
    List<Map<String, String>> tabFilteredSongs = _currentIndex == 0
        ? songs
        : songs.where((song) => bookmarkedIds.contains(song['id'])).toList();

    // Pipeline Filtering Stage 2: Filter out elements not matching current text field queries
    final query = searchQuery.toLowerCase();
    List<Map<String, String>> displayedSongs = tabFilteredSongs.where((song) {
      return song.values.any((value) => value.toLowerCase().contains(query));
    }).toList();

    // Pipeline Filtering Stage 3: Apply active ordering comparator algorithms
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
          // Nav bar locale swap widget control
          TextButton(
            style: TextButton.styleFrom(
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
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white, size: 20),
            onPressed: _showSortPanel,
          ),
          const SizedBox(width: 4), 
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Only mount search input field row if actively reading inside Main Catalog indexing tabs
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
                      isDense: true, // Shrinks internal spacing borders for structural compact look
                      hintText: isGlobalEnglish ? 'Search' : 'Wyszukaj',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 18),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 23),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white30, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                FocusScope.of(context).unfocus(); // Dismiss system hardware keypad
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
              
            // Main list view workspace switcher
            Expanded(
              child: songs.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : displayedSongs.isEmpty
                      ? Center(
                          child: Text(
                            searchQuery.isNotEmpty
                                ? (isGlobalEnglish ? 'No search results found.' : 'Nie znaleziono wyników wyszukiwania.')
                                : (_currentIndex == 0
                                    ? (isGlobalEnglish ? 'No songs available.' : 'Brak dostępnych pieśni.')
                                    : (isGlobalEnglish ? 'Your favourite songs will appear here.' : 'Twoje zapisane pieśni pojawią się tutaj.')),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        )
                      : Scrollbar(
                          controller: _listScrollController,
                          thumbVisibility: true, // Always show the scroll track indicator line
                          trackVisibility: false,
                          child: ListView.builder(
                            controller: _listScrollController,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: displayedSongs.length,
                            itemBuilder: (context, index) {
                              final song = displayedSongs[index];
                              final String songId = song['id'] ?? '';
                              final bool isSaved = bookmarkedIds.contains(songId);

                              return SongTile(
                                song: song,
                                isSaved: isSaved,
                                isGlobalEnglish: isGlobalEnglish,
                                onToggleBookmark: () => toggleBookmark(songId),
                                onTap: () => _navigateToLyrics(song, songId, isSaved),
                              );
                            },
                          ),
                        ),
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

/// A clean UI item card widget mapping explicit map attributes onto separate rows.
class SongTile extends StatelessWidget {
  final Map<String, String> song;
  final bool isSaved;
  final bool isGlobalEnglish;
  final VoidCallback onToggleBookmark;
  final VoidCallback onTap;

  const SongTile({
    super.key,
    required this.song,
    required this.isSaved,
    required this.isGlobalEnglish,
    required this.onToggleBookmark,
    required this.onTap,
  });

  /// Inlines stylized localized badge pill tags indicating what languages are available for a song.
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
          onTap: onTap, // Fires routing callback behavior
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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

/// Specialized text presentation workspace supporting live font sizing mutations 
/// and interactive runtime translation selection changes.
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
  // Local state replicas tracking view mutations independently from root variables
  late bool isEnglish;
  late bool isSavedInside;
  late double _fontSize;
  final ScrollController _lyricsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    isEnglish = widget.preferredLanguageEnglish;
    isSavedInside = widget.isBookmarked;
    _fontSize = widget.currentFontSize;

    // Safety fallback checking if preferred language string possesses zero characters.
    // Automatically forces alternative display language so user isn't shown a blank sheet.
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

  /// Displays slide-up accessibility tracking tools modifying lyrics layout sizes on-the-fly.
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // StatefulBuilder allows the slider to smoothly repaint itself within the modal 
        // while simultaneously pushing the structural text updates back to the parent page view tree
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.preferredLanguageEnglish ? "Text Size Options" : "Opcje rozmiaru tekstu",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        "${_fontSize.toInt()} px",
                        style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold),
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
                        setModalState(() => _fontSize = newValue); // Re-render modal slider node
                        setState(() {});                           // Re-render lyrics text background node
                        widget.onFontSizeChanged(newValue);        // Bubble preference change event upwards
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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

    // Use clean explicit fallback strings if selected target block language text evaluates to empty
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
                overflow: TextOverflow.ellipsis, // Wraps lengthy names cleanly with a trailing '...'
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
              isSavedInside ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              widget.onBookmarkToggle(); // Notify main list index changes
              setState(() => isSavedInside = !isSavedInside); // Swap view state icon instantly
            },
          ),
          // Local single-page context language toggle switch
          TextButton(
            style: TextButton.styleFrom(
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
            icon: const Icon(Icons.settings, color: Colors.white, size: 20),
            onPressed: _showSettingsPanel,
          ),
        ],
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _lyricsScrollController,
          thumbVisibility: true,
          trackVisibility: false,
          child: SingleChildScrollView(
            controller: _lyricsScrollController,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              // SelectableText allows application readers to manually copy lines or highlight individual words
              child: SelectableText(
                displayedLyrics,
                style: TextStyle(
                  fontSize: _fontSize,
                  height: 1.6, // Sets lines text height leading margins for enhanced screen readability
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