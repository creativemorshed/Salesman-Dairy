import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';

class _SalesData {
  _SalesData(this.sales, this.collections);
  final List<Rec> sales, collections;
}

/// বিক্রি ও আদায়ের তালিকা (মাসভিত্তিক, তারিখ অনুযায়ী ভাগ করা)
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  DateTime _m = DateTime(DateTime.now().year, DateTime.now().month, 1);

  Future<_SalesData> _load() async {
    final db = AppDb.instance;
    final from = monthStart(_m), to = monthEnd(_m);
    return _SalesData(
      await db.entriesBetween('sales', from, to),
      await db.entriesBetween('collections', from, to),
    );
  }

  Future<void> _newEntry(String table) async {
    final o = await pickOutlet(context);
    if (o == null || !mounted) return;
    await showEntrySheet(context, o, table);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('বিক্রি ও আদায়'),
          bottom: const TabBar(tabs: [Tab(text: 'বিক্রি'), Tab(text: 'আদায়')]),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('নতুন এন্ট্রি'),
            onPressed: () => _newEntry(
                DefaultTabController.of(ctx).index == 0 ? 'sales' : 'collections'),
          ),
        ),
        body: Column(
          children: [
            MonthBar(month: _m, onChanged: (m) => setState(() => _m = m)),
            Expanded(
              child: DbBuilder<_SalesData>(
                load: _load,
                builder: (context, d) => TabBarView(
                  children: [
                    _EntryList(rows: d.sales, table: 'sales'),
                    _EntryList(rows: d.collections, table: 'collections'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.rows, required this.table});
  final List<Rec> rows;
  final String table;

  @override
  Widget build(BuildContext context) {
    final isColl = table == 'collections';
    final tt = Theme.of(context).textTheme;
    final total = rows.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());

    // দিনের মোট
    final dayTotal = <String, double>{};
    for (final r in rows) {
      final k = r['date'] as String;
      dayTotal[k] = (dayTotal[k] ?? 0) + (r['amount'] as num).toDouble();
    }

    final items = <Widget>[];
    String? last;
    for (final r in rows) {
      final date = r['date'] as String;
      if (date != last) {
        last = date;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
          child: Row(children: [
            Text(niceDate(date),
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(taka(dayTotal[date] ?? 0), style: tt.titleSmall),
          ]),
        ));
      }
      final note = (r['note'] as String?) ?? '';
      items.add(AppCard(
        margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['outlet_name'] as String,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                    [r['market_name'] as String, if (note.isNotEmpty) note]
                        .join(' · '),
                    style: tt.bodySmall),
              ],
            ),
          ),
          Text(taka(r['amount'] as num),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isColl ? Colors.green : null)),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              if (await confirm(context, 'এই এন্ট্রি মুছে ফেলবেন?',
                  yes: 'মুছুন')) {
                await AppDb.instance.deleteRow(table, r['id'] as int);
              }
            },
          ),
        ]),
      ));
    }

    return Column(
      children: [
        AppCard(
          child: Row(children: [
            Icon(isColl ? Icons.payments_outlined : Icons.sell_outlined),
            const SizedBox(width: 10),
            Text(isColl ? 'এই মাসের মোট আদায়' : 'এই মাসের মোট বিক্রি'),
            const Spacer(),
            Text(taka(total),
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyNote(isColl ? 'এই মাসে কোনো আদায় নেই' : 'এই মাসে কোনো বিক্রি নেই')
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: items),
        ),
      ],
    );
  }
}
