import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';
import 'outlet_detail.dart';

class _OutletsData {
  _OutletsData(this.markets, this.rows);
  final List<Rec> markets;
  final List<Rec> rows;
}

class OutletsScreen extends StatefulWidget {
  const OutletsScreen({super.key});

  @override
  State<OutletsScreen> createState() => _OutletsScreenState();
}

class _OutletsScreenState extends State<OutletsScreen> {
  String _q = '';
  int? _marketId; // null = সব রুট

  Future<_OutletsData> _load() async {
    final db = AppDb.instance;
    final markets = await db.markets();
    // মোছা রুটের ফিল্টার আটকে থাকলে সরিয়ে দাও
    if (_marketId != null && !markets.any((m) => m['id'] == _marketId)) {
      _marketId = null;
    }
    return _OutletsData(markets, await db.outlets(marketId: _marketId, q: _q));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('নতুন আউটলেট'),
        onPressed: () => showOutletSheet(context, marketId: _marketId),
      ),
      body: DbBuilder<_OutletsData>(
        load: _load,
        builder: (context, d) {
          final total =
              d.rows.fold<double>(0, (s, r) => s + (r['due'] as num).toDouble());
          return SafeArea(
            bottom: false,
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'নাম, মালিক বা ফোন দিয়ে খুঁজুন',
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFFFFFDF8),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: const Text('সব'),
                        selected: _marketId == null,
                        onSelected: (_) => setState(() => _marketId = null),
                      ),
                    ),
                    for (final m in d.markets)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(m['name'] as String),
                          selected: _marketId == m['id'],
                          onSelected: (_) =>
                              setState(() => _marketId = m['id'] as int),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Row(children: [
                  Text('${bn(d.rows.length)}টি আউটলেট',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text('মোট বাকি: ${taka(total)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.error, fontWeight: FontWeight.bold)),
                ]),
              ),
              Expanded(
                child: d.rows.isEmpty
                    ? EmptyNote(d.markets.isEmpty
                        ? 'আগে সেটিংসে গিয়ে রুট যোগ করুন,\nতারপর আউটলেট যোগ করুন।'
                        : (_q.isEmpty
                            ? 'এখনো কোনো আউটলেট নেই।\nনিচের বাটন চেপে যোগ করুন।'
                            : 'কোনো আউটলেট পাওয়া যায়নি'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: d.rows.length,
                        itemBuilder: (context, i) {
                          final o = d.rows[i];
                          final due = (o['due'] as num).toDouble();
                          final owner = (o['owner'] as String?) ?? '';
                          final bazar = ((o['address'] as String?) ?? '').trim();
                          final sub = [
                            if (bazar.isNotEmpty) bazar,
                            if (owner.isNotEmpty) owner,
                          ].join(' · ');
                          return AppCard(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      OutletDetail(id: o['id'] as int)),
                            ),
                            child: Row(children: [
                              GradeBadge(o['grade'] as String),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o['name'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                    Text(sub,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    if (idleWarning(o) != null)
                                      InfoLine(Icons.history, idleWarning(o)!,
                                          color: const Color(0xFFB45309)),
                                    if (((o['next_note'] as String?) ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      InfoLine(
                                          Icons.sticky_note_2_outlined,
                                          'নোট: ${(o['next_note'] as String).trim()}',
                                          color: cs.tertiary),
                                  ],
                                ),
                              ),
                              Text(taka(due),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: due > 0 ? cs.error : Colors.green)),
                            ]),
                          );
                        },
                      ),
              ),
            ],
          ));
        },
      ),
    );
  }
}
