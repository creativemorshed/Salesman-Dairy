import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'db.dart';
import 'utils.dart';
import 'widgets.dart';

/// ডোনেশনের মাধ্যম: সেটিংসের কী · নাম · রঙ
const _methods = <(String, String, Color)>[
  ('donate_bkash', 'বিকাশ', Color(0xFFE2136E)),
  ('donate_nagad', 'নগদ', Color(0xFFF6921E)),
  ('donate_rocket', 'রকেট', Color(0xFF8C3494)),
];

Future<Map<String, String>> _loadNumbers() async {
  final out = <String, String>{};
  for (final (key, _, _) in _methods) {
    final v = (await AppDb.instance.getSetting(key) ?? '').trim();
    if (v.isNotEmpty) out[key] = v;
  }
  return out;
}

/// হোমের নিচের ডোনেশন কার্ড
class DonationCard extends StatelessWidget {
  const DonationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.85),
            const Color(0xFFFFF3E3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite, color: cs.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('অ্যাপটা ভালো লাগছে?',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('আপনার সামান্য ডোনেশন নতুন ফিচার ও উন্নতির পথ খুলে দেয়।',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () => showDonationSheet(context),
            child: const Text('ডোনেট', softWrap: false),
          ),
        ],
      ),
    );
  }
}

/// ডোনেশনের নম্বরগুলো দেখায় (কপি করা যায়)
Future<void> showDonationSheet(BuildContext context) async {
  final nums = await _loadNumbers();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final tt = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ডোনেশন', style: tt.titleLarge),
              const SizedBox(height: 4),
              Text('নিচের যেকোনো নম্বরে সেন্ড মানি করুন। ধন্যবাদ! ❤️',
                  style: tt.bodyMedium),
              const SizedBox(height: 12),
              if (nums.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('ডোনেশনের নম্বর এখনো যোগ করা হয়নি।'),
                ),
              for (final (key, name, color) in _methods)
                if (nums[key] != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color,
                      child: Text(name.substring(0, 1),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(name),
                    subtitle: Text(nums[key]!,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    trailing: IconButton(
                      tooltip: 'কপি',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: nums[key]!));
                        if (ctx.mounted) snack(ctx, '$name নম্বর কপি হয়েছে');
                      },
                    ),
                  ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('নম্বর যোগ/বদল'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (context.mounted) await showDonationNumbersSheet(context);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// ডোনেশনের নম্বর বসানো/বদলানো (সেটিংস থেকেও আসে)
Future<void> showDonationNumbersSheet(BuildContext context) async {
  final nums = await _loadNumbers();
  final ctrls = {
    for (final (key, _, _) in _methods) key: TextEditingController(text: nums[key] ?? ''),
  };
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ডোনেশনের নম্বর', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final (key, name, _) in _methods) ...[
              TextField(
                controller: ctrls[key],
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: '$name নম্বর'),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton(
              onPressed: () async {
                for (final (key, _, _) in _methods) {
                  final v = ctrls[key]!.text.trim();
                  if (v.isEmpty) {
                    await AppDb.instance.deleteSetting(key);
                  } else {
                    await AppDb.instance.setSetting(key, v);
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('সংরক্ষণ'),
            ),
          ],
        ),
      ),
    ),
  );
  for (final c in ctrls.values) {
    c.dispose();
  }
}
