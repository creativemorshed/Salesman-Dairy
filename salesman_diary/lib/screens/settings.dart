import 'package:flutter/material.dart';

import '../db.dart';
import '../lock.dart';
import '../notifications.dart';
import '../utils.dart';
import 'products.dart';

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
    final pin = await AppLock.instance.hasPin();
    final bio = await AppLock.instance.biometricEnabled();
    if (!mounted) return;
    setState(() {
      _notif = n != '0';
      _time = TimeOfDay(hour: h, minute: m);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _header('রিমাইন্ডার'),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('প্রতিদিনের রিমাইন্ডার'),
                  subtitle:
                      const Text('আজ কার কাছে যেতে হবে ও কার কাছে টাকা চাইতে হবে'),
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
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('প্রোডাক্ট ও দাম'),
                  subtitle: const Text('অর্ডার দেওয়ার সময় নাম ও দাম সাজেস্ট করবে'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductsScreen()),
                  ),
                ),
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
