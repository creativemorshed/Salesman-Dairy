import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
const bnMonths = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
];
// DateTime.weekday: সোম=1 ... রবি=7
const weekdayNames = [
  '', 'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার',
];
const weekdayShort = ['', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];

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

// ভারতীয়/বাংলাদেশি গ্রুপিং: 500000 → 5,00,000
String _group(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// টাকার অংক: ৳5,00,000
String taka(num v) {
  final neg = v < 0;
  final a = v.abs().toDouble();
  final isInt = (a - a.roundToDouble()).abs() < 0.005;
  final s = isInt ? a.round().toString() : a.toStringAsFixed(2);
  final p = s.split('.');
  return '${neg ? '-' : ''}৳${_group(p[0])}${p.length > 1 ? '.${p[1]}' : ''}';
}

// ---- তারিখ (ডেটাবেসে yyyy-MM-dd হিসেবে থাকে) ----
String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String today() => ymd(DateTime.now());
DateTime parseYmd(String s) => DateTime.parse(s);
String nextDay(String s) {
  final d = parseYmd(s);
  return ymd(DateTime(d.year, d.month, d.day + 1));
}

String afterDays(int n) {
  final d = DateTime.now();
  return ymd(DateTime(d.year, d.month, d.day + n));
}

String niceDate(String? s) {
  if (s == null || s.isEmpty) return '—';
  final d = parseYmd(s);
  return '${bn(d.day)} ${bnMonths[d.month - 1]} ${bn(d.year)}';
}

/// "মঙ্গলবার · ৬ অক্টোবর"
String todayHeading([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${weekdayNames[d.weekday]} · ${bn(d.day)} ${bnMonths[d.month - 1]}';
}

String monthTitle(DateTime m) => '${bnMonths[m.month - 1]} ${bn(m.year)}';
String monthStart(DateTime m) => ymd(DateTime(m.year, m.month, 1));
// পরের মাসের ১ তারিখ (exclusive শেষ সীমা)
String monthEnd(DateTime m) => ymd(DateTime(m.year, m.month + 1, 1));
// টার্গেটের কী: 2026-10
String monthKey(DateTime m) =>
    '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';

/// শেষ ভিজিট কতদিন আগে
String agoText(String? date) {
  if (date == null) return 'এখনো ভিজিট হয়নি';
  final n = parseYmd(today()).difference(parseYmd(date)).inDays;
  if (n <= 0) return 'আজ ভিজিট হয়েছে';
  if (n == 1) return 'শেষ ভিজিট: গতকাল';
  return 'শেষ ভিজিট: ${bn(n)} দিন আগে';
}

/// মার্কেটের ভিজিটের দিন ("1,3,6" ফরম্যাটে সংরক্ষিত)
bool hasDay(String days, int weekday) => days.split(',').contains('$weekday');

String daysText(String days) {
  if (days.trim().isEmpty) return 'দিন ঠিক করা নেই';
  final list = days.split(',').map(int.parse).toList()..sort();
  return list.map((d) => weekdayShort[d]).join(', ');
}

/// আজকসহ মাসের বাকি কর্মদিবস (সাপ্তাহিক ছুটির দিন বাদে; weeklyOff=0 মানে ছুটি নেই)
int remainingWorkDays(int weeklyOff, [DateTime? now]) {
  final t = now ?? DateTime.now();
  final last = DateTime(t.year, t.month + 1, 0).day;
  var n = 0;
  for (var d = t.day; d <= last; d++) {
    if (DateTime(t.year, t.month, d).weekday != weeklyOff) n++;
  }
  return n;
}

Color gradeColor(String grade) {
  switch (grade) {
    case 'A+':
      return const Color(0xFF1E6FD9);
    case 'A':
      return const Color(0xFF138A9B);
    case 'F':
      return const Color(0xFFB3261E);
    default:
      return const Color(0xFFD9901A);
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
