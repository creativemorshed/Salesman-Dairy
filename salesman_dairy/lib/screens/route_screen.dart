import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';

import '../db.dart';
import '../sheets.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';
import 'outlet_detail.dart';

class _RouteData {
  _RouteData(this.market, this.route, this.extras, this.todaySales,
      this.todayColl);
  final Rec? market;
  final List<Rec> route; // রুটের আউটলেট
  final List<Rec> extras; // অন্য রুটের যাদের টাকা দেওয়ার তারিখ হয়ে গেছে
  final double todaySales, todayColl;
}

/// আজকের রুট: রুটের সব আউটলেট (বাকি আগে), ভিজিট এন্ট্রি
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  int _filter = 0; // 0 সব, 1 বাকি, 2 সম্পন্ন
  final _marketName = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _marketName.dispose();
    super.dispose();
  }

  Future<_RouteData> _load() async {
    final db = AppDb.instance;
    final t = today(), n = nextDay(t);
    final market = await db.activeMarket(selectedMarket.value);
    _marketName.value = market?['name'] as String?;
    final route =
        market == null ? <Rec>[] : await db.route(market['id'] as int);
    final promises = await db.promises(t);
    final extras = promises
        .where((p) => market == null || p['market_id'] != market['id'])
        .toList();
    return _RouteData(market, route, extras, await db.sales(t, n),
        await db.collected(t, n));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('আজকের রুটের বিস্তারিতঃ-',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          ValueListenableBuilder<String?>(
            valueListenable: _marketName,
            builder: (context, name, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.42),
                child: MarketChip(
                    name: name,
                    onTap: () => showMarketPicker(context)),
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<int?>(
        valueListenable: selectedMarket,
        builder: (context, _, __) => DbBuilder<_RouteData>(
          load: _load,
          builder: (context, d) => _body(context, d),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, _RouteData d) {
    final market = d.market;
    if (market == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyNote('এখনো কোনো রুট নেই।\nপ্রথমে রুট যোগ করুন।'),
            FilledButton(
                onPressed: () => showMarketSheet(context),
                child: const Text('রুট যোগ করুন')),
          ],
        ),
      );
    }

    final pending = d.route.where((r) => r['visited_today'] != 1).toList();
    final done = d.route.where((r) => r['visited_today'] == 1).toList();
    final shown =
        _filter == 1 ? pending : (_filter == 2 ? done : d.route);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppCard(
          child: Row(
            children: [
              _mini(context, 'ভিজিট', '${bn(done.length)}/${bn(d.route.length)}'),
              _mini(context, 'বিক্রয়', taka(d.todaySales)),
              _mini(context, 'কালেকশন', taka(d.todayColl)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final (i, label, n) in [
                (0, 'সব', d.route.length),
                (1, 'বাকি', pending.length),
                (2, 'সম্পন্ন', done.length),
              ])
                ChoiceChip(
                  label: Text('$label (${bn(n)})'),
                  selected: _filter == i,
                  onSelected: (_) => setState(() => _filter = i),
                ),
            ],
          ),
        ),
        if (d.route.isEmpty)
          const EmptyNote('এই রুটে কোনো আউটলেট নেই।\n"আউটলেট" ট্যাব থেকে যোগ করুন।')
        else if (shown.isEmpty)
          const EmptyNote('এই তালিকায় কিছু নেই'),
        for (final r in shown) _OutletCard(r: r),
        if (d.extras.isNotEmpty) ...[
          SectionTitle('অন্য রুটে টাকা চাওয়ার কথা', count: d.extras.length),
          for (final r in d.extras) _OutletCard(r: r, showMarket: true),
        ],
      ],
    );
  }

  Widget _mini(BuildContext context, String label, String value) {
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Text(label, style: tt.bodySmall),
        ],
      ),
    );
  }
}

class _OutletCard extends StatelessWidget {
  const _OutletCard({required this.r, this.showMarket = false});
  final Rec r;
  final bool showMarket;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final due = (r['due'] as num).toDouble();
    final phone = (r['phone'] as String?) ?? '';
    final visited = r['visited_today'] == 1;
    final reminder = r['pay_reminder'] as String?;
    final promiseDue =
        reminder != null && reminder.compareTo(today()) <= 0 && due > 0;
    final owner = (r['owner'] as String?) ?? '';
    final sub = [
      if (showMarket) r['market_name'] as String,
      if (owner.isNotEmpty) owner,
      agoText(r['last_visit'] as String?),
    ].join(' · ');

    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OutletDetail(id: r['id'] as int)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradeBadge(r['grade'] as String),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['name'] as String,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(sub, style: tt.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(taka(due),
                      style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: due > 0 ? cs.error : Colors.green)),
                  Text('বাকি', style: tt.bodySmall),
                ],
              ),
            ],
          ),
          if (promiseDue)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.alarm, size: 16, color: cs.primary),
                const SizedBox(width: 4),
                Text('টাকা দেওয়ার তারিখ: ${niceDate(reminder)}',
                    style: tt.bodySmall?.copyWith(color: cs.primary)),
              ]),
            ),
          if (idleWarning(r) != null && !visited)
            InfoLine(Icons.history, idleWarning(r)!,
                color: const Color(0xFFB45309)),
          if (((r['next_note'] as String?) ?? '').trim().isNotEmpty)
            InfoLine(Icons.sticky_note_2_outlined,
                'নোট: ${(r['next_note'] as String).trim()}',
                color: cs.tertiary),
          Row(
            children: [
              if (phone.isNotEmpty) ...[
                IconButton(
                    tooltip: tr('কল'),
                    icon: const Icon(Icons.call),
                    onPressed: () => callPhone(context, phone)),
                IconButton(
                    tooltip: 'WhatsApp',
                    icon: const Icon(Icons.chat),
                    onPressed: () => openWhatsApp(context, phone)),
              ],
              const Spacer(),
              if (visited)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 22),
                ),
              OutlinedButton(
                onPressed: () => showVisitSheet(context, r),
                child: const Text('এন্ট্রি', softWrap: false),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => quickVisit(context, r),
                child: const Text('ভিজিট', softWrap: false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
