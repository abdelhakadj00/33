import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مواقيت الصلاة - المغرب',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, String>> _cities = [
    {'name': 'Rabat', 'ar': 'الرباط'},
    {'name': 'Casablanca', 'ar': 'الدار البيضاء'},
    {'name': 'Fes', 'ar': 'فاس'},
    {'name': 'Marrakech', 'ar': 'مراكش'},
    {'name': 'Tangier', 'ar': 'طنجة'},
    {'name': 'Agadir', 'ar': 'أكادير'},
    {'name': 'Oujda', 'ar': 'وجدة'},
    {'name': 'Meknes', 'ar': 'مكناس'},
    {'name': 'Laayoune', 'ar': 'العيون'},
    {'name': 'Dakhla', 'ar': 'الداخلة'},
    {'name': 'Tetouan', 'ar': 'تطوان'},
    {'name': 'Kenitra', 'ar': 'القنيطرة'},
    {'name': 'Nador', 'ar': 'الناظور'},
    {'name': 'Beni Mellal', 'ar': 'بني ملال'},
    {'name': 'El Jadida', 'ar': 'الجديدة'},
    {'name': 'Khouribga', 'ar': 'خريبكة'},
    {'name': 'Safi', 'ar': 'آسفي'},
    {'name': 'Khemisset', 'ar': 'الخميسات'},
    {'name': 'Taza', 'ar': 'تازة'},
    {'name': 'Settat', 'ar': 'سطات'},
    {'name': 'Larache', 'ar': 'العرائش'},
    {'name': 'Guelmim', 'ar': 'كلميم'},
    {'name': 'Berrechid', 'ar': 'برشيد'},
    {'name': 'Ksar El Kebir', 'ar': 'القصر الكبير'},
    {'name': 'Taourirt', 'ar': 'تاوريرت'},
    {'name': 'Errachidia', 'ar': 'الرشيدية'},
    {'name': 'Ouarzazate', 'ar': 'ورزازات'},
    {'name': 'Taroudant', 'ar': 'تارودانت'},
    {'name': 'Tiznit', 'ar': 'تزنيت'},
    {'name': 'Essaouira', 'ar': 'الصويرة'},
    {'name': 'Al Hoceima', 'ar': 'الحسيمة'},
    {'name': 'Chefchaouen', 'ar': 'شفشاون'},
    {'name': 'Ifrane', 'ar': 'إفران'},
  ];

  String _selectedCity = 'Rabat';
  String _selectedCityArabic = 'الرباط';
  Map<String, String> _timings = {};
  String _hijriDate = '';
  String _gregorianDate = '';
  bool _isLoading = true;
  String _errorMessage = '';
  String _nextPrayer = '';
  String _nextPrayerTime = '';
  String _timeRemaining = '00:00:00';
  Timer? _countdownTimer;
  bool _isDarkMode = false;
  bool _hasInternetConnection = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCity = prefs.getString('selected_city') ?? 'Rabat';
      _selectedCityArabic = prefs.getString('selected_city_arabic') ?? 'الرباط';
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
    await _fetchPrayerTimes();
    _startCountdownIfNeeded();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_city', _selectedCity);
    await prefs.setString('selected_city_arabic', _selectedCityArabic);
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  Future<void> _saveTimingsToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_timings', jsonEncode(_timings));
    await prefs.setString('cached_hijri_date', _hijriDate);
    await prefs.setString('cached_gregorian_date', _gregorianDate);
    await prefs.setString('cached_city', _selectedCity);
  }

  Future<void> _loadTimingsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTimings = prefs.getString('cached_timings');
    if (cachedTimings != null) {
      setState(() {
        _timings = Map<String, String>.from(jsonDecode(cachedTimings));
        _hijriDate = prefs.getString('cached_hijri_date') ?? '';
        _gregorianDate = prefs.getString('cached_gregorian_date') ?? '';
      });
    }
  }

  Future<void> _fetchPrayerTimes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final url = Uri.parse(
          'https://api.aladhan.com/v1/timingsByCity?city=$_selectedCity&country=Morocco&method=21');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['code'] == 200 && jsonResponse['data'] != null) {
          final data = jsonResponse['data'];
          final times = data['timings'];
          final hijri = data['date']['hijri'];
          final gregorian = data['date']['gregorian'];

          setState(() {
            _timings = {
              'الفجر': times['Fajr'] ?? '--:--',
              'الشروق': times['Sunrise'] ?? '--:--',
              'الظهر': times['Dhuhr'] ?? '--:--',
              'العصر': times['Asr'] ?? '--:--',
              'المغرب': times['Maghrib'] ?? '--:--',
              'العشاء': times['Isha'] ?? '--:--',
            };
            _hijriDate =
                '${hijri['weekday']['ar']} ${hijri['day']} ${hijri['month']['ar']} ${hijri['year']}';
            _gregorianDate =
                '${gregorian['weekday']['en']} ${gregorian['day']} ${gregorian['month']['en']} ${gregorian['year']}';
            _isLoading = false;
            _hasInternetConnection = true;
          });

          await _saveTimingsToCache();
          _calculateNextPrayer();
        } else {
          setState(() {
            _errorMessage = 'فشل في جلب البيانات';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'خطأ في الخادم: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      await _loadTimingsFromCache();
      setState(() {
        _isLoading = false;
        _hasInternetConnection = false;
        if (_timings.isEmpty) {
          _errorMessage = 'لا يوجد اتصال بالإنترنت ولا توجد بيانات محفوظة';
        }
      });
      if (_timings.isNotEmpty) {
        _calculateNextPrayer();
      }
    }
  }

  void _calculateNextPrayer() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final prayerOrder = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

    for (var prayer in prayerOrder) {
      if (_timings.containsKey(prayer)) {
        final prayerMinutes = _timeToMinutes(_timings[prayer]!);
        if (prayerMinutes > currentMinutes) {
          setState(() {
            _nextPrayer = prayer;
            _nextPrayerTime = _timings[prayer]!;
          });
          return;
        }
      }
    }

    setState(() {
      _nextPrayer = 'الفجر';
      _nextPrayerTime = _timings['الفجر'] ?? '--:--';
    });
  }

  void _startCountdownIfNeeded() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextPrayer.isEmpty || _nextPrayerTime.isEmpty) return;

      final now = DateTime.now();
      final parts = _nextPrayerTime.split(':');
      final prayerDateTime = DateTime(
          now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));

      if (prayerDateTime.isBefore(now) || prayerDateTime.isAtSameMomentAs(now)) {
        setState(() {
          _timeRemaining = '00:00:00';
        });
        return;
      }

      final difference = prayerDateTime.difference(now);
      setState(() {
        _timeRemaining =
            '${difference.inHours.toString().padLeft(2, '0')}:${(difference.inMinutes % 60).toString().padLeft(2, '0')}:${(difference.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> _toggleDarkMode() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await _saveSettings();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleDarkMode,
            tooltip: _isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _timings.isEmpty
              ? _buildErrorScreen()
              : _buildMainContent(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.mosque, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                const Text(
                  'مواقيت الصلاة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'حسب وزارة الأوقاف المغربية',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('الرئيسية'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('حول التطبيق'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog();
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _hasInternetConnection ? 'متصل بالإنترنت' : 'وضع عدم الاتصال',
              style: TextStyle(
                color: _hasInternetConnection ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchPrayerTimes,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _fetchPrayerTimes,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildNextPrayerCard(),
              const SizedBox(height: 16),
              _buildCitySelector(),
              const SizedBox(height: 16),
              _buildDateCard(),
              const SizedBox(height: 16),
              _buildPrayerTimesList(),
              const SizedBox(height: 16),
              if (!_hasInternetConnection)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'أنت في وضع عدم الاتصال. يتم عرض البيانات المحفوظة.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'حسب توقيت وزارة الأوقاف والشؤون الإسلامية',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'الصلاة القادمة',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _nextPrayer,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _nextPrayerTime,
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  _timeRemaining,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر المدينة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCity,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _cities.map((city) {
                return DropdownMenuItem<String>(
                  value: city['name'],
                  child: Text(city['ar']!, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  final city = _cities.firstWhere((c) => c['name'] == newValue);
                  setState(() {
                    _selectedCity = newValue;
                    _selectedCityArabic = city['ar']!;
                  });
                  _fetchPrayerTimes();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary, size: 32),
                  const SizedBox(height: 8),
                  const Text('التاريخ الهجري',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    _hijriDate,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 50, color: Colors.grey.shade300),
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.calendar_month,
                      color: Theme.of(context).colorScheme.primary, size: 32),
                  const SizedBox(height: 8),
                  const Text('التاريخ الميلادي',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    _gregorianDate,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimesList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مواقيت الصلاة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._timings.entries.map((entry) => _buildPrayerCard(entry.key, entry.value)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerCard(String name, String time) {
    IconData icon;
    Color color;
    switch (name) {
      case 'الفجر':
        icon = Icons.nightlight_round;
        color = Colors.indigo;
        break;
      case 'الشروق':
        icon = Icons.wb_sunny;
        color = Colors.orange;
        break;
      case 'الظهر':
        icon = Icons.sunny;
        color = Colors.amber;
        break;
      case 'العصر':
        icon = Icons.wb_cloudy;
        color = Colors.cyan;
        break;
      case 'المغرب':
        icon = Icons.nights_stay;
        color = Colors.deepOrange;
        break;
      case 'العشاء':
        icon = Icons.nightlight;
        color = Colors.deepPurple;
        break;
      default:
        icon = Icons.access_time;
        color = Colors.grey;
    }

    final isNextPrayer = name == _nextPrayer;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNextPrayer ? color.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(12),
        border: isNextPrayer ? Border.all(color: color, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isNextPrayer ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isNextPrayer ? color : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول التطبيق'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تطبيق مواقيت الصلاة للمدن المغربية'),
            SizedBox(height: 8),
            Text('الإصدار: 4.0.0'),
            SizedBox(height: 8),
            Text('المواقيت حسب وزارة الأوقاف والشؤون الإسلامية المغربية'),
            SizedBox(height: 8),
            Text('يعمل بدون إنترنت بعد أول تحميل'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
