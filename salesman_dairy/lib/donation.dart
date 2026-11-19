import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import 'i18n.dart';
import 'utils.dart';

/// ডোনেশনের নম্বর — বিকাশ, নগদ ও রকেট তিনটির জন্য একই; অ্যাপে বদলানো যায় না
const donationNumber = '01815-976176';

String _t(String en, String bnText) => isEn ? en : bnText;

class _Method {
  const _Method(this.id, this.name, this.color);
  final String id;
  final String name;
  final Color color;
}

const _methods = <_Method>[
  _Method('bkash', 'bKash', Color(0xFFE2136E)),
  _Method('nagad', 'Nagad', Color(0xFFF6921E)),
  _Method('rocket', 'Rocket', Color(0xFF8C3494)),
];

const _quickAmounts = [50, 100, 250];

// অ্যাপের কমলা-বাদামি রঙের সাথে মেলানো
const _deep = Color(0xFF5A1D05);
const _brand = Color(0xFFD9480F);
const _cream = Color(0xFFFFFDF8);

/// হোমের একদম নিচের ডোনেশন কার্ড (ডিজাইন ফিক্সড)
class DonationCard extends StatefulWidget {
  const DonationCard({super.key});

  @override
  State<DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends State<DonationCard> {
  int? _amount = 100; // বাছাই করা পরিমাণ (null = নিজের লেখা)
  int _method = 0;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  int get _value => _amount ?? parseNum(_custom.text).round();

  void _donate() {
    if (_value <= 0) {
      snack(context, _t('Select or enter an amount', 'পরিমাণ বাছুন বা লিখুন'));
      return;
    }
    _showDonationSheet(context, amount: _value, method: _methods[_method]);
  }

  @override
  Widget build(BuildContext context) {
    LangScope.watch(context);
    final tt = Theme.of(context).textTheme;
    final onDark = tt.bodyMedium?.copyWith(color: Colors.white);

    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(s,
              style: tt.titleSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [_deep, Color(0xFF9A330A), _brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: _deep.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // হালকা সাজানো বৃত্ত
            Positioned(
              right: -40,
              top: -40,
              child: _circle(130, 0.07),
            ),
            Positioned(
              left: -50,
              bottom: -60,
              child: _circle(150, 0.06),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(_t('Support Our Journey ❤️', 'আমাদের পাশে থাকুন ❤️'),
                        textAlign: TextAlign.center,
                        style: tt.titleLarge?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                        _t('Your contribution helps us grow and improve.',
                            'আপনার সহযোগিতা আমাদের এগিয়ে যেতে ও আরও ভালো হতে সাহায্য করে।'),
                        textAlign: TextAlign.center,
                        style: onDark?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78))),
                  ),
                  label(_t('Select Amount', 'পরিমাণ বাছুন')),
                  Row(
                    children: [
                      for (final a in _quickAmounts) ...[
                        _AmountChip(
                          text: '৳${bn(a)}',
                          selected: _amount == a,
                          onTap: () => setState(() {
                            _amount = a;
                            _custom.clear();
                            FocusScope.of(context).unfocus();
                          }),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _CustomAmount(
                          controller: _custom,
                          active: _amount == null,
                          hint: _t('Your amount', 'অন্য পরিমাণ'),
                          onChanged: (_) => setState(() => _amount = null),
                          onTap: () => setState(() => _amount = null),
                        ),
                      ),
                    ],
                  ),
                  label(_t('Payment Method', 'পেমেন্ট মেথড')),
                  Row(
                    children: [
                      for (var i = 0; i < _methods.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _MethodTile(
                            method: _methods[i],
                            selected: _method == i,
                            onTap: () => setState(() => _method = i),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _cream,
                        foregroundColor: _deep,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _donate,
                      child: Text(_t('Donate Now', 'এখনই ডোনেট করুন'),
                          style: tt.titleMedium?.copyWith(
                              color: _deep, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

class _AmountChip extends StatelessWidget {
  const _AmountChip(
      {required this.text, required this.selected, required this.onTap});
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 62,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.20 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected
                  ? const Color(0xFFFFC9A8)
                  : Colors.white.withValues(alpha: 0.22),
              width: selected ? 2 : 1),
        ),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _CustomAmount extends StatelessWidget {
  const _CustomAmount({
    required this.controller,
    required this.active,
    required this.hint,
    required this.onChanged,
    required this.onTap,
  });
  final TextEditingController controller;
  final bool active;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: active
                ? const Color(0xFFFFC9A8)
                : Colors.white.withValues(alpha: 0.22),
            width: active ? 2 : 1),
      ),
      child: Row(
        children: [
          Text('৳',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              onChanged: onChanged,
              onTap: onTap,
              cursorColor: Colors.white,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile(
      {required this.method, required this.selected, required this.onTap});
  final _Method method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFEBDD) : _cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? const Color(0xFFFFC9A8) : Colors.transparent,
              width: 2.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration:
                  BoxDecoration(color: method.color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(method.name.substring(0, 1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(method.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: method.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Donate Now" চাপার পর: কোন নম্বরে কত টাকা পাঠাতে হবে
Future<void> _showDonationSheet(BuildContext context,
    {required int amount, required _Method method}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _cream,
    builder: (ctx) {
      final tt = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_t('Send Money', 'সেন্ড মানি করুন'),
                  textAlign: TextAlign.center, style: tt.titleLarge),
              const SizedBox(height: 4),
              Text(_t('Thank you for supporting us! ❤️', 'আমাদের পাশে থাকার জন্য ধন্যবাদ! ❤️'),
                  textAlign: TextAlign.center, style: tt.bodyMedium),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: method.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: method.color.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Text('৳${bn(amount)}',
                        style: tt.displayMedium?.copyWith(
                            color: method.color, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(_t('via ${method.name}', '${method.name} এর মাধ্যমে'),
                        style: tt.bodyMedium),
                    const SizedBox(height: 10),
                    Text(donationNumber,
                        style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                  _t('Open the ${method.name} app → Send Money → enter this number and the amount → confirm.',
                      '${method.name} অ্যাপ খুলুন → সেন্ড মানি → এই নম্বর ও টাকার পরিমাণ দিন → নিশ্চিত করুন।'),
                  textAlign: TextAlign.center,
                  style: tt.bodySmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: Text(_t('Copy number', 'নম্বর কপি করুন')),
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: donationNumber));
                  if (ctx.mounted) {
                    snack(ctx, _t('Number copied', 'নম্বর কপি হয়েছে'));
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
