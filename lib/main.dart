import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/bookmarks_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'services/bookmark_service.dart';
import 'services/quran_service.dart';
import 'services/settings_service.dart';
import 'widgets/error_fallback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch framework-level errors (layout / paint / build errors).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'FlutterError: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  final quranService = await QuranService.load();
  final bookmarkService = BookmarkService();
  await bookmarkService.init();
  final settingsService = SettingsService();
  await settingsService.init();
  runApp(QuranApp(
    quranService: quranService,
    bookmarkService: bookmarkService,
    settingsService: settingsService,
  ));
}

class QuranApp extends StatelessWidget {
  const QuranApp({
    super.key,
    required this.quranService,
    required this.bookmarkService,
    required this.settingsService,
  });

  final QuranService quranService;
  final BookmarkService bookmarkService;
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القرآن الكريم',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: HomeShell(
        quranService: quranService,
        bookmarkService: bookmarkService,
        settingsService: settingsService,
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.quranService,
    required this.bookmarkService,
    required this.settingsService,
  });

  final QuranService quranService;
  final BookmarkService bookmarkService;
  final SettingsService settingsService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      SafeChild(
        builder: (_) => HomeScreen(
          quranService: widget.quranService,
          bookmarkService: widget.bookmarkService,
          settingsService: widget.settingsService,
        ),
      ),
      SafeChild(
        builder: (_) => SearchScreen(
          quranService: widget.quranService,
          bookmarkService: widget.bookmarkService,
        ),
      ),
      SafeChild(
        builder: (_) => BookmarksScreen(
          quranService: widget.quranService,
          bookmarkService: widget.bookmarkService,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'المصحف',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'البحث',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
              label: 'العلامات',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Islamic-inspired theme palette
// ─────────────────────────────────────────────────────────────

const _gold = Color(0xFFD4A843);
const _deepGreen = Color(0xFF0E5A46);
const _cream = Color(0xFFFFF8F0);
const _darkBg = Color(0xFF1A1A1A);

ThemeData _buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _deepGreen,
    primary: _deepGreen,
    secondary: _gold,
    surface: _cream,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Amiri Quran',
    scaffoldBackgroundColor: _cream,
    appBarTheme: AppBarTheme(
      backgroundColor: _deepGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontFamily: 'Amiri Quran',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: _gold.withAlpha(50),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: _deepGreen,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          );
        }
        return TextStyle(color: colorScheme.outline, fontSize: 12);
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _deepGreen.withAlpha(30)),
      ),
      color: Colors.white,
    ),
    dividerTheme: DividerThemeData(
      color: _gold.withAlpha(60),
      thickness: 1,
    ),
  );
}

ThemeData _buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _deepGreen,
    primary: const Color(0xFF5FBF9E),
    secondary: _gold,
    surface: _darkBg,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Amiri Quran',
    scaffoldBackgroundColor: _darkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF12281F),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontFamily: 'Amiri Quran',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _darkBg,
      indicatorColor: _gold.withAlpha(40),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: Color(0xFF5FBF9E),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          );
        }
        return TextStyle(color: colorScheme.outline, fontSize: 12);
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF5FBF9E).withAlpha(30)),
      ),
      color: const Color(0xFF252525),
    ),
    dividerTheme: DividerThemeData(
      color: _gold.withAlpha(40),
      thickness: 1,
    ),
  );
}
