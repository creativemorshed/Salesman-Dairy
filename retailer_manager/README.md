# রিটেলার ম্যানেজার (Flutter, অফলাইন)

মার্কেটে মার্কেটে ঘুরে দোকান (আউটলেট) ভিজিট করা সেলসম্যানের ব্যক্তিগত অ্যান্ড্রয়েড অ্যাপ।
**বিক্রি · আদায় · মার্কেট বাকি · টার্গেট · অর্জন** — সব ফোনের ভেতরে (SQLite), ইন্টারনেট বা সার্ভার লাগে না।
প্রোডাক্টের নাম/দাম নেই, GPS নেই — শুধু টাকার অংক।

## কাজের ধারা
1. **মার্কেট যোগ করুন** (যেমন চন্দনাইশ) এবং কোন কোন বারে সেখানে যান তা ঠিক করুন।
2. মার্কেটের ভেতরে **আউটলেট যোগ করুন** (নাম, মালিক, ফোন, গ্রেড A/B/C, আগের বাকি)।
3. **আজকের রুট** ট্যাবে আজকের বারের মার্কেটের সব দোকান আসে (যাদের বাকি আছে তারা আগে)।
4. দোকানে গিয়ে **"ভিজিট করুন"** চাপুন → আজকের বিক্রি, আদায়, নোট, পরের তাগাদার তারিখ — এক ফর্মে।
5. **হোম** ও **প্রগ্রেস** ট্যাবে বাকি, টার্গেট বনাম অর্জন নিজে থেকেই হিসাব হয়।

## ট্যাব
| ট্যাব | কী আছে |
|---|---|
| **হোম** | তারিখ ও মার্কেট, মার্কেট বাকির পরিমাণ, মোট/বাকি দোকান ও প্রগ্রেস বার, পরের ৩টি দোকান, বিস্তারিত বাটন, মাসের বিক্রি ও আদায়ের টার্গেট (দিনে কত লাগবে সহ) |
| **আজকের রুট** | আজকের মার্কেটের সব আউটলেট, সব/বাকি/সম্পন্ন ফিল্টার, কল ও WhatsApp, ভিজিট এন্ট্রি, অন্য মার্কেটের যাদের টাকা দেওয়ার তারিখ হয়ে গেছে |
| **আউটলেট** | সার্চ, মার্কেট ফিল্টার, প্রতিটির বাকি; ভেতরে বিক্রি/আদায়/ভিজিটের ইতিহাস ও হিসাব |
| **বিক্রি** | মাসভিত্তিক বিক্রি ও আদায়ের তালিকা (তারিখ অনুযায়ী ভাগ করা), নতুন এন্ট্রি |
| **প্রগ্রেস** | বিক্রি/আদায়ের টার্গেট বনাম অর্জন, কাজের দিন বাকি, দিনভিত্তিক বিক্রির চার্ট, মার্কেট অনুযায়ী হিসাব, সবচেয়ে বেশি বাকি, আমার খরচ |

**সেটিংস** (হোমের উপরে গিয়ার আইকন): মার্কেট ও ভিজিটের দিন, সাপ্তাহিক ছুটি, প্রতিদিনের রিমাইন্ডার নোটিফিকেশন, পিন/ফিঙ্গারপ্রিন্ট লক, CSV এক্সপোর্ট, ব্যাকআপ ও ফেরত আনা।

## হিসাবের নিয়ম
- **বাকি = আগের বাকি + মোট বিক্রি − মোট আদায়** (প্রতিবার হিসাব হয়)
- **মার্কেট বাকি** = ওই মার্কেটের সব আউটলেটের বাকির যোগফল
- **দিনে কত লাগবে** = (টার্গেট − অর্জন) ÷ মাসের বাকি কর্মদিবস (আজকসহ; সাপ্তাহিক ছুটি বাদ, ডিফল্ট শুক্রবার)
- টার্গেট একবার সেট করলে পরের মাসেও চলে; বদলাতে চাইলে সেই মাসে নতুন করে সেট করুন
- আজকের মার্কেট = আজকের বারে যে মার্কেটে যাওয়ার কথা। হোমের "মার্কেটঃ- …" চিপ চেপে অন্য মার্কেট দেখা যায়

## ফোল্ডার স্ট্রাকচার
```
retailer_manager/
├── pubspec.yaml
└── lib/
    ├── main.dart            # থিম, লক গেট, নোটিফিকেশন চালু
    ├── db.dart              # SQLite: markets, outlets, sales, collections, visits, expenses, targets
    ├── state.dart           # বর্তমান মার্কেট ও ট্যাব
    ├── utils.dart           # বাংলা সংখ্যা, লাখ-হিসাবে টাকা (৳5,00,000), তারিখ, কল/WhatsApp
    ├── widgets.dart         # AppCard, TargetBar, GradeBadge, MarketChip ইত্যাদি
    ├── sheets.dart          # সব ফর্ম (মার্কেট, আউটলেট, ভিজিট, বিক্রি/আদায়, টার্গেট, খরচ)
    ├── notifications.dart   # প্রতিদিনের রিমাইন্ডার
    ├── lock.dart            # পিন ও ফিঙ্গারপ্রিন্ট
    └── screens/
        ├── home.dart  dashboard.dart  route_screen.dart  outlets.dart
        ├── outlet_detail.dart  sales.dart  progress.dart
        └── markets.dart  settings.dart  expenses.dart
```

## চালানোর নিয়ম
1. [Flutter SDK](https://docs.flutter.dev/get-started/install) ইনস্টল করুন (Dart ≥ 3.3)।
2. অ্যান্ড্রয়েড ফাইল তৈরি করুন (`lib/` ও `pubspec.yaml` ওভাররাইট হয় না):
   ```
   cd retailer_manager
   flutter create . --platforms=android --project-name retailer_manager
   flutter pub get
   ```
3. **Android সেটআপ:**

### ক. `android/app/src/main/AndroidManifest.xml`
`<manifest>`-এর ভেতরে, `<application>`-এর আগে:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>

<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
</queries>
```
`<application>`-এর ভেতরে, `<activity>`-এর পরে:
```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```
অ্যাপের নাম বাংলায় দেখাতে `<application android:label="রিটেলার ম্যানেজার" ...>` করুন।

### খ. নোটিফিকেশনের জন্য Java desugaring (`android/app/build.gradle` বা `.kts`)
Groovy:
```gradle
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```
Kotlin DSL:
```kotlin
android { compileOptions { isCoreLibraryDesugaringEnabled = true } }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") }
```

### গ. ফিঙ্গারপ্রিন্টের জন্য (ঐচ্ছিক — পিন এমনিতেই কাজ করবে)
`MainActivity.kt`:
```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```
ফিঙ্গারপ্রিন্টে এরর এলে `local_auth` প্যাকেজের Android সেটআপ দেখুন (থিম সংক্রান্ত শর্ত থাকতে পারে)।

### ঘ. চালান
```
flutter run                      # ফোনে চালাতে
flutter build apk --release      # APK: build/app/outputs/flutter-apk/app-release.apk
```

## টিপস ও সীমাবদ্ধতা
- প্রথমবার অ্যাপ খুললে নোটিফিকেশনের অনুমতি চাইবে — "Allow" দিন।
- Xiaomi/Oppo/Vivo/Realme ফোনে ব্যাটারি সেভার রিমাইন্ডার আটকে দিতে পারে — অ্যাপের জন্য ব্যাটারি "No restrictions" করুন।
- পিন ভুলে গেলে অ্যাপ খোলার উপায় নেই। নিয়মিত ব্যাকআপ নিন; নতুন করে ইনস্টল করে "ব্যাকআপ থেকে ফেরত" দিলে ডেটা ফিরবে।
- এই অ্যাপ আগের "সেলসম্যান ডায়েরি"-র ডেটা নেয় না (আলাদা ডেটাবেস)। পুরনো কাস্টমারদের আউটলেট হিসেবে নতুন করে যোগ করে "আগের বাকি" ঘরে বাকির অংক বসান।
- আউটলেট মুছলে তার সব বিক্রি-আদায়ও মুছে যায়। আউটলেট থাকা মার্কেট মোছা যায় না।

## পরবর্তী আপডেটের আইডিয়া
- ডেটাবেস এনক্রিপশন (SQLCipher)
- মার্কেট/মাস অনুযায়ী আলাদা টার্গেট
- আউটলেটের ছবি, ব্যালেন্স স্টেটমেন্ট শেয়ার (টেক্সট)
