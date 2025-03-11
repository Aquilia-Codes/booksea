import 'package:flutter/material.dart';

class SearchAndFilterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search and Filter'),
      ),
      body: Center(
        child: Text(
          'Search and Filter',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
