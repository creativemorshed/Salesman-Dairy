import 'package:flutter/material.dart';

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
const weekOrder = [6, 7, 1, 2, 3, 4, 5];

// =====================================================================
// মার্কেট যোগ / এডিট (নাম + কোন কোন বারে ভিজিট)
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
      setState(() => _err = 'মার্কেটের নাম লিখুন');
      return;
    }
    await AppDb.instance
        .saveMarket(name, _days.toList(), id: widget.existing?['id'] as int?);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'এই মার্কেট মুছে ফেলবেন?', yes: 'মুছুন')) return;
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
        Text(widget.existing == null ? 'নতুন মার্কেট' : 'মার্কেট এডিট',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'মার্কেটের নাম *')),
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
            child: Text('মার্কেট মুছুন',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}

// =====================================================================
// মার্কেট বাছাই (হোম/রুটে কোন মার্কেট দেখাবে)
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
                child: Text('মার্কেট বাছুন',
                    style: Theme.of(ctx).textTheme.titleLarge),
              ),
            ),
            Flexible(
              child: rows.isEmpty
                  ? const EmptyNote('এখনো কোনো মার্কেট নেই')
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
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('নতুন মার্কেট যোগ করুন'),
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

  @override
  void dispose() {
    for (final c in [_name, _owner, _phone, _address, _note, _opening]) {
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
      setState(() => _err = 'মার্কেট বাছুন (না থাকলে "নতুন মার্কেট" চাপুন)');
      return;
    }
    await AppDb.instance.saveOutlet(
      {
        'market_id': _market,
        'name': name,
        'owner': _owner.text.trim(),
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
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'ফোন নম্বর')),
        const SizedBox(height: 14),
        Text('মার্কেট *', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final m in _markets)
              ChoiceChip(
                label: Text(m['name'] as String),
                selected: _market == m['id'],
                onSelected: (_) => setState(() => _market = m['id'] as int),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('নতুন মার্কেট'),
              onPressed: () async {
                await showMarketSheet(context);
                await _loadMarkets();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('গ্রেড', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(children: [
          for (final g in const ['A', 'B', 'C'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(g),
                selected: _grade == g,
                onSelected: (_) => setState(() => _grade = g),
              ),
            ),
          const Expanded(
              child: Text('A = বড়, B = মাঝারি, C = ছোট',
                  style: TextStyle(fontSize: 12))),
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
            decoration: const InputDecoration(labelText: 'ঠিকানা')),
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
// ভিজিট এন্ট্রি: বিক্রি + আদায় + নোট + পরের তাগাদা (একসাথে)
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
  final _coll = TextEditingController();
  final _note = TextEditingController();
  late String? _reminder = widget.outlet['pay_reminder'] as String?;

  double get _due => (widget.outlet['due'] as num).toDouble();
  double get _newDue => _due + parseNum(_sale.text) - parseNum(_coll.text);

  @override
  void dispose() {
    _sale.dispose();
    _coll.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppDb.instance.addVisit(
      outletId: widget.outlet['id'] as int,
      date: today(),
      sale: parseNum(_sale.text),
      collected: parseNum(_coll.text),
      note: _note.text.trim(),
      payReminder: _reminder,
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
        Text('ভিজিট — ${widget.outlet['name']}',
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
                    labelText: 'আজকের বিক্রি', prefixText: '৳ ')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
                controller: _coll,
                keyboardType: _numKb,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'আজকের আদায়', prefixText: '৳ ')),
          ),
        ]),
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
        FilledButton(onPressed: _save, child: const Text('ভিজিট সংরক্ষণ')),
      ],
    );
  }
}

// =====================================================================
// শুধু বিক্রি বা শুধু আদায় এন্ট্রি (table: 'sales' | 'collections')
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
  final _note = TextEditingController();
  String _date = today();
  late String? _reminder = widget.outlet['pay_reminder'] as String?;
  String? _err;

  bool get _isColl => widget.table == 'collections';

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
    await AppDb.instance.addEntry(
      table: widget.table,
      outletId: widget.outlet['id'] as int,
      date: _date,
      amount: amount,
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
            '${_isColl ? 'আদায়' : 'বিক্রি'} — ${widget.outlet['name']}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('বর্তমান বাকি: ${taka(due)}'),
        const SizedBox(height: 12),
        TextField(
            controller: _amount,
            keyboardType: _numKb,
            autofocus: true,
            decoration: InputDecoration(
                labelText: _isColl ? 'কত টাকা পেলেন? *' : 'বিক্রির পরিমাণ *',
                prefixText: '৳ ')),
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
// মাসিক টার্গেট (বিক্রি ও আদায়)
// =====================================================================
Future<void> showTargetSheet(BuildContext context, DateTime month,
        {double sales = 0, double collection = 0}) =>
    _sheet<void>(
        context,
        _TargetForm(month: month, sales: sales, collection: collection));

class _TargetForm extends StatefulWidget {
  const _TargetForm(
      {required this.month, required this.sales, required this.collection});
  final DateTime month;
  final double sales;
  final double collection;

  @override
  State<_TargetForm> createState() => _TargetFormState();
}

class _TargetFormState extends State<_TargetForm> {
  late final _sales = TextEditingController(
      text: widget.sales > 0 ? numText(widget.sales) : '');
  late final _coll = TextEditingController(
      text: widget.collection > 0 ? numText(widget.collection) : '');

  @override
  void dispose() {
    _sales.dispose();
    _coll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('টার্গেট — ${monthTitle(widget.month)}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
            controller: _sales,
            keyboardType: _numKb,
            decoration: const InputDecoration(
                labelText: 'বিক্রির টার্গেট', prefixText: '৳ ')),
        const SizedBox(height: 10),
        TextField(
            controller: _coll,
            keyboardType: _numKb,
            decoration: const InputDecoration(
                labelText: 'আদায়ের টার্গেট', prefixText: '৳ ')),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
              'এই টার্গেট পরের মাসগুলোতেও চলবে। বদলাতে চাইলে সেই মাসে নতুন করে সেট করুন।',
              style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await AppDb.instance.setTarget(monthKey(widget.month),
                parseNum(_sales.text), parseNum(_coll.text));
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
// আউটলেট বাছাই (বিক্রি/আদায় এন্ট্রির জন্য)
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
