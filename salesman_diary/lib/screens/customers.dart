import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customer_detail.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('কাস্টমার'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'নাম, দোকান বা ফোন দিয়ে খুঁজুন',
                isDense: true,
                filled: true,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('নতুন কাস্টমার'),
        onPressed: () => showCustomerSheet(context),
      ),
      body: DbBuilder<List<Rec>>(
        load: () => AppDb.instance.customers(_q),
        builder: (context, list) {
          if (list.isEmpty) {
            return EmptyNote(_q.isEmpty
                ? 'এখনো কোনো কাস্টমার নেই।\nনিচের বাটন চেপে প্রথম কাস্টমার যোগ করুন।'
                : 'কোনো কাস্টমার পাওয়া যায়নি');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              final name = c['name'] as String;
              final shop = (c['shop'] as String?) ?? '';
              final phone = (c['phone'] as String?) ?? '';
              final due = (c['due'] as num).toDouble();
              final sub = [shop, phone].where((s) => s.isNotEmpty).join(' · ');
              return ListTile(
                leading: CircleAvatar(child: Text(name.characters.first)),
                title: Text(name),
                subtitle: sub.isEmpty ? null : Text(sub),
                trailing: due > 0
                    ? Text(taka(due),
                        style: TextStyle(
                            color: cs.error, fontWeight: FontWeight.bold))
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CustomerDetail(id: c['id'] as int)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
