import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customer_detail.dart';

class _ReportData {
  _ReportData(this.sales, this.collected, this.spent, this.totalDue,
      this.target, this.top);
  final double sales, collected, spent, totalDue, target;
  final List<Rec> top;
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _m = DateTime(DateTime.now().year, DateTime.now().month, 1);

  Future<_ReportData> _load() async {
    final db = AppDb.instance;
    final from = monthStart(_m), to = monthEnd(_m);
    final r = await Future.wait([
      db.sales(from, to),
      db.collected(from, to),
      db.spent(from, to),
      db.totalDue(),
    ]);
    final target = parseNum(await db.getSetting('target') ?? '0');
    return _ReportData(r[0], r[1], r[2], r[3], target, await db.topDue(10));
  }

  Future<void> _setTarget(double current) async {
    final c = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(0) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('মাসিক বিক্রির টার্গেট'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'টাকা'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('সংরক্ষণ')),
        ],
      ),
    );
    final text = c.text;
    c.dispose();
    if (ok == true) {
      await AppDb.instance.setSetting('target', parseNum(text).toString());
    }
  }

  Future<void> _exportCsv() async {
    try {
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];
      for (final e in (await AppDb.instance.csvExports()).entries) {
        final f = File(p.join(dir.path, e.key));
        await f.writeAsString(e.value);
        files.add(XFile(f.path));
      }
      await Share.shareXFiles(files, subject: 'সেলসম্যান ডায়েরি — এক্সপোর্ট');
    } catch (e) {
      if (mounted) snack(context, 'এক্সপোর্ট হয়নি: $e');
    }
  }

  Future<void> _backup() async {
    try {
      final f = await AppDb.instance.backupFile();
      await Share.shareXFiles([XFile(f.path)],
          subject: 'সেলসম্যান ডায়েরি — ব্যাকআপ');
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('রিপোর্ট')),
      body: DbBuilder<_ReportData>(
        load: _load,
        builder: (context, d) {
          final pct = d.target > 0 ? d.sales / d.target : 0.0;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              MonthBar(month: _m, onChanged: (m) => setState(() => _m = m)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Expanded(
                      child: StatCard(
                          label: 'মোট বিক্রি',
                          value: taka(d.sales),
                          icon: Icons.shopping_bag_outlined)),
                  Expanded(
                      child: StatCard(
                          label: 'মোট আদায়',
                          value: taka(d.collected),
                          icon: Icons.payments_outlined)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Expanded(
                      child: StatCard(
                          label: 'মোট খরচ',
                          value: taka(d.spent),
                          icon: Icons.account_balance_wallet_outlined,
                          color: cs.error)),
                  Expanded(
                      child: StatCard(
                          label: 'নিট (আদায় − খরচ)',
                          value: taka(d.collected - d.spent),
                          icon: Icons.savings_outlined)),
                ]),
              ),
              Card(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: cs.error),
                  title: const Text('সব কাস্টমারের মোট বাকি'),
                  trailing: Text(taka(d.totalDue),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                              fontWeight: FontWeight.bold, color: cs.error)),
                ),
              ),
              Card(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('বিক্রির টার্গেট',
                            style: Theme.of(context).textTheme.titleSmall),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _setTarget(d.target),
                          child: Text(d.target > 0 ? 'পরিবর্তন' : 'সেট করুন'),
                        ),
                      ]),
                      if (d.target > 0) ...[
                        LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0).toDouble(),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(6)),
                        const SizedBox(height: 8),
                        Text(
                            '${taka(d.sales)} / ${taka(d.target)}  (${bn((pct * 100).toStringAsFixed(0))}%)'),
                      ] else
                        const Text('মাসিক টার্গেট সেট করলে এখানে অগ্রগতি দেখা যাবে।'),
                    ],
                  ),
                ),
              ),
              SectionTitle('সবচেয়ে বেশি বাকি'),
              if (d.top.isEmpty) const EmptyNote('কারো কাছে কোনো বাকি নেই 🎉'),
              for (final c in d.top)
                ListTile(
                  title: Text(c['name'] as String),
                  subtitle: ((c['shop'] as String?) ?? '').isEmpty
                      ? null
                      : Text(c['shop'] as String),
                  trailing: Text(taka(c['due'] as num),
                      style: TextStyle(
                          color: cs.error, fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CustomerDetail(id: c['id'] as int)),
                  ),
                ),
              const SectionTitle('ডেটা ব্যাকআপ'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Excel (CSV) এক্সপোর্ট'),
                        onPressed: _exportCsv),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('ব্যাকআপ নিন'),
                        onPressed: _backup),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.restore),
                        label: const Text('ব্যাকআপ থেকে ফেরত'),
                        onPressed: _restore),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'টিপস: ব্যাকআপ নিয়ে Google Drive বা WhatsApp-এ নিজেকে পাঠিয়ে রাখুন, ফোন হারালেও ডেটা থাকবে।',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
