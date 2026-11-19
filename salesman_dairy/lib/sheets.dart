import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import 'db.dart';
import 'state.dart';
import 'utils.dart';
import 'widgets.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: SingleChildScrollView(child: child),
    ),
  );
}

const _numKb = TextInputType.numberWithOptions(decimal: true);

// সপ্তাহের ক্রম (বাংলাদেশ): শনি থেকে শুক্র

// =====================================================================
// রুট যোগ / এডিট (নাম + কোন কোন বারে ভিজিট)
// =====================================================================
Future<void> showMarketSheet(BuildContext context, {Rec? existing}) =>
    _sheet<void>(context, _MarketForm(existing: existing));

class _MarketForm extends StatefulWidget {
  const _MarketForm({this.existing});
  final Rec? existing;

  @override
  State<_MarketForm> createState() => _MarketFormState();
}

class _MarketFormState extends State<_MarketForm> {
  late final _name = TextEditingController(
      text: (widget.existing?['name'] as String?) ?? '');
  late final Set<int> _days = {
    if (widget.existing != null)
      for (final s in (widget.existing!['days'] as String).split(','))
        if (s.isNotEmpty) int.parse(s),
  };
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'রুটের নাম লিখুন');
      return;
    }
    await AppDb.instance
        .saveMarket(name, _days.toList(), id: widget.existing?['id'] as int?);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'এই রুট মুছে ফেলবেন?', yes: 'মুছুন')) return;
    try {
      await AppDb.instance.deleteMarket(widget.existing!['id'] as int);
      if (mounted) Navigator.pop(context);
    } on StateError catch (e) {
      setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.existing == null ? 'নতুন রুট' : 'রুট এডিট',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'রুটের নাম *')),
        const SizedBox(height: 14),
        Text('কোন কোন বারে ভিজিট করেন?',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final wd in weekOrder)
              FilterChip(
                label: Text(weekdayShort[wd]),
                selected: _days.contains(wd),
                onSelected: (v) =>
                    setState(() => v ? _days.add(wd) : _days.remove(wd)),
              ),
          ],
        ),
        ErrorText(_err),
        FilledButton(onPressed: _save, child: const Text('সংরক্ষণ')),
        if (widget.existing != null)
          TextButton(
            onPressed: _delete,
            child: Text('রুট মুছুন',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}

// =====================================================================
// রুট বাছাই (হোম/রুটে কোন রুট দেখাবে)
// =====================================================================
Future<void> showMarketPicker(BuildContext context) async {
  final rows = await AppDb.instance.markets();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('রুট পছন্দ করুন',
                    style: Theme.of(ctx).textTheme.titleLarge),
              ),
            ),
            Flexible(
              child: rows.isEmpty
                  ? const EmptyNote('এখনো কোনো রুট নেই')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final m in rows)
                          ListTile(
                            leading:
                                const Icon(Icons.store_mall_directory_outlined),
                            title: Text(m['name'] as String),
                            subtitle: Text(
                                '${daysText(m['days'] as String)} · ${bn(m['outlet_count'] as num)}টি দোকান'),
                            trailing: Text(taka(m['due'] as num),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            onTap: () {
                              selectedMarket.value = m['id'] as int;
                              Navigator.pop(ctx);
                            },
                          ),
                      ],
                    ),
            ),
            // ৬টি রুট হয়ে গেলে এখানে যোগ করার অপশন নেই (সেটিংসে আছে)
            if (rows.length < routeQuickAddLimit)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('নতুন রুট যোগ করুন'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (context.mounted) showMarketSheet(context);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

// =====================================================================
// আউটলেট (দোকান) যোগ / এডিট
// =====================================================================
Future<void> showOutletSheet(BuildContext context,
        {Rec? existing, int? marketId}) =>
    _sheet<void>(context, _OutletForm(existing: existing, marketId: marketId));

class _OutletForm extends StatefulWidget {
  const _OutletForm({this.existing, this.marketId});
  final Rec? existing;
  final int? marketId;

  @override
  State<_OutletForm> createState() => _OutletFormState();
}

class _OutletFormState extends State<_OutletForm> {
  String _s(String k) => (widget.existing?[k] as String?) ?? '';
  late final _name = TextEditingController(text: _s('name'));
  late final _owner = TextEditingController(text: _s('owner'));
  late final _manager = TextEditingController(text: _s('manager'));
  late final _phone = TextEditingController(text: _s('phone'));
  late final _address = TextEditingController(text: _s('address'));
  late final _note = TextEditingController(text: _s('note'));
  late final _opening = TextEditingController(
      text: widget.existing == null
          ? ''
          : numText((widget.existing!['opening_due'] as num).toDouble()));
  late int? _market =
      (widget.existing?['market_id'] as int?) ?? widget.marketId;
  late String _grade = widget.existing == null ? 'B' : _s('grade');
  List<Rec> _markets = [];
  String? _err;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  Future<void> _loadMarkets() async {
    final m = await AppDb.instance.markets();
    if (!mounted) return;
    setState(() {
      _markets = m;
      if (_market == null && m.length == 1) _market = m.first['id'] as int;
    });
  }

  /// ফোনের কন্টাক্ট লিস্ট থেকে একটা নম্বর বেছে ঘরে বসায়
  Future<void> _pickContact() async {
    try {
      final c = await FlutterNativeContactPicker().selectContact();
      final raw = (c?.phoneNumbers != null && c!.phoneNumbers!.isNotEmpty)
          ? c.phoneNumbers!.first
          : null;
      if (raw == null) return;
      var n = raw.replaceAll(RegExp(r'[\s\-()]'), '');
      // +8801XXXXXXXXX / 8801XXXXXXXXX → 01XXXXXXXXX
      if (n.startsWith('+880')) n = '0${n.substring(4)}';
      if (n.startsWith('880') && n.length == 13) n = '0${n.substring(3)}';
      if (mounted) setState(() => _phone.text = n);
    } catch (_) {
      if (mounted) snack(context, 'কন্টাক্ট খোলা যায়নি। নম্বরটা হাতে লিখুন।');
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _owner, _manager, _phone, _address, _note, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'আউটলেটের নাম লিখুন');
      return;
    }
    if (_market == null) {
      setState(() => _err = 'রুট পছন্দ করুন (না থাকলে "নতুন রুট" চাপুন)');
      return;
    }
    await AppDb.instance.saveOutlet(
      {
        'market_id': _market,
        'name': name,
        'owner': _owner.text.trim(),
        'manager': _manager.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'note': _note.text.trim(),
        'grade': _grade,
        'opening_due': parseNum(_opening.text),
      },
      id: widget.existing?['id'] as int?,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.existing == null ? 'নতুন আউটলেট' : 'আউটলেট এডিট',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'দোকানের নাম *')),
        const SizedBox(height: 10),
        TextField(
            controller: _owner,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'মালিকের নাম')),
        const SizedBox(height: 10),
        TextField(
            controller: _manager,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'ম্যানেজারের নাম')),
        const SizedBox(height: 10),
        TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'ফোন নম্বর',
              suffixIcon: IconButton(
                tooltip: 'মোবাইলের কন্টাক্ট থেকে নিন',
                icon: const Icon(Icons.contacts_outlined),
                onPressed: _pickContact,
              ),
            )),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          value: _markets.any((m) => m['id'] == _market) ? _market : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'রুট সিলেক্ট করুনঃ- *'),
          hint: const Text('রুট বাছুন'),
          items: [
            for (final m in _markets)
              DropdownMenuItem<int>(
                  value: m['id'] as int, child: Text(m['name'] as String)),
          ],
          onChanged: (v) => setState(() => _market = v),
        ),
        if (_markets.length < routeQuickAddLimit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('নতুন রুট'),
              onPressed: () async {
                await showMarketSheet(context);
                await _loadMarkets();
              },
            ),
          ),
        const SizedBox(height: 14),
        Text('গ্রেড (A+ = বড়, A = মাঝারি, B = ছোট, F = খারাপ)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(children: [
          for (final g in const ['A+', 'A', 'B', 'F'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(g),
                selected: _grade == g,
                onSelected: (_) => setState(() => _grade = g),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
            controller: _opening,
            keyboardType: _numKb,
            decoration: const InputDecoration(
                labelText: 'আগের বাকি (অ্যাপ ব্যবহারের আগে থেকে থাকলে)',
                prefixText: '৳ ')),
        const SizedBox(height: 10),
        TextField(
            controller: _address,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'বাজারের নামঃ-')),
        const SizedBox(height: 10),
        TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'নোট')),
        ErrorText(_err),
        FilledButton(onPressed: _save, child: const Text('সংরক্ষণ')),
      ],
    );
  }
}

// =====================================================================
// ভিজিট এন্ট্রি: বিক্রয় + কালেকশন + নোট + পরের তাগাদা (একসাথে)
// =====================================================================
Future<void> showVisitSheet(BuildContext context, Rec outlet) =>
    _sheet<void>(context, _VisitForm(outlet: outlet));

class _VisitForm extends StatefulWidget {
  const _VisitForm({required this.outlet});
  final Rec outlet;

  @override
  State<_VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends State<_VisitForm> {
  final _sale = TextEditingController();
  final _comm = TextEditingController();
  final _special = TextEditingController();
  final _coll = TextEditingController();
  final _note = TextEditingController();
  final _nextNote = TextEditingController();
  String? _reminder; // ডিফল্ট: নাই

  double get _due => (widget.outlet['due'] as num).toDouble();
  double get _newDue => _due + parseNum(_sale.text) - parseNum(_coll.text);

  @override
  void dispose() {
    _sale.dispose();
    _comm.dispose();
    _special.dispose();
    _coll.dispose();
    _note.dispose();
    _nextNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (parseNum(_sale.text) <= 0 && parseNum(_coll.text) <= 0) {
      snack(context, 'বিক্রয় বা কালেকশন লিখুন। কিছু না থাকলে "ভিজিট" বাটন চাপুন।');
      return;
    }
    await AppDb.instance.addVisit(
      outletId: widget.outlet['id'] as int,
      date: today(),
      sale: parseNum(_sale.text),
      commission: parseNum(_comm.text),
      specialCommission: parseNum(_special.text),
      collected: parseNum(_coll.text),
      note: _note.text.trim(),
      payReminder: _reminder,
      nextNote: _nextNote.text,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('এন্ট্রি — ${widget.outlet['name']}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('বর্তমান বাকি: ${taka(_due)}'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
                controller: _sale,
                keyboardType: _numKb,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'আজকের বিক্রয়', prefixText: '৳ ')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
                controller: _coll,
                keyboardType: _numKb,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'আজকের কালেকশন', prefixText: '৳ ')),
          ),
        ]),
        const SizedBox(height: 10),
        CommissionFields(commission: _comm, special: _special),
        const SizedBox(height: 8),
        Text('ভিজিটের পর বাকি: ${taka(_newDue)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _newDue > 0 ? cs.error : Colors.green)),
        const SizedBox(height: 10),
        TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'নোট (কী কথা হলো?)')),
        const SizedBox(height: 12),
        ReminderField(
          label: 'পরের তাগাদার তারিখ',
          value: _reminder,
          onChanged: (v) => setState(() => _reminder = v),
        ),
        const SizedBox(height: 12),
        NextNoteField(
            existing: widget.outlet['next_note'] as String?,
            controller: _nextNote),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('এন্ট্রি সংরক্ষণ')),
      ],
    );
  }
}

// =====================================================================
// ভিজিট: এক ক্লিকেই সংরক্ষণ (কোনো মেনু নেই)। ভুলে চাপলে "বাতিল" দিয়ে ফেরানো যায়।
// তাগাদার তারিখ ও বিশেষ নোট যেমন ছিল তেমনই থাকে।
// =====================================================================
Future<void> quickVisit(BuildContext context, Rec outlet) async {
  final messenger = ScaffoldMessenger.of(context);
  final id = await AppDb.instance.addVisit(
    outletId: outlet['id'] as int,
    date: today(),
    keepFollowUp: true,
  );
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('${outlet['name']} — ভিজিট সংরক্ষণ হয়েছে'),
      action: SnackBarAction(
        label: 'বাতিল',
        onPressed: () => AppDb.instance.deleteRow('visits', id),
      ),
    ));
}

// =====================================================================
// শুধু বিক্রয় বা শুধু কালেকশন এন্ট্রি (table: 'sales' | 'collections')
// =====================================================================
Future<void> showEntrySheet(BuildContext context, Rec outlet, String table) =>
    _sheet<void>(context, _EntryForm(outlet: outlet, table: table));

class _EntryForm extends StatefulWidget {
  const _EntryForm({required this.outlet, required this.table});
  final Rec outlet;
  final String table;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  final _amount = TextEditingController();
  final _comm = TextEditingController();
  final _special = TextEditingController();
  final _note = TextEditingController();
  String _date = today();
  late String? _reminder = widget.outlet['pay_reminder'] as String?;
  String? _err;

  bool get _isColl => widget.table == 'collections';

  @override
  void dispose() {
    _amount.dispose();
    _comm.dispose();
    _special.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseNum(_amount.text);
    if (amount <= 0) {
      setState(() => _err = 'টাকার পরিমাণ লিখুন');
      return;
    }
    await AppDb.instance.addEntry(
      table: widget.table,
      outletId: widget.outlet['id'] as int,
      date: _date,
      amount: amount,
      commission: parseNum(_comm.text),
      specialCommission: parseNum(_special.text),
      note: _note.text.trim(),
      updateReminder: _isColl,
      payReminder: _reminder,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final due = (widget.outlet['due'] as num).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            '${_isColl ? 'কালেকশন' : 'বিক্রয়'} — ${widget.outlet['name']}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('বর্তমান বাকি: ${taka(due)}'),
        const SizedBox(height: 12),
        TextField(
            controller: _amount,
            keyboardType: _numKb,
            autofocus: true,
            decoration: InputDecoration(
                labelText: _isColl ? 'কত টাকা পেলেন? *' : 'বিক্রয়ের পরিমাণ *',
                prefixText: '৳ ')),
        if (!_isColl) ...[
          const SizedBox(height: 10),
          CommissionFields(commission: _comm, special: _special),
        ],
        const SizedBox(height: 10),
        TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(niceDate(_date)),
            onPressed: () async {
              final d = await pickDate(context, initial: _date);
              if (d != null) setState(() => _date = d);
            },
          ),
        ),
        if (_isColl) ...[
          ReminderField(
            label: 'পরের তাগাদার তারিখ',
            value: _reminder,
            onChanged: (v) => setState(() => _reminder = v),
          ),
        ],
        ErrorText(_err),
        FilledButton(onPressed: _save, child: const Text('সংরক্ষণ')),
      ],
    );
  }
}

// =====================================================================
// টাকা দেওয়ার তারিখ (তাগাদা) বদলানো
// =====================================================================
Future<void> showReminderSheet(
        BuildContext context, int outletId, String? current) =>
    _sheet<void>(context, _ReminderForm(outletId: outletId, current: current));

class _ReminderForm extends StatefulWidget {
  const _ReminderForm({required this.outletId, this.current});
  final int outletId;
  final String? current;

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  late String? _v = widget.current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('টাকা চাওয়ার তারিখ',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ReminderField(
            label: 'তারিখ', value: _v, onChanged: (v) => setState(() => _v = v)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await AppDb.instance.setPayReminder(widget.outletId, _v);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('সংরক্ষণ'),
        ),
      ],
    );
  }
}

// =====================================================================
// মাসিক টার্গেট (একটাই: বিক্রয় ও কালেকশনের টার্গেট সবসময় সমান)
// =====================================================================
Future<void> showTargetSheet(BuildContext context, DateTime month,
        {double target = 0}) =>
    _sheet<void>(context, _TargetForm(month: month, target: target));

class _TargetForm extends StatefulWidget {
  const _TargetForm({required this.month, required this.target});
  final DateTime month;
  final double target;

  @override
  State<_TargetForm> createState() => _TargetFormState();
}

class _TargetFormState extends State<_TargetForm> {
  late final _target = TextEditingController(
      text: widget.target > 0 ? numText(widget.target) : '');

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('মাসিক টার্গেট — ${monthTitle(widget.month)}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
            controller: _target,
            keyboardType: _numKb,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'টার্গেট (বিক্রয় ও কালেকশন দুটোর জন্য)',
                prefixText: '৳ ')),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
              'এই টার্গেট পরের মাসগুলোতেও চলবে। বদলাতে চাইলে সেই মাসে নতুন করে সেট করুন।',
              style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final v = parseNum(_target.text);
            await AppDb.instance.setTarget(monthKey(widget.month), v, v);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('সংরক্ষণ'),
        ),
      ],
    );
  }
}

// =====================================================================
// খরচ যোগ
// =====================================================================
const expenseCategories = ['যাতায়াত', 'খাবার', 'মোবাইল বিল', 'অন্যান্য'];

Future<void> showExpenseSheet(BuildContext context) =>
    _sheet<void>(context, const _ExpenseForm());

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  String _cat = expenseCategories.first;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _date = today();
  String? _err;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseNum(_amount.text);
    if (amount <= 0) {
      setState(() => _err = 'টাকার পরিমাণ লিখুন');
      return;
    }
    await AppDb.instance.addExpense(
      date: _date,
      category: _cat,
      amount: amount,
      note: _note.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('নতুন খরচ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final c in expenseCategories)
              ChoiceChip(
                label: Text(c),
                selected: _cat == c,
                onSelected: (_) => setState(() => _cat = c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
            controller: _amount,
            keyboardType: _numKb,
            decoration: const InputDecoration(labelText: 'টাকা *')),
        const SizedBox(height: 10),
        TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(niceDate(_date)),
            onPressed: () async {
              final d = await pickDate(context, initial: _date);
              if (d != null) setState(() => _date = d);
            },
          ),
        ),
        ErrorText(_err),
        FilledButton(onPressed: _save, child: const Text('সংরক্ষণ')),
      ],
    );
  }
}

// =====================================================================
// আউটলেট বাছাই (বিক্রয়/কালেকশন এন্ট্রির জন্য)
// =====================================================================
Future<Rec?> pickOutlet(BuildContext context) {
  return showModalBottomSheet<Rec>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.75,
      child: const _OutletPicker(),
    ),
  );
}

class _OutletPicker extends StatefulWidget {
  const _OutletPicker();

  @override
  State<_OutletPicker> createState() => _OutletPickerState();
}

class _OutletPickerState extends State<_OutletPicker> {
  List<Rec> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    final r = await AppDb.instance.outlets(q: q);
    if (!mounted) return;
    setState(() {
      _list = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: _search,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'আউটলেট খুঁজুন',
                isDense: true),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _list.isEmpty
                  ? const EmptyNote('কোনো আউটলেট পাওয়া যায়নি')
                  : ListView.builder(
                      itemCount: _list.length,
                      itemBuilder: (_, i) {
                        final o = _list[i];
                        return ListTile(
                          leading: GradeBadge(o['grade'] as String, size: 32),
                          title: Text(o['name'] as String),
                          subtitle: Text(o['market_name'] as String),
                          trailing: Text(taka(o['due'] as num)),
                          onTap: () => Navigator.pop(context, o),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}


/// "পরের ভিজিটে মনে রাখার বিশেষ নোট": আগের নোট দেখায় (এই ভিজিটে কাজ হলো কিনা বোঝার জন্য)
/// এবং পরের ভিজিটের জন্য নতুন নোট লেখার ঘর। সংরক্ষণ করলে আগের নোট মুছে নতুনটা বসে।
class NextNoteField extends StatelessWidget {
  const NextNoteField({super.key, required this.existing, required this.controller});
  final String? existing;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final has = existing != null && existing!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (has)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: 20, color: cs.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('আগের নোট: ${existing!.trim()}',
                      style: TextStyle(color: cs.onTertiaryContainer)),
                ),
              ],
            ),
          ),
        TextField(
          controller: controller,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'পরের ভিজিটের জন্য বিশেষ নোট (ঐচ্ছিক)',
            helperText: has
                ? 'সংরক্ষণ করলে আগের নোট মুছে এটা থাকবে'
                : 'পরের বার এই দোকানে গেলে রিমাইন্ডার হিসেবে দেখাবে',
          ),
        ),
      ],
    );
  }
}


/// বিক্রয়ের সাথে কমিশন ও স্পেশাল কমিশনের দুটি আলাদা ঘর (টাকার অংকে)
class CommissionFields extends StatelessWidget {
  const CommissionFields(
      {super.key, required this.commission, required this.special});
  final TextEditingController commission;
  final TextEditingController special;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
            controller: commission,
            keyboardType: _numKb,
            decoration: const InputDecoration(
                labelText: 'কমিশন', prefixText: '৳ ')),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: TextField(
            controller: special,
            keyboardType: _numKb,
            decoration: const InputDecoration(
                labelText: 'স্পেশাল কমিশন', prefixText: '৳ ')),
      ),
    ]);
  }
}
