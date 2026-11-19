import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  DateTime _m = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('আমার খরচ')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('খরচ যোগ'),
        onPressed: () => showExpenseSheet(context),
      ),
      body: Column(
        children: [
          MonthBar(month: _m, onChanged: (m) => setState(() => _m = m)),
          Expanded(
            child: DbBuilder<List<Rec>>(
              load: () =>
                  AppDb.instance.expenses(monthStart(_m), monthEnd(_m)),
              builder: (context, rows) {
                final total = rows.fold<double>(
                    0, (s, r) => s + (r['amount'] as num).toDouble());
                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: ListTile(
                        title: const Text('এই মাসের মোট খরচ'),
                        trailing: Text(taka(total),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? const EmptyNote('এই মাসে কোনো খরচ নেই')
                          : _byDay(context, rows),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// প্রতিদিনের খরচ আলাদা কার্ডে: তারিখ হেডিং, খরচের বিস্তারিত, দিনের মোট
  Widget _byDay(BuildContext context, List<Rec> rows) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final days = <String, List<Rec>>{};
    for (final r in rows) {
      days.putIfAbsent(r['date'] as String, () => []).add(r);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96, top: 4),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final date = keys[i];
        final list = days[date]!;
        final sum = list.fold<double>(
            0, (s, r) => s + (r['amount'] as num).toDouble());
        return AppCard(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                    '${niceDate(date)} · ${weekdayShort[parseYmd(date).weekday]}',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              for (final e in list)
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['category'] as String, style: tt.bodyLarge),
                        if (((e['note'] as String?) ?? '').trim().isNotEmpty)
                          Text((e['note'] as String).trim(),
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(taka(e['amount'] as num), style: tt.titleSmall),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      if (await confirm(context, 'এই খরচ মুছে ফেলবেন?',
                          yes: 'মুছুন')) {
                        await AppDb.instance.deleteRow('expenses', e['id'] as int);
                      }
                    },
                  ),
                ]),
              const Divider(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Row(children: [
                  Text('মোট খরচ',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(taka(sum),
                      style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700, color: cs.error)),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
