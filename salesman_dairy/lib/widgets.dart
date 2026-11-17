import 'package:flutter/material.dart';

import 'db.dart';
import 'utils.dart';

/// ডেটাবেস বদলালে নিজে থেকেই আবার লোড করে দেখায়
class DbBuilder<T> extends StatefulWidget {
  const DbBuilder({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<DbBuilder<T>> createState() => _DbBuilderState<T>();
}

class _DbBuilderState<T> extends State<DbBuilder<T>> {
  T? _data;
  bool _has = false;
  Object? _error;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    AppDb.instance.changes.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(covariant DbBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  @override
  void dispose() {
    AppDb.instance.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final t = ++_tick;
    try {
      final d = await widget.load();
      if (!mounted || t != _tick) return;
      setState(() {
        _data = d;
        _has = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted || t != _tick) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('ত্রুটি: $_error'));
    }
    if (!_has) return const Center(child: CircularProgressIndicator());
    return widget.builder(context, _data as T);
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color ?? cs.primary),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          count == null ? text : '$text (${bn(count!)})',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.text, {super.key});
  final String? text;

  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox(height: 8)
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(text!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        );
}

/// মাস পরিবর্তনের বার (< জানুয়ারি ২০২৬ >)
class MonthBar extends StatelessWidget {
  const MonthBar({super.key, required this.month, required this.onChanged});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                onChanged(DateTime(month.year, month.month - 1, 1)),
          ),
          Text(monthTitle(month),
              style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                onChanged(DateTime(month.year, month.month + 1, 1)),
          ),
        ],
      );
}

/// রিমাইন্ডার তারিখ বাছাই: নাই · ৭ দিন পর · আইকন + তারিখ (ক্যালেন্ডার)
class ReminderField extends StatelessWidget {
  const ReminderField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final in7 = afterDays(7);
    final custom = value != null && value != in7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('নাই'),
              selected: value == null,
              onSelected: (_) => onChanged(null),
            ),
            ChoiceChip(
              label: const Text('৭ দিন পর'),
              selected: value == in7,
              onSelected: (_) => onChanged(in7),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.calendar_month, size: 18),
              label: Text(custom ? niceDate(value) : 'তারিখ'),
              selected: custom,
              showCheckmark: false,
              onSelected: (_) async {
                final d = await pickDate(context, initial: value);
                if (d != null) onChanged(d);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// আউটলেটের গ্রেড (A+/A/B/F) — রঙিন গোল ব্যাজ
class GradeBadge extends StatelessWidget {
  const GradeBadge(this.grade, {super.key, this.size = 36});
  final String grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = gradeColor(grade);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(c.withAlpha(36), Colors.white),
        border: Border.all(color: c, width: 1.5),
      ),
      child: Text(grade,
          style: TextStyle(
              color: c, fontWeight: FontWeight.bold, fontSize: size * (grade.length > 1 ? 0.34 : 0.42))),
    );
  }
}

/// "চন্দনাইশ" চিপ — চাপলে রুট বদলানো যায়
class MarketChip extends StatelessWidget {
  const MarketChip(
      {super.key, required this.name, required this.onTap});
  final String? name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.store_mall_directory_outlined, size: 18),
      label: Text(
          name ?? 'রুট পছন্দ করুন',
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      onPressed: onTap,
    );
  }
}

/// গোলাকার কোণের সাদা কার্ড (ক্রিম ব্যাকগ্রাউন্ডের উপর)
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.fromLTRB(16, 6, 16, 6),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: const Color(0xFFFFFDF8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE6DFD0)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// টার্গেট বনাম অর্জন: প্রগ্রেস বার + "দিনে কত লাগবে"
class TargetBar extends StatelessWidget {
  const TargetBar({
    super.key,
    required this.label,
    required this.achieved,
    required this.target,
    this.daysLeft,
    this.color,
  });

  final String label;
  final double achieved;
  final double target;
  final int? daysLeft; // বাকি কর্মদিবস (null হলে "দিনে লাগবে" দেখাবে না)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = target > 0 ? achieved / target : 0.0;
    final remaining = target - achieved;

    var need = '';
    if (daysLeft != null && target > 0) {
      if (remaining <= 0) {
        need = ' · টার্গেট পূর্ণ!';
      } else if (daysLeft! > 0) {
        need = ' · দিনে ${taka((remaining / daysLeft!).ceil())} লাগবে';
      } else {
        need = ' · মাস শেষ';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (target > 0)
            Text('${bn((pct * 100).floor())}%',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        if (target <= 0)
          Text('টার্গেট সেট করা নেই',
              style: TextStyle(color: cs.onSurfaceVariant))
        else ...[
          LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0).toDouble(),
            minHeight: 10,
            borderRadius: BorderRadius.circular(6),
            color: color,
          ),
          const SizedBox(height: 6),
          Text('${taka(achieved)} / ${taka(target)}$need'),
        ],
      ],
    );
  }
}

/// কার্ডের ভেতরে ছোট সতর্কবার্তা/নোট লাইন (আইকন + লেখা)
class InfoLine extends StatelessWidget {
  const InfoLine(this.icon, this.text, {super.key, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
