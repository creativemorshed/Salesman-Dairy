import 'package:flutter/material.dart';

import '../db.dart';
import '../utils.dart';
import '../widgets.dart';
import 'expenses.dart';
import 'outlet_detail.dart';
import 'settings.dart';

class _Prog {
  _Prog({
    required this.sales,
    required this.collected,
    required this.spent,
    required this.commission,
    required this.special,
    required this.target,
    required this.daysLeft,
    required this.markets,
    required this.top,
    required this.daily,
    required this.dailyColl,
  });
  final double sales, collected, spent, commission, special, target;
  final int daysLeft;
  final List<Rec> markets, top;
  final Map<int, double> daily; // মাসের দিন → বিক্রি
  final Map<int, double> dailyColl; // মাসের দিন → আদায়
}

/// এক নজরে: টার্গেট বনাম অর্জন, দিনভিত্তিক বিক্রি, রুট অনুযায়ী হিসাব, বেশি বাকি
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  DateTime _m = DateTime(DateTime.now().year, DateTime.now().month, 1);

  Future<_Prog> _load() async {
    final db = AppDb.instance;
    final from = monthStart(_m), to = monthEnd(_m);
    final off = int.tryParse(await db.getSetting('weekly_off') ?? '') ?? 5;
    final t = await db.targetFor(monthKey(_m));

    final saleRows = await db.entriesBetween('sales', from, to);
    final daily = <int, double>{};
    for (final r in saleRows) {
      final day = parseYmd(r['date'] as String).day;
      daily[day] = (daily[day] ?? 0) + (r['amount'] as num).toDouble();
    }

    final collRows = await db.entriesBetween('collections', from, to);
    final dailyColl = <int, double>{};
    for (final r in collRows) {
      final day = parseYmd(r['date'] as String).day;
      dailyColl[day] = (dailyColl[day] ?? 0) + (r['amount'] as num).toDouble();
    }

    final now = DateTime.now();
    final cur = DateTime(now.year, now.month, 1);
    final daysLeft = _m.isBefore(cur)
        ? 0
        : (_m.isAfter(cur) ? remainingWorkDays(off, _m) : remainingWorkDays(off));

    return _Prog(
      sales: await db.sales(from, to),
      collected: await db.collected(from, to),
      spent: await db.spent(from, to),
      commission: await db.commission(from, to),
      special: await db.specialCommission(from, to),
      // বিক্রয় ও আদায়ের টার্গেট সবসময় সমান — একটাই সংখ্যা
      target: (t?['sales'] as num?)?.toDouble() ?? 0,
      daysLeft: daysLeft,
      markets: await db.marketStats(from, to),
      top: await db.topDue(10),
      daily: daily,
      dailyColl: dailyColl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('এক নজরে')),
      body: DbBuilder<_Prog>(
        load: _load,
        builder: (context, d) {
          final daysInMonth = DateTime(_m.year, _m.month + 1, 0).day;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              MonthBar(month: _m, onChanged: (m) => setState(() => _m = m)),

              // ---- টার্গেট কার্ড (হোমের মতো বড় সংখ্যা + একটা বার) ----
              AppCard(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: d.target <= 0
                    ? Column(children: [
                        Text('এই মাসের টার্গেট সেট করা নেই',
                            style: tt.titleMedium),
                        const SizedBox(height: 4),
                        Text('টার্গেট সেটিংসে ঠিক করা যায়',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('সেটিংসে যান'),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen())),
                        ),
                      ])
                    : _TargetBlock(d: d),
              ),

              // ---- তিনটি সংখ্যা: কমিশন · স্পেশাল কমিশন · মোট খরচ ----
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Expanded(
                      child: StatCard(
                          label: 'কমিশন',
                          value: taka(d.commission),
                          icon: Icons.percent)),
                  Expanded(
                      child: StatCard(
                          label: 'স্পেশাল কমিশন',
                          value: taka(d.special),
                          icon: Icons.stars_outlined)),
                  Expanded(
                      child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExpensesScreen())),
                    child: StatCard(
                        label: 'মোট খরচ',
                        value: taka(d.spent),
                        icon: Icons.account_balance_wallet_outlined),
                  )),
                ]),
              ),

              // ---- বিক্রয় vs কালেকশন (প্রতিদিন পাশাপাশি দুটি ক্যান্ডল) ----
              AppCard(
                child: _DailyPairs(
                  key: ValueKey(monthKey(_m)),
                  sales: d.daily,
                  coll: d.dailyColl,
                  month: _m,
                  days: daysInMonth,
                ),
              ),

              // ---- রুট অনুযায়ী ----
              const SectionTitle('রুট অনুযায়ী হিসাব'),
              if (d.markets.isEmpty) const EmptyNote('এখনো কোনো রুট নেই'),
              for (final m in d.markets)
                AppCard(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(m['name'] as String,
                              style: tt.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Text('বাকি ${taka(m['due'] as num)}',
                            style: TextStyle(
                                color: cs.error, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          'বিক্রি ${taka(m['sales'] as num)} · আদায় ${taka(m['collected'] as num)}',
                          style: tt.bodySmall),
                    ],
                  ),
                ),

              // ---- সবচেয়ে বেশি বাকি ----
              const SectionTitle('সবচেয়ে বেশি বাকি'),
              if (d.top.isEmpty) const EmptyNote('কারো কাছে কোনো বাকি নেই 🎉'),
              for (final o in d.top)
                AppCard(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OutletDetail(id: o['id'] as int)),
                  ),
                  child: Row(children: [
                    GradeBadge(o['grade'] as String, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o['name'] as String,
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(o['market_name'] as String, style: tt.bodySmall),
                        ],
                      ),
                    ),
                    Text(taka(o['due'] as num),
                        style: TextStyle(
                            color: cs.error, fontWeight: FontWeight.w700)),
                  ]),
                ),

              // ---- খরচ ----
              AppCard(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExpensesScreen())),
                child: Row(children: [
                  const Icon(Icons.receipt_long_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('আমার খরচ (যাবতীয় খরচসমূহ...)',
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// বিক্রয় vs কালেকশন: প্রতিদিনের জন্য পাশাপাশি দুটি আলাদা ক্যান্ডল।
/// পাশে স্ক্রল করা যায়; কোনো দিনে চাপলে ওই দিনের হিসাব ওপরে দেখায়।
class _DailyPairs extends StatefulWidget {
  const _DailyPairs(
      {super.key,
      required this.sales,
      required this.coll,
      required this.month,
      required this.days});
  final Map<int, double> sales, coll;
  final DateTime month;
  final int days;

  @override
  State<_DailyPairs> createState() => _DailyPairsState();
}

class _DailyPairsState extends State<_DailyPairs> {
  static const _slot = 26.0;
  static const _salesColor = Color(0xFFD9480F);
  static const _collColor = Color(0xFF138A9B);
  late final ScrollController _sc;
  int? _sel;

  int? get _todayDay {
    final n = DateTime.now();
    return (n.year == widget.month.year && n.month == widget.month.month)
        ? n.day
        : null;
  }

  @override
  void initState() {
    super.initState();
    // চলতি মাসে আজকের দিনটা যেন দেখা যায়
    final t = _todayDay ?? 1;
    _sc = ScrollController(
        initialScrollOffset: ((t - 6) * _slot).clamp(0.0, double.infinity));
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    var maxV = 0.0;
    for (final v in [...widget.sales.values, ...widget.coll.values]) {
      if (v > maxV) maxV = v;
    }

    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(t, style: tt.bodySmall),
        ]);

    final sel = _sel;
    final info = sel == null
        ? 'কোনো দিনে চাপলে ওই দিনের হিসাব দেখুন'
        : '${bn(sel)} ${monthTitle(widget.month).split(' ').first} — '
            'বিক্রয় ${taka(widget.sales[sel] ?? 0)} · কালেকশন ${taka(widget.coll[sel] ?? 0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('বিক্রয় vs কালেকশন',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
          dot(_salesColor, 'বিক্রয়'),
          const SizedBox(width: 12),
          dot(_collColor, 'কালেকশন'),
        ]),
        const SizedBox(height: 8),
        Text(info,
            style: tt.bodySmall?.copyWith(
                fontWeight: sel == null ? FontWeight.w400 : FontWeight.w700)),
        const SizedBox(height: 10),
        if (maxV == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('এই মাসে এখনো কোনো বিক্রয় বা কালেকশন নেই')),
          )
        else
          SizedBox(
            height: 132,
            child: SingleChildScrollView(
              controller: _sc,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var day = 1; day <= widget.days; day++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _sel = day),
                      child: Container(
                        width: _slot,
                        decoration: BoxDecoration(
                          color: _sel == day
                              ? cs.primaryContainer.withValues(alpha: 0.5)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _bar(widget.sales[day] ?? 0, maxV, _salesColor),
                                const SizedBox(width: 2),
                                _bar(widget.coll[day] ?? 0, maxV, _collColor),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(bn(day),
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    fontWeight: day == _todayDay
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: day == _todayDay
                                        ? cs.primary
                                        : cs.onSurfaceVariant)),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _bar(double v, double maxV, Color c) => Container(
        width: 8,
        height: v > 0 ? 3 + 92 * (v / maxV) : 2,
        decoration: BoxDecoration(
          color: v > 0 ? c : c.withValues(alpha: 0.25),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      );
}

/// টার্গেট: বড় সংখ্যা → একটা বারে দুই রঙ (বিক্রয় / আদায়) → বাকি → সময় ও দৈনিক লাগবে
class _TargetBlock extends StatelessWidget {
  const _TargetBlock({required this.d});
  final _Prog d;

  static const salesColor = Color(0xFFD9480F);
  static const collColor = Color(0xFF138A9B);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final salesLeft = (d.target - d.sales).clamp(0, double.infinity).toDouble();
    final collLeft =
        (d.target - d.collected).clamp(0, double.infinity).toDouble();

    final timeLine =
        d.daysLeft <= 0 ? 'মাস শেষ' : 'অবশিষ্ট সময় আছে ${bn(d.daysLeft)} দিন';

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('টার্গেটঃ ${taka(d.target)}',
              style: tt.headlineSmall
                  ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        _OverlayBar(
            sales: d.sales / d.target,
            collected: d.collected / d.target,
            salesColor: salesColor,
            collColor: collColor,
            track: cs.surfaceContainerHighest),
        const SizedBox(height: 10),
        // এক লাইনে (ছোট স্ক্রিনে লেখা নিজে ছোট হয়ে আঁটে)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(style: tt.bodyMedium, children: [
              const TextSpan(text: '● ', style: TextStyle(color: salesColor)),
              TextSpan(text: 'বিক্রয় বাকি ${taka(salesLeft)}'),
              const TextSpan(text: '  |  '),
              const TextSpan(text: '● ', style: TextStyle(color: collColor)),
              TextSpan(text: 'কালেকশন বাকি ${taka(collLeft)}'),
            ]),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(timeLine,
            textAlign: TextAlign.center,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// একটাই গোল বার, ওপর-নিচ ওভারলে: বড় অংশটা নিচে, ছোটটা তার ওপরে — দুটোই দেখা যায়
class _OverlayBar extends StatelessWidget {
  const _OverlayBar(
      {required this.sales,
      required this.collected,
      required this.salesColor,
      required this.collColor,
      required this.track});
  final double sales, collected;
  final Color salesColor, collColor, track;

  @override
  Widget build(BuildContext context) {
    final s = sales.clamp(0.0, 1.0), c = collected.clamp(0.0, 1.0);
    final salesFirst = s >= c; // বড়টা আগে আঁকি
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: LayoutBuilder(
        builder: (context, box) {
          Widget fill(double f, Color col) =>
              Container(height: 18, width: box.maxWidth * f, color: col);
          return Stack(children: [
            Container(height: 18, color: track),
            fill(salesFirst ? s : c, salesFirst ? salesColor : collColor),
            fill(salesFirst ? c : s, salesFirst ? collColor : salesColor),
          ]);
        },
      ),
    );
  }
}
