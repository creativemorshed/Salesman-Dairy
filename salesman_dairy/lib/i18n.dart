import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;

/// অ্যাপের ভাষা: 'en' (ডিফল্ট) বা 'bn'। সেটিংসে বদলানো যায়।
final ValueNotifier<String> lang = ValueNotifier<String>('en');
bool get isEn => lang.value != 'bn';

/// ভাষা বদলালে নিচের সব [Text] নিজে থেকে নতুন করে আঁকা হয়
class LangScope extends m.InheritedNotifier<ValueNotifier<String>> {
  const LangScope({super.key, required super.notifier, required super.child});

  /// এই ভাষার উপর নির্ভর করে — ভাষা বদলালে [context] এর উইজেট রিবিল্ড হবে
  static void watch(m.BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LangScope>();
}

/// সাধারণ [Text] এর মতোই, শুধু লেখাটা বর্তমান ভাষায় অনুবাদ করে দেখায়।
/// (সব ফাইলে `material.dart hide Text` করে এটা ব্যবহার করা হয়)
class Text extends m.StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  }) : span = null;

  const Text.rich(
    m.InlineSpan this.span, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  }) : data = null;

  final String? data;
  final m.InlineSpan? span;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;

  @override
  m.Widget build(m.BuildContext context) {
    LangScope.watch(context);
    if (span != null) {
      return m.Text.rich(span!,
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior);
    }
    return m.Text(tr(data!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior);
  }
}

// ---------------------------------------------------------------------------
// অনুবাদ: প্রথমে পুরো লেখা মেলানো, তারপর "{}" ছাঁচ, তারপর " · " / " — " দিয়ে
// ভেঙে টুকরো টুকরো করে। না মিললে (যেমন দোকানের নাম) যেমন আছে তেমনই থাকে।
// ---------------------------------------------------------------------------

/// বাংলা বা ইংরেজি — বর্তমান ভাষা অনুযায়ী লেখাটা ফেরত দেয়
String tr(String s) {
  if (!isEn || s.isEmpty) return s;
  return _toLatinDigits(_trEn(s));
}

const _bnDigitChars = '০১২৩৪৫৬৭৮৯';

String _toLatinDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = _bnDigitChars.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

final RegExp _bnLetters = RegExp('[ঀ-৿]');

String _trEn(String s) {
  final hit = _exact[s];
  if (hit != null) return hit;
  if (!_bnLetters.hasMatch(s)) return s;
  final lat = _toLatinDigits(s);
  final hit2 = _exact[lat];
  if (hit2 != null) return hit2;
  for (final t in _templates) {
    final mm = t.re.firstMatch(lat);
    if (mm != null) {
      return t.en.replaceAllMapped(RegExp(r'\{(\d)\}'),
          (x) => mm.group(int.parse(x.group(1)!))!);
    }
  }
  for (final sep in const [' · ', '  ·  ', ' — ', '\n']) {
    if (lat.contains(sep)) {
      return lat.split(sep).map(_trEn).join(sep);
    }
  }
  return s;
}

class _Tpl {
  _Tpl(String bn, this.en)
      : re = RegExp(
            '^${bn.split('{}').map(RegExp.escape).join('(.*?)')}\$',
            dotAll: true);
  final RegExp re;
  final String en;
}

// বাংলায় সংখ্যা ইংরেজি করে নেওয়ার পর মেলানো হয়, তাই এখানে {} এ ইংরেজি সংখ্যা আসে
final List<_Tpl> _templates = [
  _Tpl('এই রুটে {}টি আউটলেট আছে। আগে সেগুলো সরান বা মুছুন।',
      'This route has {1} outlets. Remove or delete them first.'),
  _Tpl('{} রুটে {}টি দোকানে ভিজিট', 'Visit {2} shops on route {1}'),
  _Tpl('{}টি দোকান থেকে টাকা নেওয়ার তারিখ', 'Payment due from {1} shops'),
  _Tpl('{}টি দোকানে {} দিনের বেশি ভিজিট/এন্ট্রি নেই',
      '{1} shops with no visit/entry for over {2} days'),
  _Tpl('{}টি দোকানে পরের ভিজিটের বিশেষ নোট আছে',
      '{1} shops have a note for the next visit'),
  _Tpl('{}টি দোকানে বিশেষ নোট আছে', '{1} shops have special notes'),
  _Tpl('মোট দোকান - {} টি, বাকি দোকান - {} টি',
      'Total shops: {1} · Pending: {2}'),
  _Tpl('পরের {}টি দোকান', 'Next {1} shops'),
  _Tpl(' মোট বাকি: {}', ' Total due: {1}'),
  _Tpl('মোট বাকি: {}', 'Total due: {1}'),
  _Tpl('{}টি আউটলেট', '{1} outlets'),
  _Tpl('{}টি দোকান', '{1} shops'),
  _Tpl('{} দিন ধরে ভিজিট/এন্ট্রি নেই', 'No visit/entry for {1} days'),
  _Tpl('{} দিন ধরে নেই', 'No activity for {1} days'),
  _Tpl('শেষ ভিজিট: {} দিন আগে', 'Last visit: {1} days ago'),
  _Tpl('অবশিষ্ট সময় আছে {} দিন', '{1} days left'),
  _Tpl('দিনে {} লাগবে', 'Need {1}/day'),
  _Tpl('{} দিন', '{1} days'),
  _Tpl('মালিক: {}', 'Owner: {1}'),
  _Tpl('ম্যানেজার: {}', 'Manager: {1}'),
  _Tpl('রুট: {}', 'Route: {1}'),
  _Tpl('পরের ভিজিটে মনে রাখুন: {}', 'Remember on next visit: {1}'),
  _Tpl('আগের নোট: {}', 'Previous note: {1}'),
  _Tpl('নোট: {}', 'Note: {1}'),
  _Tpl('বর্তমান বাকি: {}', 'Current due: {1}'),
  _Tpl('ভিজিটের পর বাকি: {}', 'Due after visit: {1}'),
  _Tpl('টাকা দেওয়ার তারিখ: {}', 'Payment date: {1}'),
  _Tpl('টার্গেটঃ {}', 'Target: {1}'),
  _Tpl('বিক্রয় বাকি {}', 'Sales left {1}'),
  _Tpl('কালেকশন বাকি {}', 'Collection left {1}'),
  _Tpl('{} — বিক্রয় {} · কালেকশন {}', '{1} — Sales {2} · Collection {3}'),
  _Tpl('স্পেশাল কমিশন: {}', 'Special: {1}'),
  _Tpl('স্পেশাল কমিশন {}', 'Special {1}'),
  _Tpl('স্পেশাল {}', 'Special {1}'),
  _Tpl('কমিশন: {}', 'Commission: {1}'),
  _Tpl('কমিশন {}', 'Commission {1}'),
  _Tpl('বাকি {}', 'Due {1}'),
  _Tpl('বিক্রয় {}', 'Sales {1}'),
  _Tpl('কালেকশন {}', 'Collection {1}'),
  _Tpl('ত্রুটি: {}', 'Error: {1}'),
  _Tpl('এক্সপোর্ট হয়নি: {}', 'Export failed: {1}'),
  _Tpl('ব্যাকআপ হয়নি: {}', 'Backup failed: {1}'),
  _Tpl('ফেরত আনা যায়নি: {}', 'Restore failed: {1}'),
  _Tpl('{} নম্বর কপি হয়েছে', '{1} number copied'),
];

const Map<String, String> _exact = {
  // --- সাধারণ ---
  'সংরক্ষণ': 'Save',
  'বাতিল': 'Cancel',
  'মুছুন': 'Delete',
  'হ্যাঁ': 'Yes',
  'ঠিক আছে': 'OK',
  'এডিট': 'Edit',
  'কল': 'Call',
  'সব': 'All',
  'বাকি': 'Due',
  'সম্পন্ন': 'Done',
  'নাই': 'None',
  '৭ দিন পর': 'After 7 days',
  'তারিখ': 'Date',
  'নোট': 'Note',
  'টাকা': 'Amount',
  'ধরন': 'Type',
  'খোলা যায়নি': 'Could not open',
  'চালিয়ে যান': 'Continue',
  'সেটিংস': 'Settings',
  'সেটিংসে যান': 'Go to Settings',
  // --- নেভিগেশন ---
  'হোম': 'Home',
  'রুট': 'Route',
  'আউটলেট': 'Outlets',
  'বিক্রয়': 'Sales',
  'এক নজরে': 'Overview',
  // --- ডোনেশন ---
  'ডোনেট': 'Donate',
  'আপনার ডেটা শুধু এই ফোনেই থাকে': 'Your data stays on this phone only',
  'অফলাইন অ্যাপ · ইন্টারনেট লাগে না': 'Offline app · no internet needed',
  'সব সেটিংস এক জায়গায়': 'All settings in one place',
  // --- হোম ---
  'সর্বমোট মার্কেট বাকি': 'Total market due',
  'আজকের রুট': "Today's route",
  'প্রথমে একটি রুট যোগ করুন': 'Add a route first',
  'রুট যোগ করুন': 'Add route',
  'এই রুটে এখনো কোনো আউটলেট নেই': 'No outlets on this route yet',
  'আউটলেট যোগ করুন': 'Add outlet',
  'আজকের সব ভিজিট শেষ! 🎉': "All of today's visits are done! 🎉",
  'দীর্ঘদিন যাওয়া হয়নি': 'Not visited for long',
  'বিশেষ নোট': 'Special notes',
  'বিস্তারিত': 'Details',
  // --- রুট ---
  'আজকের রুটের বিস্তারিতঃ-': "Today's route details:-",
  'এখনো কোনো রুট নেই।\nপ্রথমে রুট যোগ করুন।':
      'No routes yet.\nAdd a route first.',
  'এই রুটে কোনো আউটলেট নেই।\n"আউটলেট" ট্যাব থেকে যোগ করুন।':
      'No outlets on this route.\nAdd them from the "Outlets" tab.',
  'এই তালিকায় কিছু নেই': 'Nothing in this list',
  'অন্য রুটে টাকা চাওয়ার কথা': 'Payment reminders on other routes',
  'এন্ট্রি': 'Entry',
  'ভিজিট': 'Visit',
  'কালেকশন': 'Collection',
  // --- আউটলেট ---
  'নতুন আউটলেট': 'New outlet',
  'নাম, মালিক বা ফোন দিয়ে খুঁজুন': 'Search by name, owner or phone',
  'আগে সেটিংসে গিয়ে রুট যোগ করুন,\nতারপর আউটলেট যোগ করুন।':
      'Go to Settings and add a route first,\nthen add outlets.',
  'এখনো কোনো আউটলেট নেই।\nনিচের বাটন চেপে যোগ করুন।':
      'No outlets yet.\nTap the button below to add one.',
  'কোনো আউটলেট পাওয়া যায়নি': 'No outlets found',
  'আউটলেট পাওয়া যায়নি': 'Outlet not found',
  'এই আউটলেট এবং এর সব বিক্রয়, কালেকশন ও ভিজিটের তথ্য মুছে যাবে। নিশ্চিত?':
      'This outlet and all its sales, collections and visits will be deleted. Are you sure?',
  'আগের বাকি': 'Opening due',
  'বর্তমান বাকি': 'Current due',
  'টাকা চাওয়ার তারিখ: ': 'Payment reminder date: ',
  'সেট করা নেই': 'Not set',
  'এই এন্ট্রি মুছে ফেলবেন?': 'Delete this entry?',
  'কোনো বিক্রয় নেই': 'No sales',
  'কোনো কালেকশন নেই': 'No collections',
  'কোনো ভিজিটের রেকর্ড নেই': 'No visit records',
  // --- বিক্রয় পেজ ---
  'বিক্রয় ও কালেকশন': 'Sales & Collection',
  'নতুন এন্ট্রি': 'New entry',
  'এই মাসের মোট কালেকশন': "This month's total collection",
  'এই মাসের মোট বিক্রয়': "This month's total sales",
  'এই মাসে কোনো কালেকশন নেই': 'No collections this month',
  'এই মাসে কোনো বিক্রয় নেই': 'No sales this month',
  'ছবি বানানো যায়নি': 'Could not create the image',
  'JPG সংরক্ষণ করুন': 'Save JPG',
  'ছবি সংরক্ষণ হয়েছে': 'Image saved',
  'ছবি সংরক্ষণ করা যায়নি': 'Could not save the image',
  'JPG ডাউনলোড': 'Download JPG',
  'মোট কালেকশন': 'Total collection',
  'মোট বিক্রয়': 'Total sales',
  // --- এক নজরে ---
  'এই মাসের টার্গেট সেট করা নেই': "This month's target is not set",
  'টার্গেট সেটিংসে ঠিক করা যায়': 'You can set the target in Settings',
  'কমিশন': 'Commission',
  'স্পেশাল': 'Special',
  'মোট খরচ': 'Total expenses',
  'রুট অনুযায়ী হিসাব': 'By route',
  'এখনো কোনো রুট নেই': 'No routes yet',
  'সবচেয়ে বেশি বাকি': 'Highest dues',
  'কারো কাছে কোনো বাকি নেই 🎉': 'Nobody owes anything 🎉',
  'আমার খরচ (যাবতীয় খরচসমূহ...)': 'My expenses (all expenses...)',
  'কোনো দিনে চাপলে ওই দিনের হিসাব দেখুন': "Tap a day to see that day's figures",
  'বিক্রয় vs কালেকশন': 'Sales vs Collection',
  'এই মাসে এখনো কোনো বিক্রয় বা কালেকশন নেই':
      'No sales or collections this month yet',
  'মাস শেষ': 'Month over',
  ' · মাস শেষ': ' · Month over',
  ' · টার্গেট পূর্ণ!': ' · Target reached!',
  'টার্গেট পূর্ণ!': 'Target reached!',
  'টার্গেট সেট করা নেই': 'Target not set',
  // --- খরচ ---
  'আমার খরচ': 'My expenses',
  'খরচ যোগ': 'Add expense',
  'এই মাসের মোট খরচ': "This month's total expenses",
  'এই মাসে কোনো খরচ নেই': 'No expenses this month',
  'এই খরচ মুছে ফেলবেন?': 'Delete this expense?',
  'নতুন খরচ': 'New expense',
  'যাতায়াত': 'Travel',
  'খাবার': 'Food',
  'মোবাইল বিল': 'Mobile bill',
  'অন্যান্য': 'Other',
  'টাকা *': 'Amount *',
  // --- রুট ম্যানেজমেন্ট ---
  'রুট ও ভিজিটের দিন': 'Routes & visit days',
  'নতুন রুট': 'New route',
  'এখনো কোনো রুট নেই।\nরুট যোগ করে কোন কোন বারে যান তা ঠিক করুন,\nতাহলে হোম ও রুটে নিজে থেকেই আজকের রুট আসবে।':
      'No routes yet.\nAdd a route and set the days you visit it,\nand today\'s route will show up on Home and Route automatically.',
  'দিন ঠিক করা নেই': 'Days not set',
  'রুটের নাম লিখুন': 'Enter the route name',
  'এই রুট মুছে ফেলবেন?': 'Delete this route?',
  'রুট এডিট': 'Edit route',
  'রুটের নাম *': 'Route name *',
  'কোন কোন বারে ভিজিট করেন?': 'Which days do you visit?',
  'রুট মুছুন': 'Delete route',
  'রুট পছন্দ করুন': 'Select route',
  'এখনো কোনো রুট নেই ': 'No routes yet',
  'নতুন রুট যোগ করুন': 'Add new route',
  // --- আউটলেট ফর্ম ---
  'কন্টাক্ট খোলা যায়নি। নম্বরটা হাতে লিখুন।':
      'Could not open contacts. Please type the number.',
  'আউটলেটের নাম লিখুন': 'Enter the outlet name',
  'রুট পছন্দ করুন (না থাকলে "নতুন রুট" চাপুন)':
      'Select a route (tap "New route" if there is none)',
  'আউটলেট এডিট': 'Edit outlet',
  'দোকানের নাম *': 'Shop name *',
  'মালিকের নাম': 'Owner name',
  'ম্যানেজারের নাম': 'Manager name',
  'ফোন নম্বর': 'Phone number',
  'মোবাইলের কন্টাক্ট থেকে নিন': 'Pick from phone contacts',
  'রুট সিলেক্ট করুনঃ- *': 'Select route:- *',
  'রুট বাছুন': 'Choose route',
  'গ্রেড (A+ = বড়, A = মাঝারি, B = ছোট, F = খারাপ)':
      'Grade (A+ = large, A = medium, B = small, F = poor)',
  'আগের বাকি (অ্যাপ ব্যবহারের আগে থেকে থাকলে)':
      'Opening due (if any, from before using the app)',
  'বাজারের নামঃ-': 'Market name:-',
  // --- এন্ট্রি ফর্ম ---
  'বিক্রয়, কালেকশন বা নোট লিখুন। কিছু না থাকলে "ভিজিট" বাটন চাপুন।':
      'Enter a sale, collection or note. If there is nothing, tap the "Visit" button.',
  'বিক্রয় বা কালেকশন লিখুন। কিছু না থাকলে "ভিজিট" বাটন চাপুন।':
      'Enter a sale or collection. If there is none, tap the "Visit" button.',
  'আজকের বিক্রয়': "Today's sales",
  'আজকের কালেকশন': "Today's collection",
  'নোট (কী কথা হলো?)': 'Note (what was discussed?)',
  'পরের তাগাদার তারিখ': 'Next reminder date',
  'এন্ট্রি সংরক্ষণ': 'Save entry',
  'ভিজিট সংরক্ষণ হয়েছে': 'Visit saved',
  'টাকার পরিমাণ লিখুন': 'Enter the amount',
  'কত টাকা পেলেন? *': 'How much did you receive? *',
  'বিক্রয়ের পরিমাণ *': 'Sales amount *',
  'নোট (ঐচ্ছিক)': 'Note (optional)',
  'টাকা চাওয়ার তারিখ': 'Payment reminder date',
  'মাসিক টার্গেট': 'Monthly target',
  'টার্গেট (বিক্রয় ও কালেকশন দুটোর জন্য)': 'Target (for both sales and collection)',
  'এই টার্গেট পরের মাসগুলোতেও চলবে। বদলাতে চাইলে সেই মাসে নতুন করে সেট করুন।':
      'This target will continue in the following months. To change it, set a new one in that month.',
  'আউটলেট খুঁজুন': 'Search outlets',
  'পরের ভিজিটের জন্য বিশেষ নোট (ঐচ্ছিক)': 'Special note for next visit (optional)',
  'সংরক্ষণ করলে আগের নোট মুছে এটা থাকবে':
      'Saving will replace the previous note with this one',
  'পরের বার এই দোকানে গেলে রিমাইন্ডার হিসেবে দেখাবে':
      'Shown as a reminder the next time you visit this shop',
  // --- সেটিংস ---
  'ভাষা': 'Language',
  'অ্যাপের ভাষা': 'App language',
  'ইংরেজি': 'English',
  'বাংলা': 'বাংলা',
  'রুট ও ছুটি': 'Routes & holidays',
  'কোন বারে কোন রুটে যান': 'Which route you visit on which day',
  'সাপ্তাহিক ছুটি (টার্গেটের "দিনে কত লাগবে" হিসাবে বাদ যাবে)':
      'Weekly holiday (excluded from the target\'s "needed per day")',
  'ছুটি নেই': 'No holiday',
  'টার্গেট': 'Target',
  'বিক্রয় ও কালেকশনের টার্গেট সমান ধরা হয়':
      'Sales and collection targets are treated as equal',
  'রিমাইন্ডার': 'Reminders',
  'প্রতিদিনের রিমাইন্ডার': 'Daily reminder',
  'আজ কোন রুটে যেতে হবে ও কার কাছে টাকা চাইতে হবে':
      "Which route to visit today and who to ask for payment",
  'রিমাইন্ডারের সময়': 'Reminder time',
  'দোকানে যাওয়া হচ্ছে না — জানান': 'Shops not being visited — notify me',
  'এত দিন কোনো ভিজিট/এন্ট্রি না থাকলে রিমাইন্ডার ও হোমে দেখাবে':
      'Shown as a reminder and on Home if there is no visit/entry for this many days',
  'বন্ধ': 'Off',
  'নিরাপত্তা': 'Security',
  'অ্যাপ লক (পিন)': 'App lock (PIN)',
  'অ্যাপ খুলতে ৪ সংখ্যার পিন লাগবে': 'A 4-digit PIN is needed to open the app',
  'পিন পরিবর্তন': 'Change PIN',
  'ফিঙ্গারপ্রিন্ট দিয়ে খুলুন': 'Unlock with fingerprint',
  'ডেটা': 'Data',
  'Excel (CSV) এক্সপোর্ট': 'Export to Excel (CSV)',
  'ব্যাকআপ নিন': 'Back up',
  'ফাইলটা Google Drive বা WhatsApp-এ নিজেকে পাঠিয়ে রাখুন':
      'Send the file to yourself on Google Drive or WhatsApp',
  'ব্যাকআপ থেকে ফেরত আনুন': 'Restore from backup',
  'নোটিফিকেশনের অনুমতি পাওয়া যায়নি। ফোনের সেটিংস থেকে অ্যাপের নোটিফিকেশন চালু করুন।':
      'Notification permission was denied. Turn on notifications for the app in your phone settings.',
  'লক বন্ধ করতে বর্তমান পিন দিন': 'Enter the current PIN to turn the lock off',
  'ফিঙ্গারপ্রিন্ট চালু করা যায়নি। ফোনে ফিঙ্গারপ্রিন্ট সেট করা আছে কিনা দেখুন।':
      'Could not enable fingerprint. Check that a fingerprint is set up on the phone.',
  'ব্যাকআপ ফাইল থেকে ডেটা ফেরত আনলে এখনকার সব ডেটা মুছে যাবে। চালিয়ে যাবেন?':
      'Restoring from a backup will erase all current data. Continue?',
  'ডেটা ফেরত আনা হয়েছে': 'Data restored',
  'Salesman Dairy — এক্সপোর্ট': 'Salesman Dairy — Export',
  'Salesman Dairy — ব্যাকআপ': 'Salesman Dairy — Backup',
  // --- লক ---
  'ডায়েরি খুলতে ফিঙ্গারপ্রিন্ট দিন': 'Use your fingerprint to open the diary',
  'ভুল পিন, আবার চেষ্টা করুন': 'Wrong PIN, try again',
  'পিন দিন': 'Enter PIN',
  'ফিঙ্গারপ্রিন্ট': 'Fingerprint',
  'বর্তমান পিন দিন': 'Enter current PIN',
  'দুটো পিন মেলেনি, আবার শুরু করুন': 'The PINs did not match, start again',
  'অ্যাপ লক': 'App lock',
  'নতুন ৪ সংখ্যার পিন দিন': 'Enter a new 4-digit PIN',
  'আবার একই পিন দিন': 'Enter the same PIN again',
  'পিন ভুলে গেলে অ্যাপ খুলতে পারবেন না। তাই নিয়মিত ব্যাকআপ নিয়ে রাখুন।':
      'If you forget the PIN you cannot open the app. Keep regular backups.',
  'ভুল পিন': 'Wrong PIN',
  // --- নোটিফিকেশন ---
  'আজকের কাজ': "Today's tasks",
  'দৈনিক কাজের রিমাইন্ডার': 'Daily task reminder',
  'আজকের ভিজিট, টাকা চাওয়া ও বিশেষ নোটের রিমাইন্ডার':
      "Reminders for today's visits, payments and special notes",
  // --- এক্সপোর্ট/ব্যাকআপ ---
  'মালিক': 'Owner',
  'ম্যানেজার': 'Manager',
  'ফোন': 'Phone',
  'বাজার': 'Market',
  'গ্রেড': 'Grade',
  'স্পেশাল কমিশন': 'Special commission',
  'ভুল ব্যাকআপ ফাইল': 'Invalid backup file',
  // --- তারিখ ---
  'এখনো ভিজিট হয়নি': 'Not visited yet',
  'আজ ভিজিট হয়েছে': 'Visited today',
  'শেষ ভিজিট: গতকাল': 'Last visit: yesterday',
  // --- আগে/পরে ---
  '৳ ': '৳ ',
  'ত্রুটি': 'Error',
};
