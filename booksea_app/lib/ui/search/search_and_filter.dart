import 'package:flutter/material.dart';

class SearchAndFilterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/search.png'),
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Center(
          child: Text('Search and Filter'),
        ),
      ),
    );
  }
}
