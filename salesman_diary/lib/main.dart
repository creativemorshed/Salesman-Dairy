import 'package:flutter/material.dart';

import 'lock.dart';
import 'notifications.dart';
import 'screens/home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DiaryApp());
  // নোটিফিকেশন চালু করা (সমস্যা হলে অ্যাপ বন্ধ হবে না)
  Reminders.instance.start();
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'সেলসম্যান ডায়েরি',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B7F5C),
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      // পিন লক পুরো অ্যাপের (সব স্ক্রিনের) উপরে বসে
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
      home: const Home(),
    );
  }
}
