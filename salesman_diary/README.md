# সেলসম্যান ডায়েরি (Flutter, অফলাইন)

সেলসম্যানের ব্যক্তিগত ব্যবহারের অ্যান্ড্রয়েড অ্যাপ। সব ডেটা ফোনের ভেতরে (SQLite) থাকে — সার্ভার, ইন্টারনেট বা মাসিক খরচ লাগে না।

## ফিচার
- **আজকের কাজ:** যাদের কাছে আজ যেতে হবে / টাকা চাইতে হবে, আজকের বিক্রি-আদায়-খরচ
- **কাস্টমার:** নাম, দোকান, ফোন, ঠিকানা, নোট; সার্চ; এক ট্যাপে কল ও WhatsApp
- **অর্ডার, আদায়, ভিজিট নোট:** প্রতিটি কাস্টমারের আলাদা হিসাব ও বাকি
- **প্রোডাক্ট সাজেশন:** আগে বিক্রি করা প্রোডাক্টের নাম লিখতে গেলে সাজেস্ট করে, বাছলে সর্বশেষ দাম বসে যায়। তালিকা সেটিংস → "প্রোডাক্ট ও দাম"-এ হাতেও এডিট করা যায়
- **রিমাইন্ডার নোটিফিকেশন:** প্রতিদিন আপনার ঠিক করা সময়ে (ডিফল্ট সকাল ৮টা) "আজ ক’জনের কাছে ভিজিট ও ক’জনের কাছে টাকা চাইতে হবে" জানায়। কাজ না থাকলে সেদিন আসে না
- **অ্যাপ লক:** ৪ সংখ্যার পিন + ঐচ্ছিক ফিঙ্গারপ্রিন্ট। ৬০ সেকেন্ডের বেশি ব্যাকগ্রাউন্ডে থাকলে আবার লক হয় (কল/WhatsApp করে ফিরলে বারবার পিন চায় না)
- **খরচ:** যাতায়াত, খাবার, মোবাইল বিল ইত্যাদি (মাসভিত্তিক)
- **রিপোর্ট:** মাসিক বিক্রি/আদায়/খরচ/নিট, মোট বাকি, টার্গেট বনাম অর্জন, সবচেয়ে বেশি বাকি
- **ব্যাকআপ:** Excel (CSV) এক্সপোর্ট, ডেটাবেস ব্যাকআপ ও ফেরত আনা (ফেরত আনলেও আপনার পিন ঠিক থাকে)

## ফোল্ডার স্ট্রাকচার
```
salesman_diary/
├── pubspec.yaml
└── lib/
    ├── main.dart            # অ্যাপ শুরু, থিম, লক গেট
    ├── db.dart              # SQLite ডেটাবেস ও সব কোয়েরি
    ├── utils.dart           # বাংলা সংখ্যা/তারিখ, কল, WhatsApp
    ├── widgets.dart         # কমন উইজেট
    ├── sheets.dart          # ফর্ম (কাস্টমার, অর্ডার, আদায়, ভিজিট, খরচ, প্রোডাক্ট)
    ├── notifications.dart   # রিমাইন্ডার নোটিফিকেশন
    ├── lock.dart            # পিন, ফিঙ্গারপ্রিন্ট, লক স্ক্রিন
    └── screens/
        ├── home.dart            # নিচের ৪টি ট্যাব
        ├── today.dart           # আজ
        ├── customers.dart       # কাস্টমার তালিকা
        ├── customer_detail.dart # কাস্টমারের বিস্তারিত
        ├── expenses.dart        # খরচ
        ├── report.dart          # রিপোর্ট ও ব্যাকআপ
        ├── products.dart        # প্রোডাক্ট ও দাম
        └── settings.dart        # রিমাইন্ডার, অ্যাপ লক
```

## ডেটাবেস
`customers`, `orders`, `payments`, `visits`, `expenses`, `products`, `settings`।
**বাকি = মোট অর্ডার − মোট আদায়** (প্রতিবার হিসাব করা হয়)।

## চালানোর নিয়ম
1. [Flutter SDK](https://docs.flutter.dev/get-started/install) ইনস্টল করুন (Dart ≥ 3.3)।
2. অ্যান্ড্রয়েড ফাইল তৈরি করুন (`lib/` ও `pubspec.yaml` ওভাররাইট হয় না):
   ```
   cd salesman_diary
   flutter create . --platforms=android --project-name salesman_diary
   flutter pub get
   ```
3. **Android সেটআপ** (নিচের ৩.ক–৩.ঘ সব করুন):

### ৩.ক `android/app/src/main/AndroidManifest.xml`
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
`<application>`-এর ভেতরে, `<activity>`-এর পরে (ফোন রিস্টার্টের পরও রিমাইন্ডার ঠিক থাকার জন্য):
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

### ৩.খ নোটিফিকেশনের জন্য Java desugaring
`android/app/build.gradle` (বা `build.gradle.kts`) এ:

Groovy (`build.gradle`):
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
Kotlin DSL (`build.gradle.kts`):
```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

### ৩.গ ফিঙ্গারপ্রিন্টের জন্য (ঐচ্ছিক — পিন এমনিতেই কাজ করবে)
`android/app/src/main/kotlin/.../MainActivity.kt`:
```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```
ফিঙ্গারপ্রিনে এরর এলে `local_auth` প্যাকেজের Android সেটআপ ডকুমেন্ট দেখুন (থিম সংক্রান্ত শর্ত থাকতে পারে)। এটা ঠিক না হলে অ্যাপ শুধু পিন দিয়েই চলবে।

### ৩.ঘ চালান
```
flutter run                      # ফোনে চালাতে
flutter build apk --release      # APK বানাতে
```
APK: `build/app/outputs/flutter-apk/app-release.apk`

## ব্যবহারের টিপস
- **প্রথমবার** অ্যাপ খুললে নোটিফিকেশনের অনুমতি চাইবে — "Allow" দিন।
- রিমাইন্ডার চলে ফোনের অ্যালার্ম দিয়ে। কিছু ফোনে (Xiaomi, Oppo, Vivo, Realme ইত্যাদি) ব্যাটারি সেভার অ্যাপ বন্ধ করে দিলে রিমাইন্ডার আসে না — অ্যাপের জন্য Battery → "No restrictions" / "Autostart" চালু করুন।
- সময় ঠিক সেকেন্ডে নাও আসতে পারে (কয়েক মিনিট দেরি হতে পারে)।
- পিন ভুলে গেলে অ্যাপ খোলার উপায় নেই (ডেটা বাঁচাতে ব্যাকআপ ফাইল রাখুন; অ্যাপ নতুন করে ইনস্টল করে "ব্যাকআপ থেকে ফেরত" দিলে ডেটা ফিরবে)।
- পিন লক ডেটাবেস ফাইল এনক্রিপ্ট করে না; এটা অন্যের হাতে ফোন গেলে অ্যাপ খোলা ঠেকানোর জন্য।

## পরবর্তী আপডেটের আইডিয়া
- ডেটাবেস এনক্রিপশন (SQLCipher)
- কাস্টমারের ছবি/দোকানের লোকেশন (GPS)
- মাসিক রিপোর্টের চার্ট
