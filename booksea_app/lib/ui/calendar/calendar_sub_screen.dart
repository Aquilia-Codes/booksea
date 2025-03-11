import 'package:flutter/material.dart';

class CalendarSubScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
      ),
      body: Center(
        child: Text(
          'Calendar',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
