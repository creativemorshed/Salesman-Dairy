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
    required this.stale,
    required this.noted,
  });
  final Rec? market;
  final List<Rec> route;
  final double totalDue;
  final List<Rec> stale; // দীর্ঘদিন ভিজিট/এন্ট্রি নেই
  final List<Rec> noted; // পরের ভিজিটের বিশেষ নোট আছে
}

/// হোম: মার্কেট বাকি, আজকের রুটের অবস্থা, পরের ৩টি দোকান, রিমাইন্ডার
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<_Dash> _load() async {
    final db = AppDb.instance;
    final market = await db.activeMarket(selectedMarket.value);
    final route =
        market == null ? <Rec>[] : await db.route(market['id'] as int);
    final limit = staleDays.value;

    return _Dash(
      market: market,
      route: route,
      totalDue: await db.totalDue(),
      stale: limit > 0 ? await db.staleOutlets(limit) : <Rec>[],
      noted: await db.notedOutlets(),
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
                  style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(taka(marketDue),
                    style: tt.displayMedium?.copyWith(color: cs.onSurface)),
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

        // ---- রিমাইন্ডার (থাকলে): দীর্ঘদিন ভিজিট নেই · বিশেষ নোট ----
        if (d.stale.isNotEmpty || d.noted.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                if (d.stale.isNotEmpty)
                  _ReminderTile(
                    icon: Icons.history,
                    color: const Color(0xFFB45309),
                    text:
                        '${bn(d.stale.length)}টি দোকানে ${bn(staleDays.value)} দিনের বেশি ভিজিট/এন্ট্রি নেই',
                    onTap: () => _showList(context,
                        'দীর্ঘদিন যাওয়া হয়নি', d.stale, stale: true),
                  ),
                if (d.stale.isNotEmpty && d.noted.isNotEmpty)
                  const Divider(height: 1),
                if (d.noted.isNotEmpty)
                  _ReminderTile(
                    icon: Icons.sticky_note_2_outlined,
                    color: cs.tertiary,
                    text: '${bn(d.noted.length)}টি দোকানে পরের ভিজিটের বিশেষ নোট আছে',
                    onTap: () =>
                        _showList(context, 'বিশেষ নোট', d.noted, stale: false),
                  ),
              ],
            ),
          ),

        // ---- বিস্তারিত বাটন ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              onPressed: () => tabIndex.value = 1,
              child: const Text('বিস্তারিত'),
            ),
          ),
        ),
      ],
    );
  }

  void _showList(BuildContext context, String title, List<Rec> rows,
      {required bool stale}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in rows)
                      ListTile(
                        leading: GradeBadge(o['grade'] as String, size: 34),
                        title: Text(o['name'] as String),
                        subtitle: Text(stale
                            ? '${o['market_name']} · ${bn(idleDays(o) ?? 0)} দিন ধরে নেই'
                            : '${o['market_name']} · ${(o['next_note'] as String).trim()}'),
                        trailing: Text(taka((o['due'] as num).toDouble()),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    OutletDetail(id: o['id'] as int)),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(agoText(r['last_visit'] as String?),
                      style: tt.bodySmall),
                  if (((r['next_note'] as String?) ?? '').trim().isNotEmpty)
                    InfoLine(Icons.sticky_note_2_outlined,
                        'নোট: ${(r['next_note'] as String).trim()}',
                        color: Theme.of(context).colorScheme.tertiary),
                ],
              ),
            ),
            Text(taka(due),
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile(
      {required this.icon,
      required this.color,
      required this.text,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
