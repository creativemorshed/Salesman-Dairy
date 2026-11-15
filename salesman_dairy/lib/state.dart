import 'package:flutter/foundation.dart';

/// হোম/রুট ট্যাবে এখন কোন মার্কেট দেখানো হচ্ছে (null = আজকের নির্ধারিত মার্কেট)
final ValueNotifier<int?> selectedMarket = ValueNotifier<int?>(null);

/// নিচের নেভিগেশনের বর্তমান ট্যাব (হোম থেকে "বিস্তারিত" চাপলে রুট ট্যাবে যায়)
final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);
