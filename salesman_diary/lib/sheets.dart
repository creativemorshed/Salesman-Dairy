import 'package:flutter/material.dart';

import 'db.dart';
import 'utils.dart';
import 'widgets.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding:
          EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: SingleChildScrollView(child: child),
    ),
  );
}

const _numKb = TextInputType.numberWithOptions(decimal: true);

// =====================================================================
// কাস্টমার যোগ / এডিট
// =====================================================================
Future<void> showCustomerSheet(BuildContext context, {Rec? existing}) =>
    _sheet<void>(context, _CustomerForm(existing: existing));

class _CustomerForm extends StatefulWidget {
  const _CustomerForm({this.existing});
  final Rec? existing;

  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  String _s(String k) => (widget.existing?[k] as String?) ?? '';
  late final _name = TextEditingController(text: _s('name'));
  late final _shop = TextEditingController(text: _s('shop'));
  late final _phone = TextEditingController(text: _s('phone'));
  late final _address = TextEditingController(text: _s('address'));
  late final _note = TextEditingController(text: _s('note'));
  String? _err;

  @override
  void dispose() {
    for (final c in [_name, _shop, _phone, _address, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'কাস্টমারের নাম লিখুন');
      return;
    }
    await AppDb.instance.saveCustomer(
      {
        'name': name,
        'shop': _shop.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'note': _note.text.trim(),
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
        Text(widget.existing == null ? 'নতুন কাস্টমার' : 'কাস্টমার এডিট',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'নাম *')),
        const SizedBox(height: 10),
        TextField(
            controller: _shop,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'দোকানের নাম')),
        const SizedBox(height: 10),
        TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'ফোন নম্বর')),
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
// অর্ডার যোগ
// =====================================================================
Future<void> showOrderSheet(BuildContext context, int customerId) =>
    _sheet<void>(context, _OrderForm(customerId: customerId));

class _OrderForm extends StatefulWidget {
  const _OrderForm({required this.customerId});
  final int customerId;

  @override
  State<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<_OrderForm> {
  final _product = TextEditingController();
  final _productFocus = FocusNode();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _paid = TextEditingController();
  final Map<String, double> _known = {}; // আগের প্রোডাক্ট → সর্বশেষ দাম
  String _date = today();
  String? _err;

  @override
  void initState() {
    super.initState();
    AppDb.instance.products().then((rows) {
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          _known[r['name'] as String] = (r['price'] as num).toDouble();
        }
      });
    });
  }

  double get _total => parseNum(_qty.text) * parseNum(_price.text);

  @override
  void dispose() {
    for (final c in [_product, _qty, _price, _paid]) {
      c.dispose();
    }
    _productFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final product = _product.text.trim();
    final qty = parseNum(_qty.text);
    final price = parseNum(_price.text);
    if (product.isEmpty) {
      setState(() => _err = 'প্রোডাক্টের নাম লিখুন');
      return;
    }
    if (qty <= 0) {
      setState(() => _err = 'পরিমাণ ০ এর বেশি হতে হবে');
      return;
    }
    await AppDb.instance.addOrder(
      customerId: widget.customerId,
      date: _date,
      product: product,
      qty: qty,
      price: price,
      paid: parseNum(_paid.text),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('নতুন অর্ডার', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        // আগে বিক্রি করা প্রোডাক্টের নাম সাজেস্ট করে; বাছলে দামও বসে যায়
        RawAutocomplete<String>(
          textEditingController: _product,
          focusNode: _productFocus,
          optionsBuilder: (v) {
            final q = v.text.trim().toLowerCase();
            return _known.keys
                .where((k) => q.isEmpty || k.toLowerCase().contains(q))
                .take(8);
          },
          onSelected: (s) {
            final pr = _known[s];
            if (pr != null && pr > 0) _price.text = numText(pr);
            setState(() {});
          },
          fieldViewBuilder: (context, ctrl, node, onSubmit) => TextField(
            controller: ctrl,
            focusNode: node,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'প্রোডাক্ট *'),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 220, maxWidth: 340),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      ListTile(
                        dense: true,
                        title: Text(o),
                        trailing: Text(taka(_known[o] ?? 0)),
                        onTap: () => onSelected(o),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
                controller: _qty,
                keyboardType: _numKb,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'পরিমাণ')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
                controller: _price,
                keyboardType: _numKb,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'দাম (প্রতি একক)')),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: _paid,
            keyboardType: _numKb,
            decoration:
                const InputDecoration(labelText: 'নগদ পেলাম (ঐচ্ছিক)')),
        const SizedBox(height: 8),
        Row(children: [
          Text('মোট: ${taka(_total)}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(niceDate(_date)),
            onPressed: () async {
              final d = await pickDate(context, initial: _date);
              if (d != null) setState(() => _date = d);
            },
          ),
        ]),
        ErrorText(_err),
        FilledButton(onPressed: _save, child: const Text('সংরক্ষণ')),
      ],
    );
  }
}

// =====================================================================
// টাকা আদায়
// =====================================================================
Future<void> showPaymentSheet(BuildContext context, int customerId,
        {String? currentReminder, double? due}) =>
    _sheet<void>(
        context,
        _PaymentForm(
            customerId: customerId, currentReminder: currentReminder, due: due));

class _PaymentForm extends StatefulWidget {
  const _PaymentForm(
      {required this.customerId, this.currentReminder, this.due});
  final int customerId;
  final String? currentReminder;
  final double? due;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  late final _amount = TextEditingController(
      text: (widget.due != null && widget.due! > 0)
          ? widget.due!.toStringAsFixed(widget.due! % 1 == 0 ? 0 : 2)
          : '');
  final _note = TextEditingController();
  String _date = today();
  late String? _reminder = widget.currentReminder;
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
    final db = AppDb.instance;
    await db.addPayment(
      customerId: widget.customerId,
      date: _date,
      amount: amount,
      note: _note.text.trim(),
    );
    if (_reminder != widget.currentReminder) {
      await db.setReminder(widget.customerId, 'pay_reminder', _reminder);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('টাকা পেলাম', style: Theme.of(context).textTheme.titleLarge),
        if (widget.due != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('বর্তমান বাকি: ${taka(widget.due!)}'),
          ),
        const SizedBox(height: 12),
        TextField(
            controller: _amount,
            keyboardType: _numKb,
            decoration: const InputDecoration(labelText: 'টাকার পরিমাণ *')),
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
        ReminderField(
          label: 'পরের তাগাদার তারিখ',
          value: _reminder,
          onChanged: (v) => setState(() => _reminder = v),
        ),
        ErrorText(_err),
        FilledButton(onPressed: _save, child: const Text('সংরক্ষণ')),
      ],
    );
  }
}

// =====================================================================
// ভিজিট সম্পন্ন
// =====================================================================
Future<void> showVisitSheet(BuildContext context, int customerId, String name) =>
    _sheet<void>(context, _VisitForm(customerId: customerId, name: name));

class _VisitForm extends StatefulWidget {
  const _VisitForm({required this.customerId, required this.name});
  final int customerId;
  final String name;

  @override
  State<_VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends State<_VisitForm> {
  final _note = TextEditingController();
  String? _next = afterDays(7);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppDb.instance.logVisit(
      widget.customerId,
      today(),
      _note.text.trim(),
      nextVisit: _next,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ভিজিট সম্পন্ন — ${widget.name}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'ভিজিটের নোট (কী কথা হলো?)')),
        const SizedBox(height: 12),
        ReminderField(
          label: 'পরের ভিজিট',
          value: _next,
          onChanged: (v) => setState(() => _next = v),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('ভিজিট সংরক্ষণ')),
      ],
    );
  }
}

// =====================================================================
// রিমাইন্ডার পরিবর্তন (কাস্টমার ডিটেইলস থেকে)
// =====================================================================
Future<void> showReminderSheet(BuildContext context,
        {required int customerId,
        required String column,
        required String title,
        String? current}) =>
    _sheet<void>(
        context,
        _ReminderForm(
            customerId: customerId,
            column: column,
            title: title,
            current: current));

class _ReminderForm extends StatefulWidget {
  const _ReminderForm({
    required this.customerId,
    required this.column,
    required this.title,
    this.current,
  });
  final int customerId;
  final String column;
  final String title;
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
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ReminderField(
            label: 'তারিখ', value: _v, onChanged: (v) => setState(() => _v = v)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await AppDb.instance.setReminder(widget.customerId, widget.column, _v);
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
// কাস্টমার বাছাই (আজকের ভিজিটে যোগ করার জন্য)
// =====================================================================
Future<Rec?> pickCustomer(BuildContext context) {
  return showModalBottomSheet<Rec>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.75,
      child: const _CustomerPicker(),
    ),
  );
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  List<Rec> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    final r = await AppDb.instance.customers(q);
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
            autofocus: false,
            onChanged: _search,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'কাস্টমার খুঁজুন',
                isDense: true),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _list.isEmpty
                  ? const EmptyNote('কোনো কাস্টমার পাওয়া যায়নি')
                  : ListView.builder(
                      itemCount: _list.length,
                      itemBuilder: (_, i) {
                        final c = _list[i];
                        final shop = (c['shop'] as String?) ?? '';
                        return ListTile(
                          title: Text(c['name'] as String),
                          subtitle: shop.isEmpty ? null : Text(shop),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// =====================================================================
// প্রোডাক্ট যোগ / এডিট
// =====================================================================
Future<void> showProductSheet(BuildContext context, {Rec? existing}) =>
    _sheet<void>(context, _ProductForm(existing: existing));

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.existing});
  final Rec? existing;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final _name =
      TextEditingController(text: (widget.existing?['name'] as String?) ?? '');
  late final _price = TextEditingController(
      text: widget.existing == null
          ? ''
          : numText((widget.existing!['price'] as num).toDouble()));
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'প্রোডাক্টের নাম লিখুন');
      return;
    }
    try {
      await AppDb.instance.saveProduct(name, parseNum(_price.text),
          id: widget.existing?['id'] as int?);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _err = 'এই নামে প্রোডাক্ট আগেই আছে');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.existing == null ? 'নতুন প্রোডাক্ট' : 'প্রোডাক্ট এডিট',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'প্রোডাক্টের নাম *')),
        const SizedBox(height: 10),
        TextField(
            controller: _price,
            keyboardType: _numKb,
            decoration: const InputDecoration(labelText: 'দাম (প্রতি একক)')),
        ErrorText(_err),
        FilledButton(onPressed: _save, child: const Text('সংরক্ষণ')),
      ],
    );
  }
}
