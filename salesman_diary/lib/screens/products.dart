import 'package:flutter/material.dart';

import '../db.dart';
import '../sheets.dart';
import '../utils.dart';
import '../widgets.dart';

/// প্রোডাক্ট ও দামের তালিকা (অর্ডার দিলে নিজে থেকেও জমা হয়)
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('প্রোডাক্ট ও দাম')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('নতুন প্রোডাক্ট'),
        onPressed: () => showProductSheet(context),
      ),
      body: DbBuilder<List<Rec>>(
        load: () => AppDb.instance.products(),
        builder: (context, rows) {
          if (rows.isEmpty) {
            return const EmptyNote(
                'এখনো কোনো প্রোডাক্ট নেই।\nঅর্ডার দিলে প্রোডাক্ট ও দাম নিজে থেকেই জমা হবে,\nচাইলে এখানে হাতেও যোগ করতে পারেন।');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return ListTile(
                title: Text(r['name'] as String),
                onTap: () => showProductSheet(context, existing: r),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(taka(r['price'] as num),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      if (await confirm(context, 'এই প্রোডাক্ট তালিকা থেকে মুছবেন?',
                          yes: 'মুছুন')) {
                        await AppDb.instance
                            .deleteRow('products', r['id'] as int);
                      }
                    },
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
