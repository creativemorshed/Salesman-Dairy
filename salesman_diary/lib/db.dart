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
      p.join(await getDatabasesPath(), 'retailer_manager.db');

  Future<Database> get _d async => _db ??= await _open();

  Future<Database> _open() async {
    return openDatabase(
      await dbPath(),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        // মার্কেট/এলাকা + কোন কোন বারে রুট (route_days = "6,7,1" ধরনের)
        await db.execute('''
CREATE TABLE markets(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE COLLATE NOCASE,
  route_days TEXT NOT NULL DEFAULT ''
)''');
        await db.execute('''
CREATE TABLE outlets(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  owner TEXT, phone TEXT, address TEXT, note TEXT,
  market_id INTEGER REFERENCES markets(id) ON DELETE SET NULL,
  grade TEXT NOT NULL DEFAULT 'B',
  opening_due REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE sales(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  outlet_id INTEGER NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  amount REAL NOT NULL,
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
        await db.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
        await db.execute('CREATE INDEX i_out_m ON outlets(market_id)');
        await db.execute('CREATE INDEX i_sales_o ON sales(outlet_id)');
        await db.execute('CREATE INDEX i_sales_d ON sales(date)');
        await db.execute('CREATE INDEX i_col_o ON collections(outlet_id)');
        await db.execute('CREATE INDEX i_col_d ON collections(date)');
        await db.execute('CREATE INDEX i_vis_o ON visits(outlet_id)');
        await db.execute('CREATE INDEX i_vis_d ON visits(date)');
        await db.execute('CREATE INDEX i_exp_d ON expenses(date)');
      },
    );
  }

  // বাকি = আগের বাকি + মোট বিক্রি − মোট আদায়
  static const _dueSql = '''
o.opening_due +
IFNULL((SELECT SUM(amount) FROM sales s WHERE s.outlet_id=o.id),0) -
IFNULL((SELECT SUM(amount) FROM collections c WHERE c.outlet_id=o.id),0) AS due''';

  static const _lastSql =
      '(SELECT MAX(date) FROM visits v WHERE v.outlet_id=o.id) AS last_visit';

  static const _outletSelect =
      'SELECT o.*, m.name AS market, $_dueSql, $_lastSql '
      'FROM outlets o LEFT JOIN markets m ON m.id = o.market_id';

  // ---------------- আউটলেট ----------------
  Future<List<Rec>> outlets({String q = '', int? marketId}) async {
    final d = await _d;
    final like = '%${q.trim()}%';
    final where =
        StringBuffer('(o.name LIKE ? OR o.owner LIKE ? OR o.phone LIKE ?)');
    final args = <Object?>[like, like, like];
    if (marketId != null) {
      where.write(' AND o.market_id = ?');
      args.add(marketId);
    }
    return d.rawQuery(
      '$_outletSelect WHERE $where ORDER BY o.name COLLATE NOCASE',
      args,
    );
  }

  Future<Rec?> outlet(int id) async {
    final d = await _d;
    final r = await d.rawQuery('$_outletSelect WHERE o.id = ?', [id]);
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

  Future<int> outletCount() async =>
      (await _sum('SELECT COUNT(*) FROM outlets')).toInt();

  /// যাদের কাছে বাকি আছে (বেশি বাকি আগে)
  Future<List<Rec>> dueOutlets({int? limit}) async {
    final d = await _d;
    return d.rawQuery(
      'SELECT * FROM ($_outletSelect) WHERE due > 0 ORDER BY due DESC'
      '${limit != null ? ' LIMIT $limit' : ''}',
    );
  }

  // ---------------- মার্কেট ও রুট ----------------
  Future<List<Rec>> markets() async => (await _d).rawQuery(
        'SELECT m.*, (SELECT COUNT(*) FROM outlets o WHERE o.market_id=m.id) '
        'AS outlet_count FROM markets m ORDER BY m.name COLLATE NOCASE',
      );

  /// weekday: DateTime.weekday (সোম=1 … রবি=7)
  Future<List<Rec>> marketsOnDay(int weekday) async {
    final all = await markets();
    return all.where((m) {
      final days = ((m['route_days'] as String?) ?? '').split(',');
      return days.contains('$weekday');
    }).toList();
  }

  /// নাম আগে থাকলে UNIQUE এরর ছুঁড়ে
  Future<void> saveMarket(
      {required String name, required List<int> days, int? id}) async {
    final d = await _d;
    final data = {'name': name, 'route_days': days.join(',')};
    if (id == null) {
      await d.insert('markets', data);
    } else {
      await d.update('markets', data, where: 'id=?', whereArgs: [id]);
    }
    _bump();
  }

  Future<void> deleteMarket(int id) async {
    await (await _d).delete('markets', where: 'id=?', whereArgs: [id]);
    _bump();
  }

  /// নাম দিয়ে মার্কেট খোঁজে, না থাকলে নতুন বানায়। খালি নাম হলে null।
  Future<int?> marketIdByName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    final d = await _d;
    final r = await d.query('markets',
        columns: ['id'], where: 'name=?', whereArgs: [n], limit: 1);
    if (r.isNotEmpty) return r.first['id'] as int;
    return d.insert('markets', {'name': n, 'route_days': ''});
  }

  // ---------------- আজকের রুট ----------------
  /// নির্দিষ্ট মার্কেটগুলোর আউটলেট; visited = ওই তারিখে ভিজিট হয়েছে কিনা
  Future<List<Rec>> routeOutlets(String date, List<int> marketIds) async {
    if (marketIds.isEmpty) return [];
    final d = await _d;
    return d.rawQuery(
      'SELECT * FROM (SELECT o.*, m.name AS market, $_dueSql, $_lastSql, '
      'EXISTS(SELECT 1 FROM visits v2 WHERE v2.outlet_id=o.id AND v2.date=?) AS visited '
      'FROM outlets o JOIN markets m ON m.id=o.market_id '
      'WHERE o.market_id IN (${marketIds.join(',')})) '
      'ORDER BY visited, market COLLATE NOCASE, name COLLATE NOCASE',
      [date],
    );
  }

  /// ওই তারিখে যাদের ভিজিট হয়েছে (রুটের বাইরেরও)
  Future<List<Rec>> visitedOutlets(String date) async {
    final d = await _d;
    return d.rawQuery(
      'SELECT o.*, m.name AS market, $_dueSql, $_lastSql, v.note AS visit_note '
      'FROM visits v JOIN outlets o ON o.id=v.outlet_id '
      'LEFT JOIN markets m ON m.id=o.market_id WHERE v.date=? '
      'GROUP BY o.id ORDER BY MAX(v.id) DESC',
      [date],
    );
  }

  /// এক ভিজিটে বিক্রি + নগদ আদায় + নোট একসাথে
  Future<void> recordVisit({
    required int outletId,
    required String date,
    double sale = 0,
    double paid = 0,
    String note = '',
  }) async {
    final d = await _d;
    await d.transaction((t) async {
      if (sale > 0) {
        await t.insert('sales',
            {'outlet_id': outletId, 'date': date, 'amount': sale, 'note': ''});
      }
      if (paid > 0) {
        await t.insert('collections',
            {'outlet_id': outletId, 'date': date, 'amount': paid, 'note': ''});
      }
      await t.insert(
          'visits', {'outlet_id': outletId, 'date': date, 'note': note});
    });
    _bump();
  }

  // ---------------- বিক্রি / আদায় / ভিজিট ----------------
  Future<List<Rec>> outletSales(int outletId) async => (await _d).query('sales',
      where: 'outlet_id=?',
      whereArgs: [outletId],
      orderBy: 'date DESC, id DESC');

  Future<List<Rec>> outletCollections(int outletId) async =>
      (await _d).query('collections',
          where: 'outlet_id=?',
          whereArgs: [outletId],
          orderBy: 'date DESC, id DESC');

  Future<List<Rec>> outletVisits(int outletId) async =>
      (await _d).query('visits',
          where: 'outlet_id=?',
          whereArgs: [outletId],
          orderBy: 'date DESC, id DESC');

  Future<void> addSale({
    required int outletId,
    required String date,
    required double amount,
    double paid = 0,
    String note = '',
  }) async {
    final d = await _d;
    await d.transaction((t) async {
      await t.insert('sales',
          {'outlet_id': outletId, 'date': date, 'amount': amount, 'note': note});
      if (paid > 0) {
        await t.insert('collections', {
          'outlet_id': outletId,
          'date': date,
          'amount': paid,
          'note': 'বিক্রির সময় নগদ',
        });
      }
    });
    _bump();
  }

  Future<void> addCollection({
    required int outletId,
    required String date,
    required double amount,
    String note = '',
  }) async {
    await (await _d).insert('collections',
        {'outlet_id': outletId, 'date': date, 'amount': amount, 'note': note});
    _bump();
  }

  /// মাসের সব বিক্রি (আউটলেটের নামসহ)
  Future<List<Rec>> salesBetween(String from, String to) async =>
      (await _d).rawQuery(
        'SELECT s.*, o.name AS outlet FROM sales s '
        'JOIN outlets o ON o.id=s.outlet_id WHERE s.date>=? AND s.date<? '
        'ORDER BY s.date DESC, s.id DESC',
        [from, to],
      );

  Future<List<Rec>> collectionsBetween(String from, String to) async =>
      (await _d).rawQuery(
        'SELECT c.*, o.name AS outlet FROM collections c '
        'JOIN outlets o ON o.id=c.outlet_id WHERE c.date>=? AND c.date<? '
        'ORDER BY c.date DESC, c.id DESC',
        [from, to],
      );

  Future<void> deleteRow(String table, int id) async {
    const allowed = {'sales', 'collections', 'visits', 'expenses'};
    if (!allowed.contains(table)) throw ArgumentError('invalid table');
    await (await _d).delete(table, where: 'id=?', whereArgs: [id]);
    _bump();
  }

  // ---------------- নিজের খরচ ----------------
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
  Future<double> salesTotal(String from, String to) => _sum(
      'SELECT SUM(amount) FROM sales WHERE date>=? AND date<?', [from, to]);

  Future<double> collectedTotal(String from, String to) => _sum(
      'SELECT SUM(amount) FROM collections WHERE date>=? AND date<?',
      [from, to]);

  Future<double> spent(String from, String to) => _sum(
      'SELECT SUM(amount) FROM expenses WHERE date>=? AND date<?', [from, to]);

  /// সব আউটলেটের মোট বাকি (মার্কেট বাকি)
  Future<double> totalDue() => _sum(
      'SELECT IFNULL((SELECT SUM(opening_due) FROM outlets),0) + '
      'IFNULL((SELECT SUM(amount) FROM sales),0) - '
      'IFNULL((SELECT SUM(amount) FROM collections),0)');

  /// মার্কেটভিত্তিক: আউটলেট সংখ্যা, মোট বাকি, নির্দিষ্ট সময়ের বিক্রি ও আদায়
  Future<List<Rec>> marketStats(String from, String to) async {
    final rows = await (await _d).rawQuery(
      'SELECT IFNULL(m.name, \'মার্কেট নেই\') AS market, $_dueSql, '
      'IFNULL((SELECT SUM(amount) FROM sales s WHERE s.outlet_id=o.id AND s.date>=? AND s.date<?),0) AS m_sales, '
      'IFNULL((SELECT SUM(amount) FROM collections c WHERE c.outlet_id=o.id AND c.date>=? AND c.date<?),0) AS m_coll '
      'FROM outlets o LEFT JOIN markets m ON m.id=o.market_id',
      [from, to, from, to],
    );
    final map = <String, Map<String, Object?>>{};
    for (final r in rows) {
      final key = r['market'] as String;
      final m = map.putIfAbsent(key, () => <String, Object?>{
            'name': key,
            'outlets': 0,
            'due': 0.0,
            'sales': 0.0,
            'coll': 0.0,
          });
      m['outlets'] = (m['outlets'] as int) + 1;
      m['due'] = (m['due'] as double) + (r['due'] as num).toDouble();
      m['sales'] = (m['sales'] as double) + (r['m_sales'] as num).toDouble();
      m['coll'] = (m['coll'] as double) + (r['m_coll'] as num).toDouble();
    }
    final list = map.values.toList()
      ..sort((a, b) => (b['due'] as double).compareTo(a['due'] as double));
    return list;
  }

  // ---------------- টার্গেট ----------------
  /// ym = "2026-11"। ওই মাসে আলাদা টার্গেট না থাকলে সর্বশেষ সেট করা টার্গেটই চলে।
  Future<({double sales, double collect})> target(String ym) async {
    final s = await getSetting('target_sales_$ym') ??
        await getSetting('target_sales') ??
        '';
    final c = await getSetting('target_collect_$ym') ??
        await getSetting('target_collect') ??
        '';
    return (sales: parseNum(s), collect: parseNum(c));
  }

  Future<void> setTarget(String ym, double sales, double collect) async {
    await setSetting('target_sales_$ym', sales.toString());
    await setSetting('target_collect_$ym', collect.toString());
    await setSetting('target_sales', sales.toString());
    await setSetting('target_collect', collect.toString());
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
        String sql, List<String> head, List<String> keys) async {
      final rows = await d.rawQuery(sql);
      // BOM থাকলে Excel-এ বাংলা ঠিকমতো দেখায়
      final b = StringBuffer('﻿')..writeln(head.join(','));
      for (final r in rows) {
        b.writeln(keys.map((k) => esc(r[k])).join(','));
      }
      return b.toString();
    }

    return {
      'outlets.csv': await table(
        'SELECT o.name, o.owner, o.phone, m.name AS market, o.grade, $_dueSql '
        'FROM outlets o LEFT JOIN markets m ON m.id=o.market_id ORDER BY m.name, o.name',
        ['আউটলেট', 'মালিক', 'ফোন', 'মার্কেট', 'গ্রেড', 'বাকি'],
        ['name', 'owner', 'phone', 'market', 'grade', 'due'],
      ),
      'sales.csv': await table(
        'SELECT s.date, o.name AS outlet, s.amount, s.note FROM sales s '
        'JOIN outlets o ON o.id=s.outlet_id ORDER BY s.date',
        ['তারিখ', 'আউটলেট', 'বিক্রি', 'নোট'],
        ['date', 'outlet', 'amount', 'note'],
      ),
      'collections.csv': await table(
        'SELECT c.date, o.name AS outlet, c.amount, c.note FROM collections c '
        'JOIN outlets o ON o.id=c.outlet_id ORDER BY c.date',
        ['তারিখ', 'আউটলেট', 'আদায়', 'নোট'],
        ['date', 'outlet', 'amount', 'note'],
      ),
      'expenses.csv': await table(
        'SELECT date, category, amount, note FROM expenses ORDER BY date',
        ['তারিখ', 'ধরন', 'টাকা', 'নোট'],
        ['date', 'category', 'amount', 'note'],
      ),
    };
  }

  /// ডেটাবেস ফাইলের কপি (ব্যাকআপ শেয়ারের জন্য)
  Future<File> backupFile() async {
    await _d; // ডেটাবেস খোলা আছে কিনা নিশ্চিত
    final dir = await getTemporaryDirectory();
    final out = File(p.join(dir.path, 'retailer_manager_${today()}.db'));
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
