import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';
import 'expenses.dart';
import 'outlet_detail.dart';

class _Prog {
  _Prog({
    required this.sales,
    required this.collected,
    required this.spent,
    required this.visits,
    required this.totalDue,
    required this.salesTarget,
    required this.collTarget,
    required this.daysLeft,
    required this.markets,
    required this.top,
    required this.daily,
  });
  final double sales, collected, spent, totalDue, salesTarget, collTarget;
  final int visits, daysLeft;
  final List<Rec> markets, top;
  final Map<int, double> daily; // মাসের দিন → বিক্রি
}

/// প্রগ্রেস: টার্গেট বনাম অর্জন, দিনভিত্তিক বিক্রি, মার্কেট অনুযায়ী হিসাব, বেশি বাকি
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
      visits: await db.visitCount(from, to),
      totalDue: await db.totalDue(),
      salesTarget: (t?['sales'] as num?)?.toDouble() ?? 0,
      collTarget: (t?['collection'] as num?)?.toDouble() ?? 0,
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
      appBar: AppBar(title: const Text('প্রগ্রেস')),
      body: DbBuilder<_Prog>(
        load: _load,
        builder: (context, d) {
          final daysInMonth = DateTime(_m.year, _m.month + 1, 0).day;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              MonthBar(month: _m, onChanged: (m) => setState(() => _m = m)),

              // ---- টার্গেট বনাম অর্জন ----
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('টার্গেট ও অর্জন',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: const Text('টার্গেট ঠিক করুন'),
                        onPressed: () => showTargetSheet(context, _m,
                            sales: d.salesTarget, collection: d.collTarget),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    TargetBar(
                        label: 'বিক্রি',
                        achieved: d.sales,
                        target: d.salesTarget,
                        daysLeft: d.daysLeft),
                    const SizedBox(height: 14),
                    TargetBar(
                        label: 'আদায়',
                        achieved: d.collected,
                        target: d.collTarget,
                        daysLeft: d.daysLeft,
                        color: const Color(0xFF138A9B)),
                    const SizedBox(height: 10),
                    Text('কাজের দিন বাকি: ${bn(d.daysLeft)} দিন',
                        style: tt.bodySmall),
                  ],
                ),
              ),

              // ---- তিনটি সংখ্যা ----
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Expanded(
                      child: StatCard(
                          label: 'ভিজিট',
                          value: '${bn(d.visits)} টি',
                          icon: Icons.directions_walk)),
                  Expanded(
                      child: StatCard(
                          label: 'মোট বাকি',
                          value: taka(d.totalDue),
                          icon: Icons.warning_amber_rounded,
                          color: cs.error)),
                  Expanded(
                      child: StatCard(
                          label: 'খরচ',
                          value: taka(d.spent),
                          icon: Icons.account_balance_wallet_outlined)),
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
                                color: cs.error, fontWeight: FontWeight.w800)),
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
                            color: cs.error, fontWeight: FontWeight.w800)),
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
