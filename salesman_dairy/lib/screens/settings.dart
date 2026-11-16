import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db.dart';
import '../lock.dart';
import '../notifications.dart';
import '../sheets.dart';
import '../state.dart';
import '../utils.dart';
import 'expenses.dart';
import 'markets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loaded = false;
  bool _notif = true;
  bool _hasPin = false;
  bool _bio = false;
  int _off = 5; // সাপ্তাহিক ছুটি (১=সোম…৭=রবি, ০=নেই)
  int _stale = 7; // কত দিন ভিজিট/এন্ট্রি না থাকলে রিমাইন্ডার (০ = বন্ধ)
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDb.instance;
    final n = await db.getSetting('notif_enabled');
    final h = int.tryParse(await db.getSetting('notif_hour') ?? '') ?? 8;
    final m = int.tryParse(await db.getSetting('notif_minute') ?? '') ?? 0;
    final off = int.tryParse(await db.getSetting('weekly_off') ?? '') ?? 5;
    final stale = int.tryParse(await db.getSetting('stale_days') ?? '') ?? 7;
    final pin = await AppLock.instance.hasPin();
    final bio = await AppLock.instance.biometricEnabled();
    if (!mounted) return;
    setState(() {
      _stale = stale;
      _notif = n != '0';
      _time = TimeOfDay(hour: h, minute: m);
      _off = off;
      _hasPin = pin;
      _bio = bio;
      _loaded = true;
    });
  }

  String _fmtTime(TimeOfDay t) {
    final h12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final mm = t.minute.toString().padLeft(2, '0');
    return '${bn(h12)}:${bn(mm)} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  // ---------- রিমাইন্ডার ----------
  Future<void> _toggleNotif(bool on) async {
    if (on) {
      final ok = await Reminders.instance.requestPermission();
      if (!ok) {
        if (mounted) {
          snack(context,
              'নোটিফিকেশনের অনুমতি পাওয়া যায়নি। ফোনের সেটিংস থেকে অ্যাপের নোটিফিকেশন চালু করুন।');
        }
        return;
      }
    }
    await AppDb.instance.setSetting('notif_enabled', on ? '1' : '0');
    await _load();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      confirmText: 'ঠিক আছে',
      cancelText: 'বাতিল',
    );
    if (t == null) return;
    final db = AppDb.instance;
    await db.setSetting('notif_hour', '${t.hour}');
    await db.setSetting('notif_minute', '${t.minute}');
    await _load();
  }

  Future<void> _setStale(int v) async {
    await AppDb.instance.setSetting('stale_days', '$v');
    staleDays.value = v;
    await Reminders.instance.reschedule().catchError((_) {});
    await _load();
  }

  Future<void> _setOff(int v) async {
    await AppDb.instance.setSetting('weekly_off', '$v');
    await _load();
  }

  // ---------- অ্যাপ লক ----------
  Future<void> _togglePin(bool on) async {
    if (on) {
      await setupPin(context);
    } else {
      final ok = await verifyPin(context, title: 'লক বন্ধ করতে বর্তমান পিন দিন');
      if (ok) await AppLock.instance.clearPin();
    }
    await _load();
  }

  Future<void> _changePin() async {
    final ok = await verifyPin(context);
    if (!ok || !mounted) return;
    await setupPin(context);
    await _load();
  }

  Future<void> _toggleBio(bool on) async {
    if (on) {
      final ok = await AppLock.instance.authenticateBiometric();
      if (!ok) {
        if (mounted) {
          snack(context,
              'ফিঙ্গারপ্রিন্ট চালু করা যায়নি। ফোনে ফিঙ্গারপ্রিন্ট সেট করা আছে কিনা দেখুন।');
        }
        return;
      }
    }
    await AppLock.instance.setBiometric(on);
    await _load();
  }

  // ---------- এক্সপোর্ট / ব্যাকআপ ----------
  Future<void> _exportCsv() async {
    try {
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];
      for (final e in (await AppDb.instance.csvExports()).entries) {
        final f = File(p.join(dir.path, e.key));
        await f.writeAsString(e.value);
        files.add(XFile(f.path));
      }
      await Share.shareXFiles(files, subject: 'Salesman Dairy — এক্সপোর্ট');
    } catch (e) {
      if (mounted) snack(context, 'এক্সপোর্ট হয়নি: $e');
    }
  }

  Future<void> _backup() async {
    try {
      final f = await AppDb.instance.backupFile();
      await Share.shareXFiles([XFile(f.path)],
          subject: 'Salesman Dairy — ব্যাকআপ');
    } catch (e) {
      if (mounted) snack(context, 'ব্যাকআপ হয়নি: $e');
    }
  }

  Future<void> _restore() async {
    final ok = await confirm(
        context,
        'ব্যাকআপ ফাইল থেকে ডেটা ফেরত আনলে এখনকার সব ডেটা মুছে যাবে। চালিয়ে যাবেন?',
        yes: 'চালিয়ে যান');
    if (!ok) return;
    try {
      final r = await FilePicker.platform.pickFiles();
      final path = r?.files.single.path;
      if (path == null) return;
      await AppDb.instance.restoreFrom(path);
      if (mounted) snack(context, 'ডেটা ফেরত আনা হয়েছে');
    } catch (e) {
      if (mounted) snack(context, 'ফেরত আনা যায়নি: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _header('রুট ও ছুটি'),
                ListTile(
                  leading: const Icon(Icons.store_mall_directory_outlined),
                  title: const Text('মার্কেট ও ভিজিটের দিন'),
                  subtitle: const Text('কোন বারে কোন মার্কেটে যান'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MarketsScreen())),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('সাপ্তাহিক ছুটি (টার্গেটের "দিনে কত লাগবে" হিসাবে বাদ যাবে)',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('ছুটি নেই'),
                        selected: _off == 0,
                        onSelected: (_) => _setOff(0),
                      ),
                      for (final wd in weekOrder)
                        ChoiceChip(
                          label: Text(weekdayShort[wd]),
                          selected: _off == wd,
                          onSelected: (_) => _setOff(wd),
                        ),
                    ],
                  ),
                ),
                _header('রিমাইন্ডার'),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('প্রতিদিনের রিমাইন্ডার'),
                  subtitle: const Text(
                      'আজ কোন মার্কেটে যেতে হবে ও কার কাছে টাকা চাইতে হবে'),
                  value: _notif,
                  onChanged: _toggleNotif,
                ),
                ListTile(
                  enabled: _notif,
                  leading: const Icon(Icons.schedule),
                  title: const Text('রিমাইন্ডারের সময়'),
                  trailing: Text(_fmtTime(_time),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: _notif ? _pickTime : null,
                ),
                const ListTile(
                  leading: Icon(Icons.history),
                  title: Text('দোকানে যাওয়া হচ্ছে না — জানান'),
                  subtitle: Text(
                      'এত দিন কোনো ভিজিট/এন্ট্রি না থাকলে রিমাইন্ডার ও হোমে দেখাবে'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final n in const [7, 10, 14, 0])
                        ChoiceChip(
                          label: Text(n == 0 ? 'বন্ধ' : '${bn(n)} দিন'),
                          selected: _stale == n,
                          onSelected: (_) => _setStale(n),
                        ),
                    ],
                  ),
                ),
                _header('নিরাপত্তা'),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('অ্যাপ লক (পিন)'),
                  subtitle: const Text('অ্যাপ খুলতে ৪ সংখ্যার পিন লাগবে'),
                  value: _hasPin,
                  onChanged: _togglePin,
                ),
                if (_hasPin) ...[
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text('পিন পরিবর্তন'),
                    onTap: _changePin,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('ফিঙ্গারপ্রিন্ট দিয়ে খুলুন'),
                    value: _bio,
                    onChanged: _toggleBio,
                  ),
                ],
                _header('ডেটা'),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('আমার খরচ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ExpensesScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Excel (CSV) এক্সপোর্ট'),
                  onTap: _exportCsv,
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('ব্যাকআপ নিন'),
                  subtitle: const Text(
                      'ফাইলটা Google Drive বা WhatsApp-এ নিজেকে পাঠিয়ে রাখুন'),
                  onTap: _backup,
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('ব্যাকআপ থেকে ফেরত আনুন'),
                  onTap: _restore,
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );
}
