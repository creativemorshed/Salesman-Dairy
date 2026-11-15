import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';
import 'outlet_detail.dart';
import 'settings.dart';

class _Dash {
  _Dash({
    required this.market,
    required this.route,
    required this.totalDue,
    required this.sales,
    required this.collected,
    required this.salesTarget,
    required this.collTarget,
    required this.daysLeft,
  });
  final Rec? market;
  final List<Rec> route;
  final double totalDue, sales, collected, salesTarget, collTarget;
  final int daysLeft;
}

/// হোম: মার্কেট বাকি, আজকের রুটের অবস্থা, পরের ৩টি দোকান, মাসের টার্গেট
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<_Dash> _load() async {
    final db = AppDb.instance;
    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final from = monthStart(month), to = monthEnd(month);

    final market = await db.activeMarket(selectedMarket.value);
    final route =
        market == null ? <Rec>[] : await db.route(market['id'] as int);
    final off = int.tryParse(await db.getSetting('weekly_off') ?? '') ?? 5;
    final t = await db.targetFor(monthKey(month));

    return _Dash(
      market: market,
      route: route,
      totalDue: await db.totalDue(),
      sales: await db.sales(from, to),
      collected: await db.collected(from, to),
      salesTarget: (t?['sales'] as num?)?.toDouble() ?? 0,
      collTarget: (t?['collection'] as num?)?.toDouble() ?? 0,
      daysLeft: remainingWorkDays(off),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int?>(
          valueListenable: selectedMarket,
          builder: (context, _, __) => DbBuilder<_Dash>(
            load: _load,
            builder: (context, d) => _body(context, d),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, _Dash d) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final market = d.market;
    final total = d.route.length;
    final pending = d.route.where((r) => r['visited_today'] != 1).toList();
    final done = total - pending.length;
    final marketDue =
        market != null ? (market['due'] as num).toDouble() : d.totalDue;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ---- উপরের সারি: তারিখ · মার্কেট · সেটিংস ----
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(todayHeading(),
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
              ),
              MarketChip(
                  name: market?['name'] as String?,
                  onTap: () => showMarketPicker(context)),
              IconButton(
                tooltip: 'সেটিংস',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
        ),

        // ---- মার্কেট বাকি ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              Text(market != null ? 'মার্কেট বাকির পরিমাণ' : 'মোট বাকির পরিমাণ',
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(taka(marketDue),
                    style: tt.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: cs.onSurface)),
              ),
              const SizedBox(height: 4),
              Text('মোট দোকান - ${bn(total)} টি, বাকি দোকান - ${bn(pending.length)} টি',
                  style: tt.titleSmall),
              if (market != null) ...[
                const SizedBox(height: 2),
                Text('সব মার্কেট মিলিয়ে মোট বাকি: ${taka(d.totalDue)}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 12,
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        // ---- পরের ৩টি দোকান ----
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  pending.isEmpty ? 'আজকের রুট' : 'পরের ${bn(pending.length < 3 ? pending.length : 3)}টি দোকান',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (market == null)
                _hint(context, 'প্রথমে একটি মার্কেট যোগ করুন',
                    'মার্কেট যোগ করুন', () => showMarketSheet(context))
              else if (total == 0)
                _hint(context, 'এই মার্কেটে এখনো কোনো আউটলেট নেই',
                    'আউটলেট যোগ করুন',
                    () => showOutletSheet(context,
                        marketId: market['id'] as int))
              else if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('আজকের সব ভিজিট শেষ! 🎉'),
                )
              else
                for (var i = 0; i < pending.length && i < 3; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _NextTile(r: pending[i]),
                ],
            ],
          ),
        ),

        // ---- বিস্তারিত বাটন ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: SizedBox(
            height: 64,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                textStyle:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              onPressed: () => tabIndex.value = 1,
              child: const Text('বিস্তারিত'),
            ),
          ),
        ),

        // ---- মাসের টার্গেট ও অর্জন ----
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('এই মাসের টার্গেট ও অর্জন',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 10),
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
              if (d.salesTarget <= 0 && d.collTarget <= 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        showTargetSheet(context, DateTime.now()),
                    child: const Text('টার্গেট ঠিক করুন'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hint(BuildContext context, String text, String button,
      VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(text),
        ),
        FilledButton.tonal(onPressed: onTap, child: Text(button)),
      ],
    );
  }
}

class _NextTile extends StatelessWidget {
  const _NextTile({required this.r});
  final Rec r;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final due = (r['due'] as num).toDouble();
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OutletDetail(id: r['id'] as int)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            GradeBadge(r['grade'] as String, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['name'] as String,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(agoText(r['last_visit'] as String?),
                      style: tt.bodySmall),
                ],
              ),
            ),
            Text(taka(due),
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
