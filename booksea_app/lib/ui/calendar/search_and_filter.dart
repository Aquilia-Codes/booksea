import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'search_and_filter_sub_screen.dart';

class SearchAndFilterScreen extends StatefulWidget {
  const SearchAndFilterScreen({super.key});

  @override
  _SearchAndFilterState createState() => _SearchAndFilterState();
}

class _SearchAndFilterState extends State<SearchAndFilterScreen> {
  bool isSearchIcon = false;

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
          isSearchIcon
              ? Center(child: CalendarScreen())
              : Center(child: SearchAndFilterSubScreen()),
          Positioned(
            bottom: 7,
            left:
                MediaQuery.of(context).size.width / 2 - 28, // Center the button
            child: FloatingActionButton(
              onPressed: () {
                _toggleIcon();
                print('Pressed');
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              elevation: 3.0,
              child: Icon(
                isSearchIcon ? Icons.search : Icons.calendar_today,
                color: Colors.white, // Set the icon color to white
              ), // Set a smaller shadow
            ),
          ),
        ],
      ),
    );
  }
}
