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
      body: Stack(
        children: [
          Positioned(
            bottom: 7,
            left: 10, // Align the dropdown to the left
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8, // Dropdown takes 80% of the screen
              child: DropdownButton<String>(
                items: <String>['Option 1', 'Option 2', 'Option 3', 'Option 4'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (_) {
                  // Handle dropdown change
                },
                hint: Text('Select an option'),
              ),
            ),
          ),
          Positioned(
            bottom: 7,
            right: 10, // Align the button to the right
            child: FloatingActionButton(
              onPressed: () {
                print('Pressed');
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Icons.add,
                color: Colors.white,
              ),
              elevation: 3.0, // Set a smaller shadow
            ),
          ),
        ],
      ),
    );
  }
}
