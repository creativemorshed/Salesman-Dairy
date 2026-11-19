import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
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
  double _target = 0; // এই মাসের (বা আগের সর্বশেষ) টার্গেট
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
    final tgt = targetOf(await db.targetFor(monthKey(DateTime.now())));
    final pin = await AppLock.instance.hasPin();
    final bio = await AppLock.instance.biometricEnabled();
    if (!mounted) return;
    setState(() {
      _stale = stale;
      _target = tgt;
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
      confirmText: tr('ঠিক আছে'),
      cancelText: tr('বাতিল'),
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
      await Share.shareXFiles(files, subject: tr('Salesman Dairy — এক্সপোর্ট'));
    } catch (e) {
      if (mounted) snack(context, 'এক্সপোর্ট হয়নি: $e');
    }
  }

  Future<void> _backup() async {
    try {
      final f = await AppDb.instance.backupFile();
      await Share.shareXFiles([XFile(f.path)],
          subject: tr('Salesman Dairy — ব্যাকআপ'));
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

  Future<void> _setLang(String code) async {
    if (lang.value == code) return;
    lang.value = code;
    await AppDb.instance.setSetting('lang', code);
    // ডেটা-নির্ভর স্ক্রিনগুলো নতুন ভাষায় আবার আঁকা হবে; রিমাইন্ডারও নতুন ভাষায়
    AppDb.instance.changes.value++;
    Reminders.instance.reschedule().catchError((_) {});
  }

  static const _cardColor = Color(0xFFFFFDF8);
  static const _lineColor = Color(0xFFE6DFD0);

  /// বাঁ পাশের গোল-কোনা আইকন বক্স
  Widget _iconBox(IconData icon, {Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: c),
    );
  }

  /// একটা সেকশন: ছোট শিরোনাম + কার্ডের ভেতরে সারি
  Widget _section(String title, List<Widget> rows) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w700)),
          ),
          Material(
            color: _cardColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _lineColor),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 68, color: _lineColor),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title,
      {String? subtitle, Widget? trailing, VoidCallback? onTap, bool enabled = true}) {
    return ListTile(
      enabled: enabled,
      leading: _iconBox(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _switch(IconData icon, String title, bool value,
      ValueChanged<bool> onChanged, {String? subtitle}) {
    return SwitchListTile(
      secondary: _iconBox(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _chips(String caption, List<Widget> chips) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: chips),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _section('ভাষা', [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        _iconBox(Icons.translate),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text('অ্যাপের ভাষা',
                                style: Theme.of(context).textTheme.titleSmall)),
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 'en', label: Text('English')),
                            ButtonSegment(value: 'bn', label: Text('বাংলা')),
                          ],
                          selected: {isEn ? 'en' : 'bn'},
                          onSelectionChanged: (v) => _setLang(v.first),
                        ),
                      ],
                    ),
                  ),
                ]),
                _section('রুট ও ছুটি', [
                  _tile(Icons.alt_route, 'রুট ও ভিজিটের দিন',
                      subtitle: 'কোন বারে কোন রুটে যান',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MarketsScreen()))),
                  _chips('সাপ্তাহিক ছুটি (টার্গেটের "দিনে কত লাগবে" হিসাবে বাদ যাবে)', [
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
                  ]),
                ]),
                _section('টার্গেট', [
                  _tile(Icons.flag_outlined, 'মাসিক টার্গেট',
                      subtitle: 'বিক্রয় ও কালেকশনের টার্গেট সমান ধরা হয়',
                      trailing: Text(_target > 0 ? taka(_target) : 'সেট করা নেই',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () async {
                        await showTargetSheet(context, DateTime.now(),
                            target: _target);
                        await _load();
                      }),
                ]),
                _section('রিমাইন্ডার', [
                  _switch(Icons.notifications_active_outlined,
                      'প্রতিদিনের রিমাইন্ডার', _notif, _toggleNotif,
                      subtitle: 'আজ কোন রুটে যেতে হবে ও কার কাছে টাকা চাইতে হবে'),
                  _tile(Icons.schedule, 'রিমাইন্ডারের সময়',
                      enabled: _notif,
                      trailing: Text(_fmtTime(_time),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: _notif ? _pickTime : null),
                  _tile(Icons.history, 'দোকানে যাওয়া হচ্ছে না — জানান',
                      subtitle:
                          'এত দিন কোনো ভিজিট/এন্ট্রি না থাকলে রিমাইন্ডার ও হোমে দেখাবে'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
                ]),
                _section('নিরাপত্তা', [
                  _switch(Icons.lock_outline, 'অ্যাপ লক (পিন)', _hasPin,
                      _togglePin,
                      subtitle: 'অ্যাপ খুলতে ৪ সংখ্যার পিন লাগবে'),
                  if (_hasPin) ...[
                    _tile(Icons.password, 'পিন পরিবর্তন', onTap: _changePin),
                    _switch(Icons.fingerprint, 'ফিঙ্গারপ্রিন্ট দিয়ে খুলুন',
                        _bio, _toggleBio),
                  ],
                ]),
                _section('ডেটা', [
                  _tile(Icons.receipt_long_outlined, 'আমার খরচ',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ExpensesScreen()))),
                  _tile(Icons.table_chart_outlined, 'Excel (CSV) এক্সপোর্ট',
                      onTap: _exportCsv),
                  _tile(Icons.backup_outlined, 'ব্যাকআপ নিন',
                      subtitle:
                          'ফাইলটা Google Drive বা WhatsApp-এ নিজেকে পাঠিয়ে রাখুন',
                      onTap: _backup),
                  _tile(Icons.restore, 'ব্যাকআপ থেকে ফেরত আনুন',
                      onTap: _restore),
                ]),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.storefront, color: cs.primary, size: 26),
                      const SizedBox(height: 6),
                      Text('Salesman Dairy',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('অফলাইন অ্যাপ · ইন্টারনেট লাগে না',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text('আপনার ডেটা শুধু এই ফোনেই থাকে',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
