import 'package:flutter/material.dart';
import 'calendar_sub_screen.dart';
import 'search_and_filter_screen.dart';
import 'package:booksea_app/providers/auth_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool isSearchIcon = true;

  void _toggleIcon() {
    setState(() {
      isSearchIcon = !isSearchIcon;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // This is where you would switch between the calendar and search/filter screens
          isSearchIcon ? Center(child: CalendarSubScreen()) : Center(child: SearchAndFilterScreen()),
          Positioned(
            bottom: 7,
            left: MediaQuery.of(context).size.width / 2 - 28, // Center the button
            child: FloatingActionButton(
              onPressed: () {
                _toggleIcon();
                print('Pressed');
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                isSearchIcon ? Icons.search : Icons.calendar_today,
                color: Colors.white, // Set the icon color to white
              ), 
              elevation: 3.0, // Set a smaller shadow
            ),
          ),
        ],
      ),
    );
  }
}
