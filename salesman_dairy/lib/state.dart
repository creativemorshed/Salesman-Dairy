import 'package:flutter/foundation.dart';

/// হোম/রুট ট্যাবে এখন কোন রুট দেখানো হচ্ছে (null = আজকের নির্ধারিত রুট)
final ValueNotifier<int?> selectedMarket = ValueNotifier<int?>(null);

/// নিচের নেভিগেশনের বর্তমান ট্যাব (হোম থেকে "বিস্তারিত" চাপলে রুট ট্যাবে যায়)
final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

/// কত দিন কোনো ভিজিট/এন্ট্রি না থাকলে দোকানটা "দীর্ঘদিন যাওয়া হয়নি" ধরা হবে
/// (০ = বন্ধ)। সেটিংসে বদলানো যায়; অ্যাপ চালুর সময় ডেটাবেস থেকে পড়া হয়।
final ValueNotifier<int> staleDays = ValueNotifier<int>(7);
