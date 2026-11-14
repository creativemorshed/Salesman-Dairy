import 'package:flutter/material.dart';

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
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 96),
                              itemCount: rows.length,
                              itemBuilder: (context, i) {
                                final e = rows[i];
                                final note = (e['note'] as String?) ?? '';
                                return ListTile(
                                  title: Text(e['category'] as String),
                                  subtitle: Text([
                                    niceDate(e['date'] as String),
                                    if (note.isNotEmpty) note
                                  ].join(' · ')),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(taka(e['amount'] as num),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20),
                                        onPressed: () async {
                                          if (await confirm(context,
                                              'এই খরচ মুছে ফেলবেন?',
                                              yes: 'মুছুন')) {
                                            await AppDb.instance.deleteRow(
                                                'expenses', e['id'] as int);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
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
}
