import 'package:flutter/material.dart';
import 'eyes_page.dart';
import 'system_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(tabs: [
            Tab(text: 'Eyes'),
            Tab(text: 'System'),
          ]),
        ),
        body: const TabBarView(
          children: [
            EyesPage(),
            SystemPage(),
          ],
        ),
      ),
    );
  }
}
