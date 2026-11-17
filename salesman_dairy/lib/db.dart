import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'utils.dart';

typedef Rec = Map<String, Object?>;

/// পুরো অ্যাপের ডেটাবেস (SQLite, ফোনেই থাকে — ইন্টারনেট লাগে না)
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  /// কোনো ডেটা বদলালে এটা বাড়ে, স্ক্রিনগুলো অটো রিফ্রেশ হয়
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  Database? _db;

  void _bump() => changes.value++;

  Future<String> dbPath() async =>
      p.join(await getDatabasesPath(), 'salesman_dairy.db');

  Future<Database> get _d async => _db ??= await _open();

  Future<Database> _open() async {
    return openDatabase(
      await dbPath(),
      version: 4,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        // রুট: days = ভিজিটের বারগুলো ("1,3,6" = সোম, বুধ, শনি)
        await db.execute('''
CREATE TABLE markets(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  days TEXT NOT NULL DEFAULT ''
)''');
        // আউটলেট (দোকান): grade = A+/A/B/F, opening_due = আগে থেকে থাকা বাকি
        await db.execute('''
CREATE TABLE outlets(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  market_id INTEGER NOT NULL REFERENCES markets(id),
  name TEXT NOT NULL,
  owner TEXT, phone TEXT, address TEXT, note TEXT,
  grade TEXT NOT NULL DEFAULT 'B',
  opening_due REAL NOT NULL DEFAULT 0,
  pay_reminder TEXT,
  next_note TEXT,
  manager TEXT,
  created_at TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE sales(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  amount REAL NOT NULL,
  commission REAL NOT NULL DEFAULT 0,
  special_commission REAL NOT NULL DEFAULT 0,
  note TEXT
)''');
        await db.execute('''
CREATE TABLE collections(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  amount REAL NOT NULL,
  note TEXT
)''');
        await db.execute('''
CREATE TABLE visits(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  note TEXT
)''');
        await db.execute('''
CREATE TABLE expenses(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  note TEXT
)''');
        await db.execute('''
CREATE TABLE targets(
  month TEXT PRIMARY KEY,
  sales REAL NOT NULL DEFAULT 0,
  collection REAL NOT NULL DEFAULT 0
)''');
        await db.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
        await db.execute('CREATE INDEX i_outlets_m ON outlets(market_id)');
        await db.execute('CREATE INDEX i_sales_o ON sales(outlet_id)');
        await db.execute('CREATE INDEX i_sales_d ON sales(date)');
        await db.execute('CREATE INDEX i_coll_o ON collections(outlet_id)');
        await db.execute('CREATE INDEX i_coll_d ON collections(date)');
        await db.execute('CREATE INDEX i_vis_o ON visits(outlet_id)');
        await db.execute('CREATE INDEX i_vis_d ON visits(date)');
        await db.execute('CREATE INDEX i_exp_d ON expenses(date)');
      },
      onUpgrade: (db, oldV, newV) async {
        // v2: পরের ভিজিটের বিশেষ নোট
        if (oldV < 2) {
          await db.execute('ALTER TABLE outlets ADD COLUMN next_note TEXT');
        }
        // v3: প্রতিটি বিক্রির কমিশন ও স্পেশাল কমিশন
        if (oldV < 3) {
          await db.execute(
              'ALTER TABLE sales ADD COLUMN commission REAL NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE sales ADD COLUMN special_commission REAL NOT NULL DEFAULT 0');
        }
        // v4: ম্যানেজারের নাম
        if (oldV < 4) {
          await db.execute('ALTER TABLE outlets ADD COLUMN manager TEXT');
        }
      },
    );
  }

  // বাকি = আগের বাকি + মোট বিক্রি − মোট আদায়
  // প্রথম `?` = আজকের তারিখ (visited_today এর জন্য)
  static const _outletCols = '''
o.*, m.name AS market_name,
(o.opening_due
  + IFNULL((SELECT SUM(amount) FROM sales s WHERE s.outlet_id=o.id),0)
  - IFNULL((SELECT SUM(amount) FROM collections c WHERE c.outlet_id=o.id),0)) AS due,
(SELECT MAX(date) FROM visits v WHERE v.outlet_id=o.id) AS last_visit,
MAX(
  IFNULL((SELECT MAX(date) FROM visits v3 WHERE v3.outlet_id=o.id),''),
  IFNULL((SELECT MAX(date) FROM sales s3 WHERE s3.outlet_id=o.id),''),
  IFNULL((SELECT MAX(date) FROM collections c3 WHERE c3.outlet_id=o.id),''),
  o.created_at) AS last_activity,
EXISTS(SELECT 1 FROM visits v2 WHERE v2.outlet_id=o.id AND v2.date=?) AS visited_today''';

  static const _outletFrom =
      'FROM outlets o JOIN markets m ON m.id=o.market_id';

  static const _marketDue = '''
((SELECT IFNULL(SUM(o.opening_due),0) FROM outlets o WHERE o.market_id=m.id)
 + (SELECT IFNULL(SUM(s.amount),0) FROM sales s JOIN outlets o ON o.id=s.outlet_id WHERE o.market_id=m.id)
 - (SELECT IFNULL(SUM(c.amount),0) FROM collections c JOIN outlets o ON o.id=c.outlet_id WHERE o.market_id=m.id))''';

  static const _marketCols = '''
m.*,
(SELECT COUNT(*) FROM outlets o WHERE o.market_id=m.id) AS outlet_count,
$_marketDue AS due''';

  // ---------------- রুট ----------------
  /// সবসময় বার অনুযায়ী সাজানো: শনিবার, রবিবার, সোমবার … শুক্রবার
  Future<List<Rec>> markets() async => sortMarkets(await (await _d)
      .rawQuery('SELECT $_marketCols FROM markets m'));

  /// নির্দিষ্ট বারে (১=সোম…৭=রবি) যেসব রুটে যাওয়ার কথা
  Future<List<Rec>> marketsOnDay(int weekday) async => sortMarkets(
      await (await _d).rawQuery(
        "SELECT $_marketCols FROM markets m WHERE (',' || m.days || ',') LIKE ?",
        ['%,$weekday,%'],
      ));

  /// হোম/রুটে দেখানোর রুট: বাছাই করা → আজকের নির্ধারিত → প্রথমটা
  Future<Rec?> activeMarket(int? selectedId) async {
    final all = await markets();
    if (all.isEmpty) return null;
    if (selectedId != null) {
      for (final m in all) {
        if (m['id'] == selectedId) return m;
      }
    }
    final w = DateTime.now().weekday;
    for (final m in all) {
      if (hasDay(m['days'] as String, w)) return m;
    }
    return all.first;
  }

  Future<void> saveMarket(String name, List<int> days, {int? id}) async {
    final sorted = [...days]..sort();
    final data = {'name': name, 'days': sorted.join(',')};
    final d = await _d;
    if (id == null) {
      await d.insert('markets', data);
    } else {
      await d.update('markets', data, where: 'id=?', whereArgs: [id]);
    }
    _bump();
  }

  /// রুটে আউটলেট থাকলে মোছা যাবে না
  Future<void> deleteMarket(int id) async {
    final d = await _d;
    final n = Sqflite.firstIntValue(await d.rawQuery(
            'SELECT COUNT(*) FROM outlets WHERE market_id=?', [id])) ??
        0;
    if (n > 0) {
      throw StateError('এই রুটে $nটি আউটলেট আছে। আগে সেগুলো সরান বা মুছুন।');
    }
    await d.delete('markets', where: 'id=?', whereArgs: [id]);
    _bump();
  }

  // ---------------- আউটলেট ----------------
  Future<List<Rec>> outlets({int? marketId, String q = ''}) async {
    final where = <String>[];
    final args = <Object?>[today()];
    if (marketId != null) {
      where.add('o.market_id=?');
      args.add(marketId);
    }
    final qq = q.trim();
    if (qq.isNotEmpty) {
      where.add('(o.name LIKE ? OR o.owner LIKE ? OR o.phone LIKE ?)');
      args.addAll(['%$qq%', '%$qq%', '%$qq%']);
    }
    return (await _d).rawQuery(
      'SELECT $_outletCols $_outletFrom '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY (due <= 0), due DESC, o.name COLLATE NOCASE',
      args,
    );
  }

  /// রুটের রুট: ভিজিট বাকিরা আগে; প্রত্যেক দলে বেশি বাকি আগে, বাকি ০ হলে সবার নিচে
  Future<List<Rec>> route(int marketId) async => (await _d).rawQuery(
        'SELECT $_outletCols $_outletFrom WHERE o.market_id=? '
        'ORDER BY visited_today, (due <= 0), due DESC, '
        "CASE o.grade WHEN 'A+' THEN 0 WHEN 'A' THEN 1 WHEN 'F' THEN 3 ELSE 2 END, "
        'o.name COLLATE NOCASE',
        [today(), marketId],
      );

  Future<Rec?> outlet(int id) async {
    final r = await (await _d).rawQuery(
        'SELECT $_outletCols $_outletFrom WHERE o.id=?', [today(), id]);
    return r.isEmpty ? null : r.first;
  }

  Future<int> saveOutlet(Rec data, {int? id}) async {
    final d = await _d;
    int rid;
    if (id == null) {
      rid = await d.insert('outlets', {...data, 'created_at': today()});
    } else {
      await d.update('outlets', data, where: 'id=?', whereArgs: [id]);
      rid = id;
    }
    _bump();
    return rid;
  }

  Future<void> deleteOutlet(int id) async {
    await (await _d).delete('outlets', where: 'id=?', whereArgs: [id]);
    _bump();
  }

  Future<void> setPayReminder(int id, String? value) async {
    await (await _d).update('outlets', {'pay_reminder': value},
        where: 'id=?', whereArgs: [id]);
    _bump();
  }

  /// যাদের টাকা দেওয়ার তারিখ হয়ে গেছে এবং বাকি আছে
  Future<List<Rec>> promises(String date) async => (await _d).rawQuery(
        'SELECT * FROM (SELECT $_outletCols $_outletFrom '
        'WHERE o.pay_reminder IS NOT NULL AND o.pay_reminder <= ?) '
        'WHERE due > 0 ORDER BY pay_reminder',
        [today(), date],
      );

  /// N দিন বা তার বেশি কোনো ভিজিট/বিক্রি/আদায় নেই এমন আউটলেট (সবচেয়ে পুরনো আগে)
  Future<List<Rec>> staleOutlets(int days, {String? asOf}) async =>
      (await _d).rawQuery(
        'SELECT * FROM (SELECT $_outletCols $_outletFrom) '
        "WHERE last_activity <= date(?, '-$days day') "
        'ORDER BY last_activity, due DESC',
        [today(), asOf ?? today()],
      );

  /// পরের ভিজিটের বিশেষ নোট আছে এমন আউটলেট
  Future<List<Rec>> notedOutlets() async => (await _d).rawQuery(
        'SELECT * FROM (SELECT $_outletCols $_outletFrom) '
        "WHERE next_note IS NOT NULL AND next_note <> '' ORDER BY name",
        [today()],
      );

  Future<List<Rec>> topDue(int limit) async => (await _d).rawQuery(
        'SELECT * FROM (SELECT $_outletCols $_outletFrom) '
        'WHERE due > 0 ORDER BY due DESC LIMIT ?',
        [today(), limit],
      );

  // ---------------- বিক্রি / আদায় / ভিজিট ----------------
  static const _entryTables = {'sales', 'collections'};

  void _checkEntryTable(String t) {
    if (!_entryTables.contains(t)) throw ArgumentError('invalid table');
  }

  Future<List<Rec>> entries(String table, int outletId) async {
    _checkEntryTable(table);
    return (await _d).query(table,
        where: 'outlet_id=?',
        whereArgs: [outletId],
        orderBy: 'date DESC, id DESC');
  }

  Future<List<Rec>> visits(int outletId) async => (await _d).query('visits',
      where: 'outlet_id=?',
      whereArgs: [outletId],
      orderBy: 'date DESC, id DESC');

  /// মাসের সব এন্ট্রি (আউটলেট ও রুটের নামসহ)
  Future<List<Rec>> entriesBetween(String table, String from, String to) async {
    _checkEntryTable(table);
    return (await _d).rawQuery(
      'SELECT t.*, o.name AS outlet_name, m.name AS market_name FROM $table t '
      'JOIN outlets o ON o.id=t.outlet_id JOIN markets m ON m.id=o.market_id '
      'WHERE t.date>=? AND t.date<? ORDER BY t.date DESC, t.id DESC',
      [from, to],
    );
  }

  /// ভিজিট এন্ট্রি: ভিজিট + বিক্রি + আদায় একসাথে সংরক্ষণ
  /// ভিজিট (ও থাকলে বিক্রি/আদায়) সংরক্ষণ; ভিজিটের id ফেরত দেয়।
  /// keepFollowUp = true হলে তাগাদার তারিখ ও বিশেষ নোট যেমন আছে তেমনই থাকে।
  Future<int> addVisit({
    required int outletId,
    required String date,
    double sale = 0,
    double commission = 0,
    double specialCommission = 0,
    double collected = 0,
    String note = '',
    String? payReminder,
    String? nextNote,
    bool keepFollowUp = false,
  }) async {
    final d = await _d;
    late int visitId;
    await d.transaction((t) async {
      visitId = await t.insert(
          'visits', {'outlet_id': outletId, 'date': date, 'note': note});
      if (sale > 0) {
        await t.insert('sales', {
          'outlet_id': outletId,
          'date': date,
          'amount': sale,
          'commission': commission,
          'special_commission': specialCommission,
          'note': note
        });
      }
      if (collected > 0) {
        await t.insert('collections', {
          'outlet_id': outletId,
          'date': date,
          'amount': collected,
          'note': note
        });
      }
      // ভিজিট হয়ে গেলে আগের বিশেষ নোট শেষ; নতুন নোট (থাকলে) পরের ভিজিটের জন্য
      if (!keepFollowUp) {
        final nn = (nextNote ?? '').trim();
        await t.update('outlets',
            {'pay_reminder': payReminder, 'next_note': nn.isEmpty ? null : nn},
            where: 'id=?', whereArgs: [outletId]);
      }
    });
    _bump();
    return visitId;
  }

  /// শুধু বিক্রি বা শুধু আদায় যোগ করা
  Future<void> addEntry({
    required String table,
    required int outletId,
    required String date,
    required double amount,
    double commission = 0,
    double specialCommission = 0,
    String note = '',
    bool updateReminder = false,
    String? payReminder,
  }) async {
    _checkEntryTable(table);
    final d = await _d;
    await d.transaction((t) async {
      await t.insert(table, {
        'outlet_id': outletId,
        'date': date,
        'amount': amount,
        if (table == 'sales') 'commission': commission,
        if (table == 'sales') 'special_commission': specialCommission,
        'note': note,
      });
      if (updateReminder) {
        await t.update('outlets', {'pay_reminder': payReminder},
            where: 'id=?', whereArgs: [outletId]);
      }
    });
    _bump();
  }

  Future<void> deleteRow(String table, int id) async {
    const allowed = {'sales', 'collections', 'visits', 'expenses'};
    if (!allowed.contains(table)) throw ArgumentError('invalid table');
    await (await _d).delete(table, where: 'id=?', whereArgs: [id]);
    _bump();
  }

  // ---------------- খরচ ----------------
  Future<List<Rec>> expenses(String from, String to) async =>
      (await _d).query('expenses',
          where: 'date>=? AND date<?',
          whereArgs: [from, to],
          orderBy: 'date DESC, id DESC');

  Future<void> addExpense({
    required String date,
    required String category,
    required double amount,
    String note = '',
  }) async {
    await (await _d).insert('expenses', {
      'date': date,
      'category': category,
      'amount': amount,
      'note': note,
    });
    _bump();
  }

  // ---------------- যোগফল ----------------
  Future<double> _sum(String sql, [List<Object?> args = const []]) async {
    final r = await (await _d).rawQuery(sql, args);
    final v = r.first.values.first;
    return v == null ? 0 : (v as num).toDouble();
  }

  /// from (অন্তর্ভুক্ত) থেকে to (বাদ) পর্যন্ত
  Future<double> sales(String from, String to) => _sum(
      'SELECT SUM(amount) FROM sales WHERE date>=? AND date<?', [from, to]);

  /// মাসের মোট কমিশন
  Future<double> commission(String from, String to) => _sum(
      'SELECT SUM(commission) FROM sales WHERE date>=? AND date<?', [from, to]);

  /// মাসের মোট স্পেশাল কমিশন
  Future<double> specialCommission(String from, String to) => _sum(
      'SELECT SUM(special_commission) FROM sales WHERE date>=? AND date<?',
      [from, to]);

  Future<double> collected(String from, String to) => _sum(
      'SELECT SUM(amount) FROM collections WHERE date>=? AND date<?',
      [from, to]);

  Future<double> spent(String from, String to) => _sum(
      'SELECT SUM(amount) FROM expenses WHERE date>=? AND date<?', [from, to]);

  Future<double> totalDue() => _sum(
      'SELECT IFNULL((SELECT SUM(opening_due) FROM outlets),0) + '
      'IFNULL((SELECT SUM(amount) FROM sales),0) - '
      'IFNULL((SELECT SUM(amount) FROM collections),0)');

  Future<int> visitCount(String from, String to) async =>
      Sqflite.firstIntValue(await (await _d).rawQuery(
          'SELECT COUNT(*) FROM visits WHERE date>=? AND date<?',
          [from, to])) ??
      0;

  /// রুট ভিত্তিক: মাসের বিক্রি, আদায় ও এখনকার মোট বাকি
  Future<List<Rec>> marketStats(String from, String to) async =>
      sortMarkets(await (await _d).rawQuery(
        '''
SELECT m.id, m.name,
 (SELECT IFNULL(SUM(s.amount),0) FROM sales s JOIN outlets o ON o.id=s.outlet_id
   WHERE o.market_id=m.id AND s.date>=? AND s.date<?) AS sales,
 (SELECT IFNULL(SUM(c.amount),0) FROM collections c JOIN outlets o ON o.id=c.outlet_id
   WHERE o.market_id=m.id AND c.date>=? AND c.date<?) AS collected,
 $_marketDue AS due
FROM markets m''',
        [from, to, from, to],
      ));

  // ---------------- টার্গেট ----------------
  /// ওই মাস বা তার আগের সর্বশেষ সেট করা টার্গেট (নতুন মাসে আগেরটাই চলে)
  Future<Rec?> targetFor(String month) async {
    final r = await (await _d).rawQuery(
        'SELECT * FROM targets WHERE month<=? ORDER BY month DESC LIMIT 1',
        [month]);
    return r.isEmpty ? null : r.first;
  }

  Future<void> setTarget(String month, double sales, double collection) async {
    await (await _d).insert(
        'targets', {'month': month, 'sales': sales, 'collection': collection},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _bump();
  }

  // ---------------- সেটিংস ----------------
  Future<String?> getSetting(String key) async {
    final r = await (await _d)
        .query('settings', where: 'key=?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await (await _d).insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _bump();
  }

  Future<void> deleteSetting(String key) async {
    await (await _d).delete('settings', where: 'key=?', whereArgs: [key]);
    _bump();
  }

  // ---------------- এক্সপোর্ট / ব্যাকআপ ----------------
  Future<Map<String, String>> csvExports() async {
    final d = await _d;

    String esc(Object? v) {
      final s = (v ?? '').toString();
      return (s.contains(',') || s.contains('"') || s.contains('\n'))
          ? '"${s.replaceAll('"', '""')}"'
          : s;
    }

    Future<String> table(
        String sql, List<Object?> args, List<String> head, List<String> keys) async {
      final rows = await d.rawQuery(sql, args);
      // BOM থাকলে Excel-এ বাংলা ঠিকমতো দেখায়
      final b = StringBuffer('﻿')..writeln(head.join(','));
      for (final r in rows) {
        b.writeln(keys.map((k) => esc(r[k])).join(','));
      }
      return b.toString();
    }

    return {
      'outlets.csv': await table(
        'SELECT $_outletCols $_outletFrom ORDER BY m.name, o.name',
        [today()],
        ['রুট', 'আউটলেট', 'মালিক', 'ম্যানেজার', 'ফোন', 'বাজার', 'গ্রেড', 'বাকি'],
        ['market_name', 'name', 'owner', 'phone', 'address', 'grade', 'due'],
      ),
      'sales.csv': await table(
        'SELECT s.date, m.name AS market, o.name AS outlet, s.amount, '
        's.commission, s.special_commission, s.note '
        'FROM sales s JOIN outlets o ON o.id=s.outlet_id '
        'JOIN markets m ON m.id=o.market_id ORDER BY s.date',
        [],
        ['তারিখ', 'রুট', 'আউটলেট', 'বিক্রি', 'কমিশন', 'স্পেশাল কমিশন', 'নোট'],
        ['date', 'market', 'outlet', 'amount', 'commission', 'special_commission', 'note'],
      ),
      'collections.csv': await table(
        'SELECT c.date, m.name AS market, o.name AS outlet, c.amount, c.note '
        'FROM collections c JOIN outlets o ON o.id=c.outlet_id '
        'JOIN markets m ON m.id=o.market_id ORDER BY c.date',
        [],
        ['তারিখ', 'রুট', 'আউটলেট', 'আদায়', 'নোট'],
        ['date', 'market', 'outlet', 'amount', 'note'],
      ),
      'expenses.csv': await table(
        'SELECT date, category, amount, note FROM expenses ORDER BY date',
        [],
        ['তারিখ', 'ধরন', 'টাকা', 'নোট'],
        ['date', 'category', 'amount', 'note'],
      ),
    };
  }

  /// ডেটাবেস ফাইলের কপি (ব্যাকআপ শেয়ারের জন্য)
  Future<File> backupFile() async {
    await _d; // ডেটাবেস খোলা আছে কিনা নিশ্চিত
    final dir = await getTemporaryDirectory();
    final out = File(p.join(dir.path, 'salesman_dairy_${today()}.db'));
    return File(await dbPath()).copy(out.path);
  }

  /// ব্যাকআপ ফাইল থেকে ডেটা ফেরত আনা (বর্তমান ডেটা মুছে যাবে)
  Future<void> restoreFrom(String path) async {
    // ফাইলটা আসলেই আমাদের ডেটাবেস কিনা যাচাই
    final test = await openDatabase(path, readOnly: true);
    try {
      final r = await test.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='outlets'");
      if (r.isEmpty) throw const FormatException('ভুল ব্যাকআপ ফাইল');
    } finally {
      await test.close();
    }
    // অ্যাপ লকের তথ্য ব্যাকআপ দিয়ে বদলাবে না (পিন বন্ধ হয়ে যাওয়া ঠেকাতে)
    const lockKeys = ['pin_hash', 'pin_salt', 'bio_enabled'];
    final keep = <String, String?>{
      for (final k in lockKeys) k: await getSetting(k),
    };
    await _db?.close();
    _db = null;
    await File(path).copy(await dbPath());
    final d = await _d;
    for (final e in keep.entries) {
      if (e.value == null) {
        await d.delete('settings', where: 'key=?', whereArgs: [e.key]);
      } else {
        await d.insert('settings', {'key': e.key, 'value': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    _bump();
  }
}
