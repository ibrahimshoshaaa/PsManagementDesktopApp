import 'package:flutter/material.dart';

import '../shared/stations_screen.dart';

class DrinkTablesScreen extends StatelessWidget {
  const DrinkTablesScreen({super.key});

  @override
  Widget build(BuildContext context) => const StationsScreen(drinks: true);
}
