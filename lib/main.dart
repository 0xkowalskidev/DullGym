import 'package:flutter/material.dart';
import 'package:dullgym/database/database_helper.dart';
import 'package:dullgym/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const DullGymApp());
}

class DullGymApp extends StatelessWidget {
  const DullGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DullGym',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
