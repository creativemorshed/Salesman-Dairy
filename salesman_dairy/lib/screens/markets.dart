import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';

/// মার্কেটের তালিকা: নাম, কোন কোন বারে ভিজিট, আউটলেট সংখ্যা, মার্কেট বাকি
class MarketsScreen extends StatelessWidget {
  const MarketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('মার্কেট ও ভিজিটের দিন')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('নতুন মার্কেট'),
        onPressed: () => showMarketSheet(context),
      ),
      body: DbBuilder<List<Rec>>(
        load: () => AppDb.instance.markets(),
        builder: (context, rows) {
          if (rows.isEmpty) {
            return const EmptyNote(
                'এখনো কোনো মার্কেট নেই।\nমার্কেট যোগ করে কোন কোন বারে যান তা ঠিক করুন,\nতাহলে হোম ও রুটে নিজে থেকেই আজকের মার্কেট আসবে।');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final m = rows[i];
              final due = (m['due'] as num).toDouble();
              return AppCard(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                onTap: () => showMarketSheet(context, existing: m),
                child: Row(children: [
                  const Icon(Icons.store_mall_directory_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['name'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                            '${daysText(m['days'] as String)} · ${bn(m['outlet_count'] as num)}টি আউটলেট',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(taka(due),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: due > 0
                                  ? Theme.of(context).colorScheme.error
                                  : Colors.green)),
                      Text('বাকি', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
