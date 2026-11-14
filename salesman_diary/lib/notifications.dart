import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'db.dart';
import 'utils.dart';

/// প্রতিদিন নির্দিষ্ট সময়ে "আজকের কাজ" নোটিফিকেশন (ইন্টারনেট লাগে না)।
///
/// কীভাবে কাজ করে: অ্যাপ খুললে বা ডেটা বদলালে, আগামী ১৪ দিনের প্রতিদিনের জন্য
/// ভিজিট/তাগাদার সংখ্যা হিসাব করে ফোনের অ্যালার্মে নোটিফিকেশন বসিয়ে রাখে।
/// যেদিন কোনো কাজ নেই, সেদিন নোটিফিকেশন আসে না।
class Reminders {
  Reminders._();
  static final Reminders instance = Reminders._();

  static const _days = 14;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;
  Timer? _debounce;

  bool get _supported => Platform.isAndroid;

  /// অ্যাপ চালুর সময় একবার ডাকা হয়। কোনো সমস্যা হলে অ্যাপ বন্ধ হবে না।
  Future<void> start() async {
    if (!_supported) return;
    try {
      await _init();
      final db = AppDb.instance;
      // প্রথমবার: ডিফল্ট চালু + অনুমতি চাওয়া
      if (await db.getSetting('notif_enabled') == null) {
        await db.setSetting('notif_enabled', '1');
        await requestPermission();
      }
      await reschedule();
    } catch (_) {
      // নোটিফিকেশন ছাড়াও অ্যাপ চলবে
    }
  }

  Future<void> _init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      // নতুন/পুরনো ভার্সনের জন্য দুই রকম রিটার্ন টাইপই সামলানো হলো
      final dynamic r = await FlutterTimezone.getLocalTimezone();
      final String name = r is String ? r : (r.identifier as String);
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    }
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(init);
    _inited = true;
    // ডেটা বদলালে (একটু থেমে) রিমাইন্ডার নতুন করে বসাও
    AppDb.instance.changes.addListener(_onChange);
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      reschedule().catchError((_) {});
    });
  }

  /// Android 13+ এ নোটিফিকেশনের অনুমতি
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> reschedule() async {
    if (!_supported || !_inited) return;
    await _plugin.cancelAll();

    final db = AppDb.instance;
    if (await db.getSetting('notif_enabled') == '0') return;
    final hour = int.tryParse(await db.getSetting('notif_hour') ?? '') ?? 8;
    final minute = int.tryParse(await db.getSetting('notif_minute') ?? '') ?? 0;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_tasks',
        'দৈনিক কাজের রিমাইন্ডার',
        channelDescription: 'আজকের ভিজিট ও টাকা চাওয়ার রিমাইন্ডার',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < _days; i++) {
      final at =
          tz.TZDateTime(tz.local, now.year, now.month, now.day + i, hour, minute);
      if (!at.isAfter(now)) continue;

      final date = ymd(at);
      final visits = (await db.dueVisits(date)).length;
      final collects = (await db.dueCollections(date)).length;
      if (visits == 0 && collects == 0) continue;

      final parts = <String>[
        if (visits > 0) '${bn(visits)} জনের কাছে ভিজিটে যেতে হবে',
        if (collects > 0) '${bn(collects)} জনের কাছে টাকা চাইতে হবে',
      ];
      await _plugin.zonedSchedule(
        1000 + i,
        'আজকের কাজ',
        parts.join(', '),
        at,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
