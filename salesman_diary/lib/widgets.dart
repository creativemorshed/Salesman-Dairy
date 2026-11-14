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

/// ক্রিম-সাদা গোলাকার প্যানেল (হোম স্ক্রিনের কার্ড)
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4DDCF)),
        ),
        child: child,
      );
}

class GradeDot extends StatelessWidget {
  const GradeDot({super.key, required this.grade});
  final String? grade;

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: gradeColor(grade)),
      );
}

/// বাকির পরিমাণ (বাকি থাকলে লাল, অগ্রিম থাকলে সবুজ)
class DueLabel extends StatelessWidget {
  const DueLabel(this.due, {super.key});
  final double due;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (due > 0) {
      return Text(taka(due),
          style: TextStyle(
              color: cs.error, fontWeight: FontWeight.bold, fontSize: 16));
    }
    if (due < 0) {
      return Text('অগ্রিম ${taka(-due)}',
          style: const TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold));
    }
    return const SizedBox.shrink();
  }
}

/// আউটলেটের এক সারি: গ্রেডের ডট, নাম, নিচে তথ্য, ডানে বাকি
class OutletRow extends StatelessWidget {
  const OutletRow({
    super.key,
    required this.o,
    required this.onTap,
    this.showMarket = false,
    this.trailing,
  });

  final Rec o;
  final VoidCallback onTap;
  final bool showMarket;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final grade = (o['grade'] as String?) ?? 'B';
    final market = (o['market'] as String?) ?? '';
    final sub = [
      if (showMarket && market.isNotEmpty) market,
      lastVisitText(o['last_visit'] as String?),
      grade,
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: GradeDot(grade: grade),
      horizontalTitleGap: 12,
      title: Text(o['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      subtitle: Text(sub),
      trailing: trailing ?? DueLabel((o['due'] as num).toDouble()),
      onTap: onTap,
    );
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

/// তারিখ বাছাইয়ের ছোট বাটন
class DateChip extends StatelessWidget {
  const DateChip({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        icon: const Icon(Icons.calendar_month),
        label: Text(niceDate(value)),
        onPressed: () async {
          final d = await pickDate(context, initial: value);
          if (d != null) onChanged(d);
        },
      );
}

/// টার্গেট বনাম অর্জনের প্রগ্রেস বার + "দিনে ৳X লাগবে"
class TargetLine extends StatelessWidget {
  const TargetLine({
    super.key,
    required this.label,
    required this.achieved,
    required this.target,
    this.showPerDay = true,
  });

  final String label;
  final double achieved;
  final double target;
  final bool showPerDay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (target <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('$label: ${taka(achieved)} · টার্গেট সেট করা নেই'),
      );
    }
    final pct = achieved / target;
    final need = perDayNeeded(target, achieved, DateTime.now());
    final tail = !showPerDay
        ? ''
        : need > 0
            ? ' · দিনে ${taka(need)} লাগবে'
            : ' · টার্গেট পূরণ ✓';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${taka(achieved)} / ${taka(target)} '
            '(${bn((pct * 100).toStringAsFixed(0))}%)$tail',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}
