import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
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
  });
  final double sales, collected, spent, commission, special, target;
  final int daysLeft;
  final List<Rec> markets, top;
  final Map<int, double> daily; // মাসের দিন → বিক্রি
}

/// এক নজরে: টার্গেট বনাম অর্জন, দিনভিত্তিক বিক্রি, মার্কেট অনুযায়ী হিসাব, বেশি বাকি
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

              // ---- দিনভিত্তিক বিক্রি ----
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('দিনভিত্তিক বিক্রি',
                        style:
                            tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    _DailyBars(data: d.daily, days: daysInMonth),
                  ],
                ),
              ),

              // ---- মার্কেট অনুযায়ী ----
              const SectionTitle('মার্কেট অনুযায়ী হিসাব'),
              if (d.markets.isEmpty) const EmptyNote('এখনো কোনো মার্কেট নেই'),
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
                child: const Row(children: [
                  Icon(Icons.receipt_long_outlined),
                  SizedBox(width: 12),
                  Expanded(child: Text('আমার খরচ (যাতায়াত, খাবার, মোবাইল বিল…)')),
                  Icon(Icons.chevron_right),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ছোট বার চার্ট: মাসের প্রতিদিনের বিক্রি
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.data, required this.days});
  final Map<int, double> data;
  final int days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    var maxV = 0.0;
    for (final v in data.values) {
      if (v > maxV) maxV = v;
    }
    if (maxV == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('এই মাসে এখনো কোনো বিক্রি নেই')),
      );
    }
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var day = 1; day <= days; day++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 2 + 80 * ((data[day] ?? 0) / maxV),
                      decoration: BoxDecoration(
                        color: (data[day] ?? 0) > 0
                            ? cs.primary
                            : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: (day == 1 || day % 5 == 0)
                          ? FittedBox(
                              child: Text(bn(day),
                                  style: const TextStyle(fontSize: 9)))
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
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

    String timeLine;
    if (salesLeft <= 0) {
      timeLine = 'বিক্রয়ের টার্গেট পূর্ণ! 🎉';
    } else if (d.daysLeft <= 0) {
      timeLine = 'মাস শেষ';
    } else {
      timeLine =
          'আরও সময় আছে ${bn(d.daysLeft)} দিন | দৈনিক বিক্রয় লাগবে ${taka((salesLeft / d.daysLeft).ceil())}';
    }

    Widget left(Color c, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(text, style: tt.bodyMedium),
          ],
        );

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('টার্গেটঃ ${taka(d.target)}',
              style: tt.headlineSmall
                  ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        _DualBar(
            sales: d.sales / d.target,
            collected: d.collected / d.target,
            salesColor: salesColor,
            collColor: collColor,
            track: cs.surfaceContainerHighest),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            left(salesColor, 'বিক্রয় এখনও বাকি ${taka(salesLeft)}'),
            left(collColor, 'নগদ কালেকশন বাকি ${taka(collLeft)}'),
          ],
        ),
        const SizedBox(height: 10),
        Text(timeLine,
            textAlign: TextAlign.center,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// একটাই গোল বার, ভেতরে দুই লেন: ওপরে বিক্রয় (কমলা), নিচে আদায় (সবুজ-নীল)
class _DualBar extends StatelessWidget {
  const _DualBar(
      {required this.sales,
      required this.collected,
      required this.salesColor,
      required this.collColor,
      required this.track});
  final double sales, collected;
  final Color salesColor, collColor, track;

  @override
  Widget build(BuildContext context) {
    Widget lane(double f, Color c) => LayoutBuilder(
          builder: (context, box) => Stack(children: [
            Container(height: 10, color: track),
            Container(
                height: 10,
                width: box.maxWidth * f.clamp(0.0, 1.0),
                color: c),
          ]),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(children: [
        lane(sales, salesColor),
        const SizedBox(height: 2),
        lane(collected, collColor),
      ]),
    );
  }
}
