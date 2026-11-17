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
    final off = int.tryParse(await db.getSetting('weekly_off') ?? '') ?? 5;

    final staleLimit =
        int.tryParse(await db.getSetting('stale_days') ?? '') ?? 7;
    final noted = await db.notedOutlets();

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < _days; i++) {
      final at =
          tz.TZDateTime(tz.local, now.year, now.month, now.day + i, hour, minute);
      if (!at.isAfter(now)) continue;

      if (at.weekday == off) continue; // সাপ্তাহিক ছুটির দিনে রিমাইন্ডার নেই

      final date = ymd(at);
      // ওই বারে যেসব রুটে যাওয়ার কথা + টাকা দেওয়ার তারিখ হয়ে যাওয়া আউটলেট
      final markets = await db.marketsOnDay(at.weekday);
      final shops =
          markets.fold<int>(0, (s, m) => s + (m['outlet_count'] as int));
      final promises = (await db.promises(date)).length;
      // ওই দিনের হিসাবে: যেসব দোকানে সীমার বেশি দিন ভিজিট/এন্ট্রি নেই
      final stale = staleLimit > 0
          ? (await db.staleOutlets(staleLimit, asOf: date)).length
          : 0;
      // ওই দিনের রুটগুলোর দোকানে পরের ভিজিটের বিশেষ নোট
      final marketIds = markets.map((m) => m['id']).toSet();
      final todayNotes =
          noted.where((o) => marketIds.contains(o['market_id'])).toList();
      if (shops == 0 && promises == 0 && stale == 0 && todayNotes.isEmpty) {
        continue;
      }

      final parts = <String>[
        if (shops > 0)
          '${markets.map((m) => m['name']).join(', ')} রুটে ${bn(shops)}টি দোকানে ভিজিট',
        if (promises > 0) '${bn(promises)}টি দোকান থেকে টাকা নেওয়ার তারিখ',
        if (stale > 0)
          '${bn(stale)}টি দোকানে ${bn(staleLimit)} দিনের বেশি ভিজিট/এন্ট্রি নেই',
        if (todayNotes.isNotEmpty)
          '${bn(todayNotes.length)}টি দোকানে বিশেষ নোট আছে',
      ];
      // বড় করে খুললে প্রতিটি নোট দোকানের নামসহ দেখা যাবে
      final big = [
        ...parts,
        for (final o in todayNotes.take(5))
          '• ${o['name']}: ${(o['next_note'] as String).trim()}',
      ].join('\n');
      await _plugin.zonedSchedule(
        1000 + i,
        'আজকের কাজ',
        parts.join(' · '),
        at,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_tasks',
            'দৈনিক কাজের রিমাইন্ডার',
            channelDescription: 'আজকের ভিজিট, টাকা চাওয়া ও বিশেষ নোটের রিমাইন্ডার',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(big),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
