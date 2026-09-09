import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/bookmarks_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'services/bookmark_service.dart';
import 'services/quran_service.dart';
import 'services/settings_service.dart';
import 'services/ui_controller.dart';
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

  runApp(const QuranApp());
}

class QuranApp extends StatefulWidget {
  const QuranApp({super.key});

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  _AppServices? _services;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _retryBootstrap() {
    setState(() => _error = null);
    _bootstrap();
  }

  /// تهيئة الخدمات بعد رسم أول إطار — تظهر شاشة البداية فورًا بدل
  /// تجمّد الإقلاع. فك ملفات JSON الكبيرة يجري داخل [QuranService.load]
  /// على isolate خلفي فلا تُجمّد واجهة المستخدم.
  Future<void> _bootstrap() async {
    try {
      final quranService = await QuranService.load();

      final bookmarkService = BookmarkService();
      final settingsService = SettingsService();
      await Future.wait([bookmarkService.init(), settingsService.init()]);

      // تسخين بيانات تخطيط المصحف مبكرًا (بالتوازي مع أول ظهور).
      unawaited(quranService.layout());

      if (mounted) {
        setState(() {
          _services = _AppServices(
            quranService: quranService,
            bookmarkService: bookmarkService,
            settingsService: settingsService,
          );
        });
      }
    } catch (error, stackTrace) {
      // فشل التهيئة لا يُبقي المستخدم عالقًا في شاشة البداية أبدًا.
      developer.log(
        'Bootstrap failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
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
      home: _error != null
          ? _BootstrapErrorView(error: _error!, onRetry: _retryBootstrap)
          : services == null
              ? const _SplashView()
              : HomeShell(
              quranService: services.quranService,
              bookmarkService: services.bookmarkService,
              settingsService: services.settingsService,
            ),
    );
  }
}

class _AppServices {
  const _AppServices({
    required this.quranService,
    required this.bookmarkService,
    required this.settingsService,
  });

  final QuranService quranService;
  final BookmarkService bookmarkService;
  final SettingsService settingsService;
}  /// شاشة فشل التهيئة — رسالة واضحة مع زر إعادة المحاولة بدل شاشة بداية
  /// معلّقة إلى الأبد.
class _BootstrapErrorView extends StatelessWidget {
  const _BootstrapErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E5A46),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Color(0xFFD4A843),
              ),
              const SizedBox(height: 16),
              const Text(
                'تعذّر تحميل بيانات التطبيق',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              // تفاصيل الخطأ تظهر هنا مباشرة لتشخيص المشكلة من لقطة شاشة.
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(150),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شاشة البداية أثناء تهيئة الخدمات (أجزاء من الثانية عادةً).
class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E5A46),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'القرآن الكريم',
              style: TextStyle(
                fontFamily: 'Amiri Quran',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white.withAlpha(230),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFD4A843),
              ),
            ),
          ],
        ),
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
  // التنقل بين التبويبات يُدار عبر ValueNotifier حتى يستمر ظهور الشريط السفلي
  // عبر كل الشاشات (بما فيها شاشة القراءة) مع الحفاظ على حالة كل تبويب.
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _tabIndex = ValueNotifier<int>(0);
  final UiController _uiController = UiController();

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
          uiController: _uiController,
        ),
      ),
      SafeChild(
        builder: (_) => SearchScreen(
          quranService: widget.quranService,
          bookmarkService: widget.bookmarkService,
          settingsService: widget.settingsService,
          uiController: _uiController,
        ),
      ),
      SafeChild(
        builder: (_) => BookmarksScreen(
          quranService: widget.quranService,
          bookmarkService: widget.bookmarkService,
          settingsService: widget.settingsService,
          uiController: _uiController,
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _tabIndex.dispose();
    _uiController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    // إن كانت شاشة القراءة مفتوحة، أغلقها ثم بدّل التبويب.
    final nav = _navKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
    _tabIndex.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // زر الرجوع: أغلق شاشة القراءة أولًا، ثم اخرج من التطبيق.
          final nav = _navKey.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: Navigator(
            key: _navKey,
            onGenerateRoute: (settings) => MaterialPageRoute<dynamic>(
              settings: settings,
              builder: (_) => ValueListenableBuilder<int>(
                valueListenable: _tabIndex,
                builder: (_, index, _) =>
                    IndexedStack(index: index, children: _tabs),
              ),
            ),
          ),
          bottomNavigationBar: ValueListenableBuilder<int>(
            valueListenable: _tabIndex,
            builder: (_, index, _) => ValueListenableBuilder<bool>(
              valueListenable: _uiController.chromeVisible,
              builder: (_, visible, _) {
                final navBar = NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: _onDestinationSelected,
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
                );
                // في وضع التركيز يُخفي الشريط السفلي لتمتلئ الصفحة بكامل الشاشة.
                return AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.bottomCenter,
                  child: visible
                      ? navBar
                      : const SizedBox(width: double.infinity),
                );
              },
            ),
          ),
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
    appBarTheme: const AppBarTheme(
      backgroundColor: _deepGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
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
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF12281F),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
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
