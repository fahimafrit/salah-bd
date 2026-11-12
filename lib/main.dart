import 'dart:async';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ===== সেটিংস: শহর পরিবর্তন করতে এখানে বদলান (এখন ঢাকা) =====
const double kLat = 23.8103, kLng = 90.4125;
const kCity = 'ঢাকা';
// ============================================================

const kGreen = Color(0xFF0B5D3B), kDark = Color(0xFF063D27), kGold = Color(0xFFD4A94A);
const kBg = Color(0xFFF4F1E8);
final notif = FlutterLocalNotificationsPlugin();

String bn(Object n) {
  const d = '০১২৩৪৫৬৭৮৯';
  return n.toString().split('').map((c) {
    final i = int.tryParse(c);
    return i == null ? c : d[i];
  }).join();
}

const days = ['সোমবার','মঙ্গলবার','বুধবার','বৃহস্পতিবার','শুক্রবার','শনিবার','রবিবার'];
const months = ['জানুয়ারি','ফেব্রুয়ারি','মার্চ','এপ্রিল','মে','জুন','জুলাই','আগস্ট','সেপ্টেম্বর','অক্টোবর','নভেম্বর','ডিসেম্বর'];

DateTime dhaka(DateTime t) => t.toUtc().add(const Duration(hours: 6));
String fmt(DateTime t) {
  final d = dhaka(t);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${bn(h)}:${bn(d.minute.toString().padLeft(2, '0'))}';
}
String ampm(DateTime t) {
  final h = dhaka(t).hour;
  return h < 4 ? 'রাত' : h < 6 ? 'ভোর' : h < 12 ? 'সকাল' : h < 15 ? 'দুপুর' : h < 17 ? 'বিকাল' : h < 19 ? 'সন্ধ্যা' : 'রাত';
}

class Day {
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;
  Day(this.fajr, this.sunrise, this.dhuhr, this.asr, this.maghrib, this.isha);
  factory Day.of(DateTime date) {
    final p = CalculationMethodParameters.karachi();
    p.madhab = Madhab.hanafi;
    final t = PrayerTimes(coordinates: Coordinates(kLat, kLng), date: date, calculationParameters: p, precision: true);
    return Day(t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha);
  }
}

DateTime todayDate() {
  final d = dhaka(DateTime.now());
  return DateTime.utc(d.year, d.month, d.day);
}

Future<void> scheduleAll() async {
  final android = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();
  await android?.requestExactAlarmsPermission();
  await notif.cancelAll();
  final loc = tz.getLocation('Asia/Dhaka');
  const names = ['ফজর', 'জোহর', 'আসর', 'মাগরিব', 'এশা'];
  for (int i = 0; i < 30; i++) {
    final day = Day.of(todayDate().add(Duration(days: i)));
    final times = [day.fajr, day.dhuhr, day.asr, day.maghrib, day.isha];
    for (int j = 0; j < 5; j++) {
      final when = tz.TZDateTime.from(times[j], loc);
      if (when.isBefore(tz.TZDateTime.now(loc))) continue;
      await notif.zonedSchedule(
        i * 10 + j, '${names[j]} নামাজের সময় হয়েছে', 'নামাজ পড়ার সময় হয়েছে',
        when,
        const NotificationDetails(android: AndroidNotificationDetails(
          'salah', 'নামাজের সময়', importance: Importance.max, priority: Priority.high,
          playSound: true, enableVibration: true, category: AndroidNotificationCategory.alarm)),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await notif.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  runApp(const App());
  try { await scheduleAll(); } catch (_) {}
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'নামাজের সময়',
    theme: ThemeData(colorSchemeSeed: kGreen, scaffoldBackgroundColor: kBg, useMaterial3: true),
    home: const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final today = Day.of(todayDate());
    final tomorrow = Day.of(todayDate().add(const Duration(days: 1)));
    final list = [
      ['ফজর', today.fajr, Icons.nights_stay],
      ['জোহর', today.dhuhr, Icons.wb_sunny],
      ['আসর', today.asr, Icons.wb_twilight],
      ['মাগরিব', today.maghrib, Icons.brightness_3],
      ['এশা', today.isha, Icons.bedtime],
    ];
    int next = list.indexWhere((e) => (e[1] as DateTime).isAfter(now));
    final nextName = next == -1 ? 'ফজর' : list[next][0] as String;
    final nextTime = next == -1 ? tomorrow.fajr : list[next][1] as DateTime;
    final left = nextTime.difference(now);
    String two(int n) => bn(n.toString().padLeft(2, '0'));
    final countdown = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    final d = dhaka(DateTime.now());
    final dateText = '${days[d.weekday - 1]}, ${bn(d.day)} ${months[d.month - 1]} ${bn(d.year)}';

    Widget row(String name, DateTime t, IconData icon, {bool hl = false, bool minor = false}) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: minor ? 10 : 16),
      decoration: BoxDecoration(
        color: hl ? kGreen : Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.07), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Row(children: [
        Icon(icon, color: hl ? kGold : kGreen, size: minor ? 24 : 30),
        const SizedBox(width: 14),
        Expanded(child: Text(name, style: TextStyle(fontSize: minor ? 20 : 26, fontWeight: FontWeight.w600, color: hl ? Colors.white : kDark))),
        Text('${ampm(t)} ', style: TextStyle(fontSize: 16, color: hl ? Colors.white70 : Colors.black54)),
        Text(fmt(t), style: TextStyle(fontSize: minor ? 24 : 30, fontWeight: FontWeight.bold, color: hl ? Colors.white : kDark)),
      ]),
    );

    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [kDark, kGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
          child: Column(children: [
            Text(kCity, style: const TextStyle(color: kGold, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(dateText, style: const TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 22),
            const Text('পরবর্তী নামাজ', style: TextStyle(color: Colors.white70, fontSize: 18)),
            Text(nextName, style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
            Text('${ampm(nextTime)} ${fmt(nextTime)}', style: const TextStyle(color: kGold, fontSize: 28, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            const Text('বাকি আছে', style: TextStyle(color: Colors.white70, fontSize: 16)),
            Text(countdown, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w300, letterSpacing: 2)),
          ]),
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < list.length; i++)
          row(list[i][0] as String, list[i][1] as DateTime, list[i][2] as IconData, hl: i == next),
        const Padding(padding: EdgeInsets.fromLTRB(24, 18, 24, 4),
          child: Text('অন্যান্য সময়', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kDark))),
        row('সূর্যোদয়', today.sunrise, Icons.wb_sunny_outlined, minor: true),
        row('ইশরাকের সময় শুরু', today.sunrise.add(const Duration(minutes: 15)), Icons.light_mode, minor: true),
        row('সেহরির শেষ সময়', today.fajr, Icons.free_breakfast, minor: true),
        row('ইফতারের সময়', today.maghrib, Icons.local_drink, minor: true),
        const Padding(padding: EdgeInsets.fromLTRB(24, 18, 24, 4),
          child: Text('নামাজ পড়া নিষেধ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF9B2C2C)))),
        row('সূর্যোদয়ের সময়', today.sunrise, Icons.block, minor: true),
        row('ঠিক দুপুর (জাওয়াল)', today.dhuhr.subtract(const Duration(minutes: 6)), Icons.block, minor: true),
        row('সূর্যাস্তের সময়', today.maghrib.subtract(const Duration(minutes: 15)), Icons.block, minor: true),
        const SizedBox(height: 30),
      ]),
    );
  }
}
