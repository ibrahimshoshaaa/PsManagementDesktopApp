import 'package:flutter/material.dart';

import '../shared/stations_screen.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) => const StationsScreen(drinks: false);
}
