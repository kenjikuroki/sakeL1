import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'widgets/ad_banner.dart';
import 'utils/ad_manager.dart';


import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';
import 'pages/settings_page.dart';
import 'utils/purchase_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// 1. Data Models & Helpers
// -----------------------------------------------------------------------------

class Quiz {
  final String question;
  final bool isCorrect;
  final String explanation;
  final String? imagePath;

  Quiz({
    required this.question,
    required this.isCorrect,
    required this.explanation,
    this.imagePath,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    dynamic imagePathVal = json['imagePath'];
    String? finalImagePath;
    if (imagePathVal is List) {
      if (imagePathVal.isNotEmpty) {
        finalImagePath = imagePathVal.first as String?;
      }
    } else if (imagePathVal is String) {
      finalImagePath = imagePathVal;
    }

    return Quiz(
      question: (json['question'] as String).replaceAll('\n', ''),
      isCorrect: json['isCorrect'] as bool,
      explanation: json['explanation'] as String,
      imagePath: finalImagePath,
    );
  }
}

class PrefsHelper {
  static const String _keyWeakQuestions = 'weak_questions';
  static const String _keyAdCounter = 'ad_counter';
  static const String _keyIsPremium = 'is_premium';

  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsPremium) ?? false;
  }

  static Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPremium, value);
  }

  static Future<bool> shouldShowInterstitial() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyAdCounter) ?? 0;
    current++;
    await prefs.setInt(_keyAdCounter, current);
    return (current % 3 == 0);
  }
  
  static Future<void> saveHighScore(String categoryKey, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getInt(categoryKey) ?? 0;
    if (score > currentHigh) {
      await prefs.setInt(categoryKey, score);
    }
  }

  static Future<int> getHighScore(String categoryKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(categoryKey) ?? 0;
  }

  static Future<void> addWeakQuestions(List<String> questions) async {
    if (questions.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyWeakQuestions) ?? [];
    
    bool changed = false;
    for (final q in questions) {
      if (!current.contains(q)) {
        current.add(q);
        changed = true;
      }
    }
    
    if (changed) {
      await prefs.setStringList(_keyWeakQuestions, current);
    }
  }

  static Future<void> removeWeakQuestions(List<String> questions) async {
    if (questions.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyWeakQuestions) ?? [];
    
    bool changed = false;
    for (final q in questions) {
       if (current.remove(q)) {
         changed = true;
       }
    }
    
    if (changed) {
      await prefs.setStringList(_keyWeakQuestions, current);
    }
  }

  static Future<List<String>> getWeakQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyWeakQuestions) ?? [];
  }
}

class QuizData {
  static Map<String, List<Quiz>> _data = {};

  static Future<void> load(BuildContext context) async {
    try {
      final locale = Localizations.localeOf(context);
      final isSpanish = locale.languageCode == 'es';
      final fileName = isSpanish ? 'assets/quiz_data_ES.json' : 'assets/quiz_data_EN.json';
      
      final String jsonString = await rootBundle.loadString(fileName);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      _data = {};
      jsonData.forEach((key, value) {
        if (value is List) {
          _data[key] = value.map((q) => Quiz.fromJson(q)).toList();
        }
      });
    } catch (e) {
      debugPrint("Error loading quiz data: $e");
      _data = {};
    }
  }

  static List<Quiz> get part1 => _data['part1'] ?? [];
  static List<Quiz> get part2 => _data['part2'] ?? [];
  static List<Quiz> get part3 => _data['part3'] ?? [];
  static List<Quiz> get part4 => _data['part4'] ?? [];


  static List<Quiz> getQuizzesFromTexts(List<String> texts) {
    final allQuizzes = [
      ...part1,
      ...part2,
      ...part3,
      ...part4,

    ];
    return allQuizzes.where((q) => texts.contains(q.question)).toList();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('ja'),
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50), // Chic Dark
          primary: const Color(0xFF2C3E50),
          secondary: const Color(0xFFBFA05D), // Muted Gold accent
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5), // Soft Grey
        textTheme: GoogleFonts.loraTextTheme(), // Use Lora font
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C3E50), // Chic Dark Blue-Grey
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }

}

// -----------------------------------------------------------------------------
// 2. Home Page
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _weaknessCount = 0;
  bool _isLoading = true;
  bool _isPremium = false;
  bool _isShuffleMode = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // 1. Wait for 1 second
    await Future.delayed(const Duration(seconds: 1));

    // 2. Request ATT
    final status = await AppTrackingTransparency.requestTrackingAuthorization();
    debugPrint("ATT Status: $status");

    // 3. Initialize Ads
    await MobileAds.instance.initialize();
    

    if (!await PrefsHelper.isPremium()) {
      AdManager.instance.preloadAd('home');
    }

    // 5. Init Purchase Manager
    await PurchaseManager.instance.initialize();
    PurchaseManager.instance.isPremiumNotifier.addListener(_onPremiumChanged);
    _onPremiumChanged(); // initial check

    if (context.mounted) {
      await QuizData.load(context);
    }
    await _loadUserData();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPremiumChanged() {
    final val = PurchaseManager.instance.isPremiumNotifier.value;
    if (mounted) {
      setState(() {
        _isPremium = val;
      });
    }
  }

  @override
  void dispose() {
    PurchaseManager.instance.isPremiumNotifier.removeListener(_onPremiumChanged);
    super.dispose();
  }

  
  Future<void> _loadUserData() async {
    final weakList = await PrefsHelper.getWeakQuestions();
    if (mounted) {
      setState(() {
        _weaknessCount = weakList.length;
      });
    }
  }

  void _startQuiz(BuildContext context, List<Quiz> quizList, String categoryKey, {bool isRandom10 = true}) async {
    List<Quiz> questionsToUse = List<Quiz>.from(quizList);
    
    if (isRandom10) {
      questionsToUse.shuffle();
      if (questionsToUse.length > 10) {
        questionsToUse = questionsToUse.take(10).toList();
      }
    } else {
      // Sequential mode - do NOT shuffle, use all questions
    }
    
    if (!_isPremium) {
      AdManager.instance.preloadAd('result');
      AdManager.instance.preloadAd('quiz');
      AdManager.instance.preloadInterstitial();
    }
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: questionsToUse,
          categoryKey: categoryKey,
          totalQuestions: questionsToUse.length,
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData();
  }

  void _startWeaknessReview(BuildContext context) async {
    final weakTexts = await PrefsHelper.getWeakQuestions();
    if (!mounted) return;
    if (weakTexts.isEmpty) return;

    final rawWeakQuizzes = QuizData.getQuizzesFromTexts(weakTexts);
    if (!mounted) return;

    // Active category sets
    final p1Set = QuizData.part1.map((q) => q.question).toSet();
    final p2Set = QuizData.part2.map((q) => q.question).toSet();
    final p3Set = QuizData.part3.map((q) => q.question).toSet();

    // Filter weak quizzes to only include those in active categories
    // This fixes the count discrepancy where hidden Part 4 questions were being counted in "All"
    final allWeakQuizzes = rawWeakQuizzes.where((q) {
      return p1Set.contains(q.question) || 
             p2Set.contains(q.question) || 
             p3Set.contains(q.question);
    }).toList();

    if (allWeakQuizzes.isEmpty) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noData)),
        );
      }
      return;
    }

    final counts = {
      'all': allWeakQuizzes.length,
      'part1': allWeakQuizzes.where((q) => p1Set.contains(q.question)).length,
      'part2': allWeakQuizzes.where((q) => p2Set.contains(q.question)).length,
      'part3': allWeakQuizzes.where((q) => p3Set.contains(q.question)).length,
    };

    final l10n = AppLocalizations.of(context)!;

    // Show category selection
    final selectedCategory = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header centered
              Center(
                child: Text(
                  l10n.selectCategory,
                  style: GoogleFonts.lora(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Categories List
              _buildCategoryCard(
                context, 
                title: l10n.allCategories, 
                count: counts['all']!, 
                icon: Icons.all_inclusive, 
                color: Colors.blueGrey[50]!, 
                iconColor: Colors.blueGrey,
                onTap: () => Navigator.pop(context, 'all'),
              ),
              const SizedBox(height: 12),
              _buildCategoryCard(
                context, 
                title: l10n.part1Title, 
                count: counts['part1']!, 
                icon: Icons.water_drop, 
                color: Colors.blue[50]!, 
                iconColor: Colors.blueAccent,
                onTap: () => Navigator.pop(context, 'part1'),
              ),
              const SizedBox(height: 12),
              _buildCategoryCard(
                context, 
                title: l10n.part2Title, 
                count: counts['part2']!, 
                icon: Icons.biotech, 
                color: Colors.teal[50]!, 
                iconColor: Colors.teal,
                onTap: () => Navigator.pop(context, 'part2'),
              ),
              const SizedBox(height: 12),
              _buildCategoryCard(
                context, 
                title: l10n.part3Title, 
                count: counts['part3']!, 
                icon: Icons.label, 
                color: Colors.purple[50]!, 
                iconColor: Colors.purpleAccent,
                onTap: () => Navigator.pop(context, 'part3'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedCategory == null) return;

    List<Quiz> filteredQuizzes;
    if (selectedCategory == 'all') {
      filteredQuizzes = allWeakQuizzes;
    } else {
      Set<String> poolSet;
      switch (selectedCategory) {
        case 'part1': poolSet = p1Set; break;
        case 'part2': poolSet = p2Set; break;
        case 'part3': poolSet = p3Set; break;
        default: poolSet = {};
      }
      filteredQuizzes = allWeakQuizzes.where((q) => poolSet.contains(q.question)).toList();
    }

    if (filteredQuizzes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noData)),
        );
      }
      return;
    }

    if (!_isPremium) {
      AdManager.instance.preloadAd('result');
      AdManager.instance.preloadAd('quiz');
      AdManager.instance.preloadInterstitial();
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: filteredQuizzes,
          isWeaknessReview: true,
          totalQuestions: filteredQuizzes.length,
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData();
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$count ${AppLocalizations.of(context)!.imageQuestion.contains('Imagen') ? 'preguntas' : AppLocalizations.of(context)!.imageQuestion.contains('画像') ? '問' : 'questions'}",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startQuizByCategory(BuildContext context, String partKey) {
    List<Quiz> quizzes;
    String highScoreKey;
    switch(partKey) {
      case 'part1': quizzes = QuizData.part1; highScoreKey = 'highscore_part1'; break;
      case 'part2': quizzes = QuizData.part2; highScoreKey = 'highscore_part2'; break;
      case 'part3': quizzes = QuizData.part3; highScoreKey = 'highscore_part3'; break;
      case 'part4': quizzes = QuizData.part4; highScoreKey = 'highscore_part4'; break;

      default: quizzes = []; highScoreKey = '';
    }
    
    if (quizzes.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(AppLocalizations.of(context)!.noData)),
       );
       return;
    }
    _startQuiz(context, quizzes, highScoreKey, isRandom10: _isShuffleMode);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.homeTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
               Navigator.of(context).push(
                 MaterialPageRoute(builder: (_) => const SettingsPage()),
               );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context)!.homeSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Shuffle/Sequential Toggle (Pill shape)
                  Center(
                    child: Container(
                      height: 48,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          _buildToggleButtonSection(
                            icon: Icons.shuffle,
                            isSelected: _isShuffleMode,
                            onTap: () => setState(() => _isShuffleMode = true),
                            isLeft: true,
                          ),
                          _buildToggleButtonSection(
                            icon: Icons.format_list_numbered,
                            isSelected: !_isShuffleMode,
                            onTap: () => setState(() => _isShuffleMode = false),
                            isLeft: false,
                            isLocked: !_isPremium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Part 1
                  _MenuButton(
                    title: AppLocalizations.of(context)!.part1Title,
                    icon: Icons.water_drop, // Changed from waves
                    iconColor: Colors.blueAccent,
                    onTap: () => _startQuizByCategory(context, 'part1'),
                  ),
                  const SizedBox(height: 16),

                  // Part 2
                  _MenuButton(
                    title: AppLocalizations.of(context)!.part2Title,
                    icon: Icons.workspace_premium, // Changed from local_bar (martini)
                    iconColor: Colors.orange,
                    onTap: () => _startQuizByCategory(context, 'part2'),
                  ),
                  const SizedBox(height: 16),

                  // Part 3
                  _MenuButton(
                    title: AppLocalizations.of(context)!.part3Title,
                    icon: Icons.room_service, // Changed from thermostat
                    iconColor: Colors.redAccent,
                    onTap: () => _startQuizByCategory(context, 'part3'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Part 4 - REMOVED

                  const SizedBox(height: 40),

                  // Weakness Review
                  ElevatedButton.icon(
                    onPressed: _weaknessCount > 0 ? () => _startWeaknessReview(context) : null,
                    icon: const Icon(Icons.refresh),
                    label: Text("${AppLocalizations.of(context)!.reviewWeakness} ($_weaknessCount)"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Sister App Promotion
                  const _SisterAppPromo(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Ad Banner REMOVED FROM HERE
        ],
      ),
    );
  }

  void _showPremiumUnlockDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rich Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFD700), Color(0xFFFFB300), Color(0xFFFFA000)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.removeAds,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                   _buildFeatureRow(Icons.format_list_numbered, l10n.premiumFeature2),
                   const SizedBox(height: 12),
                   _buildFeatureRow(Icons.block, l10n.premiumFeature1),
                   const SizedBox(height: 12),
                   _buildFeatureRow(Icons.category, l10n.premiumFeature3),
                   
                   const SizedBox(height: 32),
                   
                   // Buy Button
                   Container(
                     width: double.infinity,
                     height: 56,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(28),
                       boxShadow: [
                         BoxShadow(
                           color: const Color(0xFFFFB300).withOpacity(0.3),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                       ],
                     ),
                     child: ElevatedButton(
                       onPressed: () {
                         Navigator.pop(context);
                         Navigator.of(context).push(
                           MaterialPageRoute(builder: (_) => const SettingsPage()),
                         );
                       },
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFFFFB300),
                         foregroundColor: Colors.white,
                         elevation: 0,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                       ),
                       child: Text(
                         l10n.buy,
                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                       ),
                     ),
                   ),
                   
                   const SizedBox(height: 8),
                   TextButton(
                     onPressed: () => Navigator.pop(context),
                     child: Text(
                       l10n.cancel, 
                       style: TextStyle(color: Colors.black.withOpacity(0.4), fontWeight: FontWeight.w500),
                     ),
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFFFB300)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButtonSection({
    required IconData icon, 
    required bool isSelected, 
    required VoidCallback onTap,
    required bool isLeft,
    bool isLocked = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isLocked ? () => _showPremiumUnlockDialog(context) : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C3E50) : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isLeft ? 24 : 0),
              bottomLeft: Radius.circular(isLeft ? 24 : 0),
              topRight: Radius.circular(!isLeft ? 24 : 0),
              bottomRight: Radius.circular(!isLeft ? 24 : 0),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              if (isLocked)
                Icon(
                  Icons.lock,
                  size: 32,
                  color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.black45,
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLocked;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isLocked ? Icons.lock : Icons.chevron_right, 
                  color: isLocked ? Colors.grey : Colors.grey[400]
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// 3. Quiz Page
// -----------------------------------------------------------------------------

class QuizPage extends StatefulWidget {
  final List<Quiz> quizzes;
  final String? categoryKey;
  final bool isWeaknessReview;
  final int totalQuestions;

  const QuizPage({
    super.key,
    required this.quizzes,
    this.categoryKey,
    this.isWeaknessReview = false,
    required this.totalQuestions,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final AppinioSwiperController controller = AppinioSwiperController();
  
  int _score = 0;
  int _currentIndex = 1;
  final List<Quiz> _incorrectQuizzes = [];
  final List<Quiz> _correctQuizzesInReview = [];
  final List<Map<String, dynamic>> _answerHistory = [];
  Color _backgroundColor = const Color(0xFFF0F2F5);

  void _handleSwipeEnd(int previousIndex, int targetIndex, SwiperActivity activity) {
    if (activity is Swipe) {
      final quiz = widget.quizzes[previousIndex];
      bool userVal = (activity.direction == AxisDirection.right);
      bool isCorrect = (userVal == quiz.isCorrect);

      _answerHistory.add({
        'quiz': quiz,
        'result': isCorrect,
      });

      setState(() {
        if (isCorrect) {
          _score++;
          _backgroundColor = Colors.green.withValues(alpha: 0.2);
          HapticFeedback.lightImpact();
          
          if (widget.isWeaknessReview) {
            _correctQuizzesInReview.add(quiz);
          }
        } else {
          _backgroundColor = Colors.red.withValues(alpha: 0.2);
          _incorrectQuizzes.add(quiz);
          HapticFeedback.heavyImpact();
        }
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _backgroundColor = const Color(0xFFF0F2F5);
          });
        }
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 600),
          content: Text(
            isCorrect ? AppLocalizations.of(context)!.correct : AppLocalizations.of(context)!.incorrect,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFD64545),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.5,
            left: 50,
            right: 50,
          ),
        ),
      );

      setState(() {
        if (_currentIndex < widget.totalQuestions) {
          _currentIndex++;
        }
      });

      if (previousIndex == widget.quizzes.length - 1) {
        _finishQuiz();
      }
    }
  }

  Future<void> _finishQuiz() async {
    if (widget.categoryKey != null) {
      await PrefsHelper.saveHighScore(widget.categoryKey!, _score);
    }

    if (_incorrectQuizzes.isNotEmpty) {
      final incorrectTexts = _incorrectQuizzes.map((q) => q.question).toList();
      await PrefsHelper.addWeakQuestions(incorrectTexts);
    }

    if (widget.isWeaknessReview && _correctQuizzesInReview.isNotEmpty) {
      final correctTexts = _correctQuizzesInReview.map((q) => q.question).toList();
      await PrefsHelper.removeWeakQuestions(correctTexts);
    }
    
    if (mounted) {
      final shouldShow = await PrefsHelper.shouldShowInterstitial();
      
      if (shouldShow) {
        AdManager.instance.showInterstitial(
          onComplete: () {
            if (mounted) {
              _navigateToResult();
            }
          },
        );
      } else {
        _navigateToResult();
      }
    }
  }

  void _navigateToResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultPage(
          score: _score,
          total: widget.quizzes.length,
          history: _answerHistory,
          incorrectQuizzes: _incorrectQuizzes,
          originalQuizzes: widget.quizzes,
          categoryKey: widget.categoryKey,
          isWeaknessReview: widget.isWeaknessReview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true, 
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: _backgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${AppLocalizations.of(context)!.questionLabel} $_currentIndex",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "$_currentIndex / ${widget.totalQuestions}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _currentIndex / widget.totalQuestions,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppinioSwiper(
                  controller: controller,
                  cardCount: widget.quizzes.length,
                  loop: false,
                  backgroundCardCount: 2,
                  swipeOptions: const SwipeOptions.symmetric(horizontal: true, vertical: false),
                  onSwipeEnd: _handleSwipeEnd,
                  cardBuilder: (context, index) {
                    return _buildCard(widget.quizzes[index]);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.only(bottom: 40, top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        controller.unswipe();
                        setState(() {
                          if (_currentIndex > 1) {
                            _currentIndex--;
                          }
                          if (_answerHistory.isNotEmpty) {
                            final last = _answerHistory.removeLast();
                            final bool wasCorrect = last['result'];
                            final Quiz quiz = last['quiz'];
                            
                            if (wasCorrect) {
                              _score--;
                              if (widget.isWeaknessReview) {
                                _correctQuizzesInReview.remove(quiz);
                              }
                            } else {
                              _incorrectQuizzes.remove(quiz);
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.undo),
                      label:  Text(AppLocalizations.of(context)!.retry),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
              // Ad Banner added here
              if (!PurchaseManager.instance.isPremiumNotifier.value)
                const SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 60,
                    child: AdBanner(adKey: 'quiz'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Quiz quiz) {
    bool hasImage = quiz.imagePath != null;

    return Container(
      margin: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, // 上詰め
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage) 
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: Image.asset(
                  quiz.imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text("Image not found", style: TextStyle(color: Colors.grey[600])),
                      ],
                    );
                  },
                ),
              ),
            )
          else 
            const SizedBox(height: 40),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const Text(
                    "Q.",
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    textAlign: TextAlign.center, // ここは中央配置
                  ),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: AutoSizeText(
                      quiz.question,
                      style: TextStyle(
                        fontSize: hasImage ? 24 : 32, // 基本サイズ
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.left, // 左寄せ
                      minFontSize: 12,
                      stepGranularity: 1,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 20, // 複数行表示を保証
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.only(left: 40.0, right: 40.0, bottom: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.close, color: Color(0xFFD64545), size: 48),
                Icon(Icons.check, color: Color(0xFF2E7D32), size: 48),
              ],
            ),
          ),
          if (hasImage) const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Result Page
// -----------------------------------------------------------------------------

class ResultPage extends StatelessWidget {
  final int score;
  final int total;
  final List<Map<String, dynamic>> history;
  final List<Quiz> incorrectQuizzes;
  final List<Quiz> originalQuizzes;
  final String? categoryKey;
  final bool isWeaknessReview;

  const ResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.history,
    required this.incorrectQuizzes,
    required this.originalQuizzes,
    this.categoryKey,
    required this.isWeaknessReview,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea( // 1. SafeArea内
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // 1. 上部エリア
            // -----------------------------------------------------------------
            const AdBanner(adKey: 'result'), // 一番上に広告バナー

            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32), // 角丸32px
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text(
                        AppLocalizations.of(context)!.scoreLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$score/$total", // 9/10
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  
                  if (score == total)
                    Text(
                      AppLocalizations.of(context)!.perfectMessage,
                      style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold),
                    )
                  else
                    Text(
                      score >= (total * 0.8) ? AppLocalizations.of(context)!.passMessage : AppLocalizations.of(context)!.failMessage,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: score >= (total * 0.8) ? Colors.green : Colors.red,
                      ),
                    ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // 2. 中央エリア（スクロール可能なリスト）
            // -----------------------------------------------------------------
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final Quiz quiz = item['quiz'];
                  final bool isCorrect = item['result'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), // 角丸16px
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green : Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quiz.question,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    if (quiz.imagePath != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.image, size: 16, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Text(AppLocalizations.of(context)!.imageQuestion, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.05), // 薄い青灰色
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "💡 ${quiz.explanation}",
                              style: TextStyle(color: Colors.blueGrey[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // -----------------------------------------------------------------
            // 3. 下部エリア（固定フッター）
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF0F2F5),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 左ボタン: 「ミスを確認」 (全問正解時は非表示)
                      if (incorrectQuizzes.isNotEmpty) ...[
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => QuizPage(
                                      quizzes: incorrectQuizzes,
                                      isWeaknessReview: true,
                                      totalQuestions: incorrectQuizzes.length,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text(AppLocalizations.of(context)!.reviewMistakes),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Right Button: Retry or Home
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              if (isWeaknessReview) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                return;
                              }

                              final shuffledAgain = List<Quiz>.from(originalQuizzes)..shuffle();
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => QuizPage(
                                    quizzes: shuffledAgain,
                                    categoryKey: categoryKey,
                                    totalQuestions: shuffledAgain.length,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blueAccent,
                              elevation: 0,
                              side: const BorderSide(color: Colors.blueAccent, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: Text(isWeaknessReview ? AppLocalizations.of(context)!.backToHome : AppLocalizations.of(context)!.retry),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  
                  // Back to home link
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Text(AppLocalizations.of(context)!.backToHome, style: const TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SisterAppPromo extends StatelessWidget {
  const _SisterAppPromo();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showConfirmationDialog(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/sister_app_icon.jpg',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.sisterAppSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.sisterAppTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.launch, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/sister_app_icon.jpg', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.sisterAppPopupTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.sisterAppPopupBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        AppLocalizations.of(context)!.cancel,
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final url = Uri.parse('https://apps.apple.com/app/id6757795299');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.open,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
