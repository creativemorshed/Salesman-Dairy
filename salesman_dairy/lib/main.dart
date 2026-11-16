import 'package:flutter/material.dart';

import 'db.dart';
import 'lock.dart';
import 'notifications.dart';
import 'screens/home.dart';
import 'state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SalesmanDairyApp());
  AppDb.instance.getSetting('stale_days').then((v) {
    final n = int.tryParse(v ?? '');
    if (n != null) staleDays.value = n;
  }).catchError((_) {});
  // নোটিফিকেশন চালু করা (সমস্যা হলে অ্যাপ বন্ধ হবে না)
  Reminders.instance.start();
}

/// পুরো অ্যাপের লেখার মাপ — Hind Siliguri, একটাই স্কেল:
/// বড় সংখ্যা ৩৬ · শিরোনাম ২২/২০/১৬ · মূল লেখা ১৫/১৪ · ছোট ১২.৫
/// (বাংলা অক্ষরের জন্য লাইন-হাইট একটু বেশি, যাতে মাত্রা/কার কাটা না পড়ে)
const _textTheme = TextTheme(
  displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.25),
  headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
  titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
  bodyLarge: TextStyle(fontSize: 16, height: 1.5),
  bodyMedium: TextStyle(fontSize: 14, height: 1.5),
  bodySmall: TextStyle(fontSize: 12.5, height: 1.45),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
  labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.3),
  labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
);

class SalesmanDairyApp extends StatelessWidget {
  const SalesmanDairyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFF6F1E7);
    return MaterialApp(
      title: 'Salesman Dairy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'HindSiliguri', // অ্যাপের সাথেই আসে, ইন্টারনেট লাগে না
        colorSchemeSeed: const Color(0xFFD9480F),
        scaffoldBackgroundColor: cream,
        textTheme: _textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: cream,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: _textTheme.titleLarge
              ?.copyWith(color: const Color(0xFF1B2A24)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFDF8),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStatePropertyAll(
              _textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500)),
        ),
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      // পিন লক পুরো অ্যাপের (সব স্ক্রিনের) উপরে বসে
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
      home: const Home(),
    );
  }
}
