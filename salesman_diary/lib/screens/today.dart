import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customer_detail.dart';
import 'settings.dart';

class _TodayData {
  _TodayData(this.sales, this.collected, this.spent, this.visits,
      this.collections, this.done);
  final double sales, collected, spent;
  final List<Rec> visits, collections, done;
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  Future<_TodayData> _load() async {
    final db = AppDb.instance;
    final t = today();
    final n = nextDay(t);
    final sums =
        await Future.wait([db.sales(t, n), db.collected(t, n), db.spent(t, n)]);
    return _TodayData(
      sums[0],
      sums[1],
      sums[2],
      await db.dueVisits(t),
      await db.dueCollections(t),
      await db.visitedOn(t),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('আজকের কাজ'),
            Text(niceDate(today()),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'সেটিংস',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('আজকের ভিজিটে যোগ'),
        onPressed: () async {
          final c = await pickCustomer(context);
          if (c != null) {
            await AppDb.instance.setReminder(c['id'] as int, 'next_visit', today());
          }
        },
      ),
      body: DbBuilder<_TodayData>(
        load: _load,
        builder: (context, d) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Expanded(
                      child: StatCard(
                          label: 'আজকের বিক্রি',
                          value: taka(d.sales),
                          icon: Icons.shopping_bag_outlined)),
                  Expanded(
                      child: StatCard(
                          label: 'আজকের আদায়',
                          value: taka(d.collected),
                          icon: Icons.payments_outlined)),
                  Expanded(
                      child: StatCard(
                          label: 'আজকের খরচ',
                          value: taka(d.spent),
                          icon: Icons.account_balance_wallet_outlined,
                          color: Theme.of(context).colorScheme.error)),
                ]),
              ),
              SectionTitle('ভিজিটে যেতে হবে', count: d.visits.length),
              if (d.visits.isEmpty)
                const EmptyNote('আজকের জন্য কোনো ভিজিট নেই।\n"আজকের ভিজিটে যোগ" চাপুন।'),
              for (final c in d.visits) _CustomerCard(c: c, kind: _Kind.visit),
              if (d.collections.isNotEmpty) ...[
                SectionTitle('টাকা চাইতে হবে', count: d.collections.length),
                for (final c in d.collections)
                  _CustomerCard(c: c, kind: _Kind.collect),
              ],
              if (d.done.isNotEmpty) ...[
                SectionTitle('আজ ভিজিট হয়েছে', count: d.done.length),
                for (final v in d.done)
                  ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(v['name'] as String),
                    subtitle: ((v['note'] as String?) ?? '').isEmpty
                        ? null
                        : Text(v['note'] as String),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CustomerDetail(id: v['customer_id'] as int)),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

enum _Kind { visit, collect }

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.c, required this.kind});
  final Rec c;
  final _Kind kind;

  @override
  Widget build(BuildContext context) {
    final id = c['id'] as int;
    final name = c['name'] as String;
    final shop = (c['shop'] as String?) ?? '';
    final phone = (c['phone'] as String?) ?? '';
    final due = (c['due'] as num).toDouble();
    final cs = Theme.of(context).colorScheme;

    String sub;
    if (kind == _Kind.visit) {
      final nv = c['next_visit'] as String;
      sub = nv.compareTo(today()) < 0
          ? 'ভিজিটের তারিখ ছিল ${niceDate(nv)}'
          : 'আজ ভিজিট';
    } else {
      sub = 'তাগাদার তারিখ: ${niceDate(c['pay_reminder'] as String?)}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CustomerDetail(id: id)),
            ),
            title: Text(shop.isEmpty ? name : '$name · $shop'),
            subtitle: Text(sub),
            trailing: due > 0
                ? Text('বাকি ${taka(due)}',
                    style: TextStyle(
                        color: cs.error, fontWeight: FontWeight.bold))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
            child: Row(
              children: [
                if (phone.isNotEmpty) ...[
                  IconButton(
                      tooltip: 'কল',
                      icon: const Icon(Icons.call),
                      onPressed: () => callPhone(context, phone)),
                  IconButton(
                      tooltip: 'WhatsApp',
                      icon: const Icon(Icons.chat),
                      onPressed: () => openWhatsApp(context, phone)),
                ],
                const Spacer(),
                if (kind == _Kind.visit)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.check),
                    label: const Text('ভিজিট হলো'),
                    onPressed: () => showVisitSheet(context, id, name),
                  )
                else
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('টাকা পেলাম'),
                    onPressed: () => showPaymentSheet(context, id,
                        currentReminder: c['pay_reminder'] as String?,
                        due: due),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
