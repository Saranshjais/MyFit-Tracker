import 'package:flutter/material.dart';

import 'progress_screen.dart';
import 'weight_entry_sheet.dart';

class WeightHistoryScreen extends StatelessWidget {
  const WeightHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weight history')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => showWeightEntrySheet(context),
      icon: const Icon(Icons.add),
      label: const Text('Record weight'),
    ),
    body: const WeightTab(),
  );
}
