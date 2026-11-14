import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
const bnMonths = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
];

/// DateTime.weekday: সোম=1 … রবি=7
const bnWeekdays = [
  'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার',
];
const bnWeekdaysShort = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];

/// সপ্তাহের ক্রম শনিবার থেকে (DateTime.weekday মান)
const weekOrder = [6, 7, 1, 2, 3, 4, 5];

/// ইংরেজি সংখ্যাকে বাংলা সংখ্যায় রূপান্তর
String bn(Object v) => v
    .toString()
    .replaceAllMapped(RegExp(r'[0-9]'), (m) => _bnDigits[int.parse(m[0]!)]);

/// বাংলা সংখ্যাকে ইংরেজি সংখ্যায় রূপান্তর
String toEn(String s) {
  var r = s;
  for (var i = 0; i < 10; i++) {
    r = r.replaceAll(_bnDigits[i], '$i');
  }
  return r;
}

/// ইনপুট থেকে সংখ্যা পার্স (বাংলা/ইংরেজি দুটোই চলবে)
double parseNum(String s) =>
    double.tryParse(toEn(s.trim()).replaceAll(',', '')) ?? 0;

/// ইনপুট ফিল্ডে বসানোর জন্য (১২০.0 → "120")
String numText(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

// ভারতীয় পদ্ধতিতে কমা: 500000 → 5,00,000
String _indian(String digits) {
  if (digits.length <= 3) return digits;
  final last = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last';
}

/// ৳৫,০০,০০০ আকারে টাকা
String taka(num v) {
  final neg = v < 0;
  final parts = v.abs().toStringAsFixed(2).split('.');
  final frac = parts[1].replaceFirst(RegExp(r'0+$'), '');
  final out = StringBuffer(neg ? '-' : '')
    ..write('৳')
    ..write(bn(_indian(parts[0])));
  if (frac.isNotEmpty) out.write('.${bn(frac)}');
  return out.toString();
}

// ---- তারিখ (ডেটাবেসে yyyy-MM-dd হিসেবে থাকে) ----
String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String today() => ymd(DateTime.now());
DateTime parseYmd(String s) => DateTime.parse(s);

String nextDay(String s) {
  final d = parseYmd(s);
  return ymd(DateTime(d.year, d.month, d.day + 1));
}

String niceDate(String? s) {
  if (s == null || s.isEmpty) return '—';
  final d = parseYmd(s);
  return '${bn(d.day)} ${bnMonths[d.month - 1]} ${bn(d.year)}';
}

/// "মঙ্গলবার · ৬ অক্টোবর"
String dayHeader(DateTime d) =>
    '${bnWeekdays[d.weekday - 1]} · ${bn(d.day)} ${bnMonths[d.month - 1]}';

String monthTitle(DateTime m) => '${bnMonths[m.month - 1]} ${bn(m.year)}';
String monthStart(DateTime m) => ymd(DateTime(m.year, m.month, 1));
// পরের মাসের ১ তারিখ (exclusive শেষ সীমা)
String monthEnd(DateTime m) => ymd(DateTime(m.year, m.month + 1, 1));

/// শেষ ভিজিট কত দিন আগে
String lastVisitText(String? last) {
  if (last == null || last.isEmpty) return 'এখনো ভিজিট হয়নি';
  final n = DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(parseYmd(last)).inDays;
  if (days <= 0) return 'আজ ভিজিট হয়েছে';
  return '${bn(days)} দিন আগে ভিজিট';
}

/// মাসের বাকি দিনে (আজসহ) প্রতিদিন কত করে লাগবে
double perDayNeeded(double target, double achieved, DateTime now) {
  final left = target - achieved;
  if (left <= 0) return 0;
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final days = lastDay - now.day + 1;
  return (left / days).ceilToDouble();
}

/// আউটলেটের গ্রেডের রঙ (A নীল, B টিল, C ধূসর-নীল)
Color gradeColor(String? g) {
  switch (g) {
    case 'A':
      return const Color(0xFF1E7BDB);
    case 'C':
      return const Color(0xFF78909C);
    default:
      return const Color(0xFF12879B);
  }
}

// ---- UI হেল্পার ----
void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirm(BuildContext context, String message,
    {String yes = 'হ্যাঁ'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> pickDate(BuildContext context, {String? initial}) async {
  final d = await showDatePicker(
    context: context,
    initialDate: initial != null ? parseYmd(initial) : DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
    confirmText: 'ঠিক আছে',
    cancelText: 'বাতিল',
  );
  return d == null ? null : ymd(d);
}

// ---- কল / WhatsApp ----
Future<void> _open(BuildContext context, Uri uri) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) snack(context, 'খোলা যায়নি');
}

Future<void> callPhone(BuildContext context, String phone) =>
    _open(context, Uri(scheme: 'tel', path: toEn(phone).trim()));

Future<void> openWhatsApp(BuildContext context, String phone) {
  var n = toEn(phone).replaceAll(RegExp(r'[^0-9]'), '');
  if (n.startsWith('0')) n = '88$n'; // বাংলাদেশ কান্ট্রি কোড
  return _open(context, Uri.parse('https://wa.me/$n'));
}
