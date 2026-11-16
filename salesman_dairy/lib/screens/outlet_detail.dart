import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';

class _Detail {
  _Detail(this.o, this.sales, this.collections, this.visits);
  final Rec? o;
  final List<Rec> sales, collections, visits;
}

class OutletDetail extends StatelessWidget {
  const OutletDetail({super.key, required this.id});
  final int id;

  Future<_Detail> _load() async {
    final db = AppDb.instance;
    return _Detail(
      await db.outlet(id),
      await db.entries('sales', id),
      await db.entries('collections', id),
      await db.visits(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DbBuilder<_Detail>(
      load: _load,
      builder: (context, d) {
        final o = d.o;
        if (o == null) {
          // আউটলেট মুছে ফেলা হয়েছে
          return const Scaffold(body: EmptyNote('আউটলেট পাওয়া যায়নি'));
        }
        return _View(id: id, o: o, d: d);
      },
    );
  }
}

double _sum(List<Rec> rows) =>
    rows.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());

class _View extends StatelessWidget {
  const _View({required this.id, required this.o, required this.d});
  final int id;
  final Rec o;
  final _Detail d;

  String _s(String k) => (o[k] as String?) ?? '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final due = (o['due'] as num).toDouble();
    final opening = (o['opening_due'] as num).toDouble();
    final phone = _s('phone');
    final reminder = o['pay_reminder'] as String?;

    final info = <(IconData, String)>[
      if (_s('owner').isNotEmpty) (Icons.person_outline, _s('owner')),
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
              onPressed: () => showOutletSheet(context, existing: o),
            ),
            IconButton(
              tooltip: 'মুছুন',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(context,
                    'এই আউটলেট এবং এর সব বিক্রি, আদায় ও ভিজিটের তথ্য মুছে যাবে। নিশ্চিত?',
                    yes: 'মুছুন');
                if (!ok) return;
                await AppDb.instance.deleteOutlet(id);
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
                  icon: const Icon(Icons.edit_note),
                  label: const Text('এন্ট্রি', softWrap: false),
                  onPressed: () => showVisitSheet(context, o),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('ভিজিট', softWrap: false),
                  onPressed: () => showQuickVisitSheet(context, o),
                ),
              ),
            ]),
          ),
        ),
        body: Column(
          children: [
            AppCard(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    GradeBadge(_s('grade'), size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('মার্কেট: ${_s('market_name')}',
                          style: tt.titleSmall),
                    ),
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
                  if (_s('next_note').trim().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.notifications_active_outlined,
                            size: 18, color: cs.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('পরের ভিজিটে মনে রাখুন: ${_s('next_note').trim()}',
                              style: TextStyle(color: cs.onTertiaryContainer)),
                        ),
                      ]),
                    ),
                  if (idleWarning(o) != null)
                    InfoLine(Icons.history, idleWarning(o)!,
                        color: const Color(0xFFB45309)),
                  for (final (icon, text) in info)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        Icon(icon, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(child: Text(text)),
                      ]),
                    ),
                  const Divider(height: 22),
                  Row(children: [
                    _num(context, 'আগের বাকি', taka(opening)),
                    _num(context, 'মোট বিক্রি', taka(_sum(d.sales))),
                    _num(context, 'মোট আদায়', taka(_sum(d.collections))),
                    _num(context, 'বর্তমান বাকি', taka(due),
                        color: due > 0 ? cs.error : Colors.green),
                  ]),
                  const Divider(height: 22),
                  InkWell(
                    onTap: () => showReminderSheet(context, id, reminder),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Icon(Icons.alarm, size: 18),
                        const SizedBox(width: 8),
                        const Text('টাকা চাওয়ার তারিখ: '),
                        Text(reminder == null ? 'সেট করা নেই' : niceDate(reminder),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        const Icon(Icons.edit_calendar_outlined, size: 18),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const TabBar(tabs: [
              Tab(text: 'বিক্রি'),
              Tab(text: 'আদায়'),
              Tab(text: 'ভিজিট'),
            ]),
            Expanded(
              child: TabBarView(children: [
                _EntriesTab(rows: d.sales, table: 'sales'),
                _EntriesTab(rows: d.collections, table: 'collections'),
                _VisitsTab(rows: d.visits),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _num(BuildContext context, String label, String value, {Color? color}) {
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: tt.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ),
        Text(label, style: tt.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}

Future<void> _delete(BuildContext context, String table, int id) async {
  if (await confirm(context, 'এই এন্ট্রি মুছে ফেলবেন?', yes: 'মুছুন')) {
    await AppDb.instance.deleteRow(table, id);
  }
}

class _EntriesTab extends StatelessWidget {
  const _EntriesTab({required this.rows, required this.table});
  final List<Rec> rows;
  final String table;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return EmptyNote(table == 'sales' ? 'কোনো বিক্রি নেই' : 'কোনো আদায় নেই');
    }
    final isColl = table == 'collections';
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        final note = (r['note'] as String?) ?? '';
        return ListTile(
          title: Text(taka(r['amount'] as num),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isColl ? Colors.green : null)),
          subtitle: Text(
              [niceDate(r['date'] as String), if (note.isNotEmpty) note]
                  .join(' · ')),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _delete(context, table, r['id'] as int),
          ),
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
