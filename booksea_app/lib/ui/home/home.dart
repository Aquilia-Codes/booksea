import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:booksea_app/providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false); 
    DateTime selectedDate = DateTime.now();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(200.0),
        child: AppBar(
          flexibleSpace: SizedBox(
            height: 200.0,
            child: Padding(
              padding: const EdgeInsets.only(top: 30.0),
              child: EasyDateTimeLine(
                initialDate: selectedDate, 
                onDateChange: (date) {
                  // Handle date change
                  selectedDate = date;
                  print(selectedDate);
                }, 
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
