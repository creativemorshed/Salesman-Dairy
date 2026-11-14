import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';

class _Detail {
  _Detail(this.c, this.orders, this.payments, this.visits);
  final Rec? c;
  final List<Rec> orders, payments, visits;
}

class CustomerDetail extends StatelessWidget {
  const CustomerDetail({super.key, required this.id});
  final int id;

  Future<_Detail> _load() async {
    final db = AppDb.instance;
    return _Detail(
      await db.customer(id),
      await db.orders(id),
      await db.payments(id),
      await db.visits(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DbBuilder<_Detail>(
      load: _load,
      builder: (context, d) {
        final c = d.c;
        if (c == null) {
          // কাস্টমার মুছে ফেলা হয়েছে
          return const Scaffold(body: EmptyNote('কাস্টমার পাওয়া যায়নি'));
        }
        return _View(id: id, c: c, d: d);
      },
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.id, required this.c, required this.d});
  final int id;
  final Rec c;
  final _Detail d;

  String _s(String k) => (c[k] as String?) ?? '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final due = (c['due'] as num).toDouble();
    final phone = _s('phone');

    final info = [
      if (_s('shop').isNotEmpty) (Icons.storefront, _s('shop')),
      if (phone.isNotEmpty) (Icons.phone, phone),
      if (_s('address').isNotEmpty) (Icons.place_outlined, _s('address')),
      if (_s('note').isNotEmpty) (Icons.sticky_note_2_outlined, _s('note')),
    ];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_s('name')),
          actions: [
            IconButton(
              tooltip: 'এডিট',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showCustomerSheet(context, existing: c),
            ),
            IconButton(
              tooltip: 'মুছুন',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(context,
                    'এই কাস্টমার এবং তার সব অর্ডার, আদায় ও ভিজিটের তথ্য মুছে যাবে। নিশ্চিত?',
                    yes: 'মুছুন');
                if (!ok) return;
                await AppDb.instance.deleteCustomer(id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('অর্ডার'),
                  onPressed: () => showOrderSheet(context, id),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('টাকা পেলাম'),
                  onPressed: () => showPaymentSheet(context, id,
                      currentReminder: c['pay_reminder'] as String?, due: due),
                ),
              ),
            ]),
          ),
        ),
        body: Column(
          children: [
            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('মোট বাকি: ',
                          style: Theme.of(context).textTheme.bodyLarge),
                      Text(taka(due),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: due > 0 ? cs.error : Colors.green)),
                      const Spacer(),
                      if (phone.isNotEmpty) ...[
                        IconButton.filledTonal(
                            tooltip: 'কল',
                            icon: const Icon(Icons.call),
                            onPressed: () => callPhone(context, phone)),
                        IconButton.filledTonal(
                            tooltip: 'WhatsApp',
                            icon: const Icon(Icons.chat),
                            onPressed: () => openWhatsApp(context, phone)),
                      ],
                    ]),
                    for (final (icon, text) in info)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(icon, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(child: Text(text)),
                        ]),
                      ),
                    const Divider(height: 20),
                    _ReminderRow(
                      icon: Icons.directions_walk,
                      label: 'পরের ভিজিট',
                      value: c['next_visit'] as String?,
                      onTap: () => showReminderSheet(context,
                          customerId: id,
                          column: 'next_visit',
                          title: 'পরের ভিজিটের তারিখ',
                          current: c['next_visit'] as String?),
                    ),
                    _ReminderRow(
                      icon: Icons.alarm,
                      label: 'টাকা চাওয়ার তারিখ',
                      value: c['pay_reminder'] as String?,
                      onTap: () => showReminderSheet(context,
                          customerId: id,
                          column: 'pay_reminder',
                          title: 'টাকা চাওয়ার তারিখ',
                          current: c['pay_reminder'] as String?),
                    ),
                  ],
                ),
              ),
            ),
            const TabBar(tabs: [
              Tab(text: 'অর্ডার'),
              Tab(text: 'আদায়'),
              Tab(text: 'ভিজিট'),
            ]),
            Expanded(
              child: TabBarView(children: [
                _OrdersTab(rows: d.orders),
                _PaymentsTab(rows: d.payments),
                _VisitsTab(rows: d.visits),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$label: '),
          Text(value == null ? 'সেট করা নেই' : niceDate(value),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.edit_calendar_outlined, size: 18),
        ]),
      ),
    );
  }
}

Future<void> _delete(BuildContext context, String table, int id) async {
  if (await confirm(context, 'এই এন্ট্রি মুছে ফেলবেন?', yes: 'মুছুন')) {
    await AppDb.instance.deleteRow(table, id);
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.rows});
  final List<Rec> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyNote('কোনো অর্ডার নেই');
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final o = rows[i];
        final qty = (o['qty'] as num).toDouble();
        final price = (o['price'] as num).toDouble();
        return ListTile(
          title: Text(o['product'] as String),
          subtitle: Text(
              '${qtyText(qty)} × ${taka(price)} · ${niceDate(o['date'] as String)}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(taka(qty * price),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _delete(context, 'orders', o['id'] as int),
            ),
          ]),
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.rows});
  final List<Rec> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyNote('কোনো টাকা আদায় হয়নি');
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final p = rows[i];
        final note = (p['note'] as String?) ?? '';
        return ListTile(
          title: Text(niceDate(p['date'] as String)),
          subtitle: note.isEmpty ? null : Text(note),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(taka(p['amount'] as num),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _delete(context, 'payments', p['id'] as int),
            ),
          ]),
        );
      },
    );
  }
}

class _VisitsTab extends StatelessWidget {
  const _VisitsTab({required this.rows});
  final List<Rec> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyNote('কোনো ভিজিটের রেকর্ড নেই');
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final v = rows[i];
        final note = (v['note'] as String?) ?? '';
        return ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: Text(niceDate(v['date'] as String)),
          subtitle: note.isEmpty ? null : Text(note),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _delete(context, 'visits', v['id'] as int),
          ),
        );
      },
    );
  }
}
