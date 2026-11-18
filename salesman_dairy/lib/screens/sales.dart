import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';

class _SalesData {
  _SalesData(this.sales, this.collections);
  final List<Rec> sales, collections;
}

/// বিক্রয় ও কালেকশন: মাসভিত্তিক, প্রতিদিনের জন্য আলাদা কার্ড (JPG ডাউনলোডসহ)
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  DateTime _m = DateTime(DateTime.now().year, DateTime.now().month, 1);

  Future<_SalesData> _load() async {
    final db = AppDb.instance;
    final from = monthStart(_m), to = monthEnd(_m);
    return _SalesData(
      await db.entriesBetween('sales', from, to),
      await db.entriesBetween('collections', from, to),
    );
  }

  Future<void> _newEntry(String table) async {
    final o = await pickOutlet(context);
    if (o == null || !mounted) return;
    await showEntrySheet(context, o, table);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('বিক্রয় ও কালেকশন'),
          bottom: const TabBar(tabs: [Tab(text: 'বিক্রয়'), Tab(text: 'কালেকশন')]),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('নতুন এন্ট্রি'),
            onPressed: () => _newEntry(
                DefaultTabController.of(ctx).index == 0 ? 'sales' : 'collections'),
          ),
        ),
        body: Column(
          children: [
            MonthBar(month: _m, onChanged: (m) => setState(() => _m = m)),
            Expanded(
              child: DbBuilder<_SalesData>(
                load: _load,
                builder: (context, d) => TabBarView(
                  children: [
                    _EntryList(rows: d.sales, table: 'sales'),
                    _EntryList(rows: d.collections, table: 'collections'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.rows, required this.table});
  final List<Rec> rows;
  final String table;

  @override
  Widget build(BuildContext context) {
    final isColl = table == 'collections';
    final tt = Theme.of(context).textTheme;
    final total =
        rows.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
    final commTotal = rows.fold<double>(
        0, (s, r) => s + ((r['commission'] as num?)?.toDouble() ?? 0));
    final specTotal = rows.fold<double>(
        0, (s, r) => s + ((r['special_commission'] as num?)?.toDouble() ?? 0));

    // দিন অনুযায়ী ভাগ (নতুন তারিখ আগে)
    final byDay = <String, List<Rec>>{};
    for (final r in rows) {
      byDay.putIfAbsent(r['date'] as String, () => []).add(r);
    }
    final dates = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        AppCard(
          child: Column(children: [
            Row(children: [
              Icon(isColl ? Icons.payments_outlined : Icons.sell_outlined),
              const SizedBox(width: 10),
              Text(isColl ? 'এই মাসের মোট কালেকশন' : 'এই মাসের মোট বিক্রয়'),
              const Spacer(),
              Text(taka(total),
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            if (!isColl) ...[
              const Divider(height: 20),
              Row(children: [
                Expanded(
                  child: Text('কমিশন: ${taka(commTotal)}',
                      style: tt.titleSmall),
                ),
                Expanded(
                  child: Text('স্পেশাল কমিশন: ${taka(specTotal)}',
                      textAlign: TextAlign.end, style: tt.titleSmall),
                ),
              ]),
            ],
          ]),
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyNote(isColl
                  ? 'এই মাসে কোনো কালেকশন নেই'
                  : 'এই মাসে কোনো বিক্রয় নেই')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: dates.length,
                  itemBuilder: (context, i) => _DayCard(
                    key: ValueKey('$table-${dates[i]}'),
                    date: dates[i],
                    rows: byDay[dates[i]]!,
                    table: table,
                  ),
                ),
        ),
      ],
    );
  }
}

/// একটি দিনের কার্ড: তারিখ (হেডিং) · প্রতিটি এন্ট্রির বিস্তারিত · দিনের মোট।
/// ওপরের ডানের বাটনে কার্ডটা JPG ছবি হিসেবে ডাউনলোড করা যায়।
class _DayCard extends StatefulWidget {
  const _DayCard(
      {super.key, required this.date, required this.rows, required this.table});
  final String date;
  final List<Rec> rows;
  final String table;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  final _boundaryKey = GlobalKey();
  bool _capturing = false; // ছবি তোলার সময় বাটনগুলো লুকানো থাকে

  bool get _isColl => widget.table == 'collections';

  Future<void> _download() async {
    setState(() => _capturing = true);
    await WidgetsBinding.instance.endOfFrame; // বাটন ছাড়া রূপটা আঁকা হোক
    Uint8List? bytes;
    final name =
        'salesman-dairy_${_isColl ? 'collection' : 'sales'}_${widget.date}.jpg';
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final rgba = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: data!.buffer,
        numChannels: 4,
      );
      bytes = img.encodeJpg(rgba, quality: 92);
    } catch (_) {
      if (mounted) snack(context, 'ছবি বানানো যায়নি');
    }
    if (mounted) setState(() => _capturing = false);
    if (bytes == null || !mounted) return;

    try {
      // সিস্টেমের "সংরক্ষণ" ডায়ালগ: ফোনের Downloads/যেকোনো ফোল্ডারে রাখা যায়
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'JPG সংরক্ষণ করুন',
        fileName: name,
        type: FileType.image,
        bytes: bytes,
      );
      if (saved != null && mounted) snack(context, 'ছবি সংরক্ষণ হয়েছে');
    } catch (_) {
      // সংরক্ষণ ডায়ালগ না খুললে শেয়ার মেনু দিয়ে চেষ্টা
      try {
        await Share.shareXFiles(
            [XFile.fromData(bytes, mimeType: 'image/jpeg', name: name)]);
      } catch (_) {
        if (mounted) snack(context, 'ছবি সংরক্ষণ করা যায়নি');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rows = widget.rows;
    final sum =
        rows.fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
    final comm = rows.fold<double>(
        0, (s, r) => s + ((r['commission'] as num?)?.toDouble() ?? 0));
    final spec = rows.fold<double>(
        0, (s, r) => s + ((r['special_commission'] as num?)?.toDouble() ?? 0));
    final d = parseYmd(widget.date);

    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: EdgeInsets.zero,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          color: const Color(0xFFFFFDF8), // ছবিতে স্বচ্ছ জায়গা না থাকার জন্য
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text('${weekdayNames[d.weekday]} : ${bn(d.day)} ${bnMonths[d.month - 1]}',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Visibility(
                  visible: !_capturing,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: IconButton(
                    tooltip: 'JPG ডাউনলোড',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: _download,
                  ),
                ),
              ]),
              const SizedBox(height: 2),
              for (final r in rows) _row(context, r, tt, cs),
              const Divider(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(children: [
                  Text(_isColl ? 'মোট কালেকশন' : 'মোট বিক্রয়',
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(taka(sum),
                      style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _isColl ? Colors.green.shade700 : cs.primary)),
                ]),
              ),
              if (!_isColl && (comm > 0 || spec > 0))
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 10),
                  child: Text(
                      [
                        if (comm > 0) 'কমিশন ${taka(comm)}',
                        if (spec > 0) 'স্পেশাল কমিশন ${taka(spec)}',
                      ].join('  ·  '),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Rec r, TextTheme tt, ColorScheme cs) {
    final note = ((r['note'] as String?) ?? '').trim();
    final comm = (r['commission'] as num?)?.toDouble() ?? 0;
    final spec = (r['special_commission'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r['outlet_name'] as String,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                  [
                    ((r['outlet_address'] as String?) ?? '').trim(),
                    ((r['outlet_owner'] as String?) ?? '').trim(),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (note.isNotEmpty)
                Text(note,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (!_isColl && (comm > 0 || spec > 0))
                Text(
                    [
                      if (comm > 0) 'কমিশন ${taka(comm)}',
                      if (spec > 0) 'স্পেশাল ${taka(spec)}',
                    ].join(' · '),
                    style: tt.bodySmall?.copyWith(color: cs.primary)),
            ],
          ),
        ),
        Text(taka(r['amount'] as num),
            style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: _isColl ? Colors.green.shade700 : null)),
        Visibility(
          visible: !_capturing,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              if (await confirm(context, 'এই এন্ট্রি মুছে ফেলবেন?',
                  yes: 'মুছুন')) {
                await AppDb.instance.deleteRow(widget.table, r['id'] as int);
              }
            },
          ),
        ),
      ]),
    );
  }
}
