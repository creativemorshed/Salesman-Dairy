import 'package:flutter/material.dart';

import 'lock.dart';
import 'notifications.dart';
import 'screens/home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SalesmanDairyApp());
  // নোটিফিকেশন চালু করা (সমস্যা হলে অ্যাপ বন্ধ হবে না)
  Reminders.instance.start();
}

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
        colorSchemeSeed: const Color(0xFFD9480F),
        scaffoldBackgroundColor: cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFFFFFDF8),
          surfaceTintColor: Colors.transparent,
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
