//TODO remove all the circular progress indicators where they are not needed
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
  import 'package:booksea_app/providers/auth_provider.dart'; 
import 'package:booksea_app/services/firestore_database.dart';
import 'package:booksea_app/models/type_model.dart';
import 'package:booksea_app/models/tour_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final firestoreDatabase = Provider.of<FirestoreDatabase>(context, listen: false);
    String boatId = authProvider.boatIds.first;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(160.0),
        child: AppBar(
          flexibleSpace: SizedBox(
            height: 180.0,
            child: Padding(
              padding: const EdgeInsets.only(top: 30.0),
              child: Material(
                elevation: 2.0,
                shadowColor: Theme.of(context).colorScheme.tertiaryContainer,
                child: InfiniteDatePicker(
                  initialDate: selectedDate,
                  onDateChange: (date) {
                    setState(() {
                      selectedDate = date;
                    }); 
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          TourDataStream(
            companyId: authProvider.companyId!,
            boatId: boatId,
            selectedDate: selectedDate,
            firestoreDatabase: firestoreDatabase,
          ),
          if (authProvider.boatIds.length > 1)
            Positioned(
              bottom: 10,
              left: 15,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.75,
                child: DropdownButtonFormField<String>(
                  value: authProvider.boatIds.first,
                  items: authProvider.boatIds.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      boatId = newValue!;
                    });
                  },
                  hint: Text('Select an option'),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 7,
            left: authProvider.boatIds.length < 2 ? (MediaQuery.of(context).size.width / 2) - 28 : 15,
            child: FloatingActionButton(
              onPressed: () async {
                final companyId = authProvider.companyId;

                if (companyId != null) {
                  showTourSelectionModal(context, companyId, firestoreDatabase, authProvider, selectedDate, boatId);
                }
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              elevation: 3.0,
              child: Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InfiniteDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateChange;

  const InfiniteDatePicker({super.key, required this.initialDate, required this.onDateChange});

  @override
  InfiniteDatePickerState createState() => InfiniteDatePickerState();
}

class InfiniteDatePickerState extends State<InfiniteDatePicker> {
  late DateTime selectedDate;
  final DateTime startDate = DateTime(2025, 1, 1);
  final DateTime endDate = DateTime(2026, 2, 1);
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    _scrollController = ScrollController(
      initialScrollOffset: _calculateInitialOffset(),
    );
  }

  double _calculateInitialOffset() {
    final today = DateTime.now();
    if (today.isBefore(startDate)) {
      return 0.0;
    }
    final daysFromStart = today.difference(startDate).inDays;
    return daysFromStart * 78.9; // Assuming each item is 78.9 pixels wide
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) { 

    return Stack(
      children: [
        Positioned(
          left: 0,
          bottom:20,
          height: 125.0, // 70% of the top bar's height (200.0 * 0.7)
          child: Image.asset(
            'assets/Wave.png',
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: [ 
            Expanded(child: Container( 
            )), // This will push the SizedBox to the bottom
            SizedBox( 
              height: 115.0,
              child: Column(
                children: [ 
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: endDate.difference(startDate).inDays + 1,
                      itemBuilder: (context, index) {
                        final date = startDate.add(Duration(days: index));
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDate = date;
                            });
                            widget.onDateChange(date);
                          },
                          child: Container(
                            width: 55, 
                            margin: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(30), // Reduced radius for smoother edges
                              boxShadow: [
                                BoxShadow(
                                  color: selectedDate == date ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.primary,
                                  blurRadius: 6, // Increased blur for smoother appearance
                                  offset: Offset(0, 1), // Slight offset for a softer shadow
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  date.day.toString(),
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: selectedDate == date ? Theme.of(context).colorScheme.primary : DateTime.now().day == date.day && DateTime.now().month == date.month && DateTime.now().year == date.year ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary.withOpacity(0.5)), 
                                ),
                                Text(
                                  _getMonthName(date.month),
                                  style: TextStyle(fontSize: 12, color: selectedDate == date ? Theme.of(context).colorScheme.primary : DateTime.now().day == date.day && DateTime.now().month == date.month && DateTime.now().year == date.year ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 20.0,  
                    color: Theme.of(context).colorScheme.tertiaryContainer,  
                    child: Center(child: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.tertiary),)),
                  )
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const List<String> monthNames = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return monthNames[month - 1];
  }
}

class TourSelectionModal extends StatefulWidget {
  final String companyId;
  final FirestoreDatabase firestoreDatabase;
  final AuthProvider authProvider;
  final DateTime selectedDate;
  final String boatId;

  const TourSelectionModal({  
    super.key,
    required this.companyId,
    required this.firestoreDatabase,
    required this.authProvider,
    required this.selectedDate,
    required this.boatId,
  });
  
  @override
  // ignore: library_private_types_in_public_api
  _TourSelectionModalState createState() => _TourSelectionModalState();
}

class _TourSelectionModalState extends State<TourSelectionModal> {
  late Future<Map<String, dynamic>> _tourTypesAndBoatInfoFuture;
  String? _selectedTourType;
  final TextEditingController _capacityController = TextEditingController(); 
  final TextEditingController _tourNameController = TextEditingController();
  TimeOfDay? startTime;
  TimeOfDay? endTime; 
  late DateTime modalSelectedDate;
  final TextEditingController _notesController = TextEditingController();
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    modalSelectedDate = widget.selectedDate;
    startDate = widget.selectedDate; // Initialize startDate
    endDate = widget.selectedDate; // Initialize endDate
    super.initState();
    _tourTypesAndBoatInfoFuture = widget.firestoreDatabase.getTourTypesAndBoatInfo(widget.companyId, widget.boatId);
    _tourTypesAndBoatInfoFuture.then((data) {
      List<TypeModel> types = data['tourTypes'];
      if (types.isNotEmpty) {
        setState(() {
          _tourNameController.text = '${data['boatInfo'].name} ${types.first.typeName}';
          _selectedTourType = types.first.typeName;
          _capacityController.text =  data['boatInfo'].capacity.toString();
          if (startTime == null && endTime == null) { // Ensure initialization happens only once
            startTime = TimeOfDay.fromDateTime(types.first.startTime);
            endTime = TimeOfDay.fromDateTime(types.first.endTime);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 0.3,
                maxHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _tourTypesAndBoatInfoFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: \${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!['tourTypes'].isEmpty) {
                        return Center(child: Text('No tour types available'));
                      } else {
                        List<TypeModel> types = snapshot.data!['tourTypes'];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedTourType,
                              items: types.map((TypeModel type) {
                                return DropdownMenuItem<String>(
                                  value: type.typeName,
                                  child: Text(type.typeName),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedTourType = newValue;
                                  TypeModel selectedType = types.firstWhere((type) => type.typeName == newValue);
                                  _tourNameController.text = '${snapshot.data!['boatInfo'].name} ${selectedType.typeName}';
                                  _capacityController.text = snapshot.data!['boatInfo'].capacity.toString();
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Select a Tour Type',
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              decoration: InputDecoration(labelText: 'Tour Name'),
                              controller: _tourNameController,
                              onChanged: (value) {
                                setState(() {
                                  _tourNameController.text = value;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _capacityController,
                              decoration: InputDecoration(labelText: 'Capacity'),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _capacityController.text = value;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            // Start Date and Time Picker
                            SizedBox(
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Start',
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${startDate.day}.${startDate.month}.${startDate.year} at ${startTime?.format(context) ?? 'Select Time'}'),
                                    trailing: Icon(Icons.keyboard_arrow_right),
                                    onTap: () async {
                                      DateTime? pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: startDate,
                                        firstDate: DateTime(2024),
                                        lastDate: DateTime(2101),
                                      );
                                      if (pickedDate != null) {
                                        TimeOfDay? pickedTime = await showTimePicker(
                                          context: context,
                                          initialTime: startTime ?? TimeOfDay.now(),
                                        );
                                        if (pickedTime != null) {
                                          setState(() {
                                            startDate = pickedDate;
                                            startTime = pickedTime;
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // End Date and Time Picker
                            SizedBox(
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End',
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${endDate.day}.${endDate.month}.${endDate.year} at ${endTime?.format(context) ?? 'Select Time'}'),
                                    trailing: Icon(Icons.keyboard_arrow_right),
                                    onTap: () async {
                                      DateTime? pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: endDate,
                                        firstDate: DateTime(2024),
                                        lastDate: DateTime(2101),
                                      );
                                      if (pickedDate != null) {
                                        TimeOfDay? pickedTime = await showTimePicker(
                                          context: context,
                                          initialTime: endTime ?? TimeOfDay.now(),
                                        );
                                        if (pickedTime != null) {
                                          setState(() {
                                            endDate = pickedDate;
                                            endTime = pickedTime;
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              decoration: InputDecoration(labelText: 'Notes'),
                              controller: _notesController,
                              onChanged: (value) {
                                setState(() {
                                  _notesController.text = value;
                                });
                              },
                            ),
                            const SizedBox(height: 20), 
                            Center(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (_selectedTourType != null && startTime != null && endTime != null) {
                                    final startDateTime = DateTime(
                                      startDate.year,
                                      startDate.month,
                                      startDate.day,
                                      startTime!.hour,
                                      startTime!.minute,
                                    );

                                    final endDateTime = DateTime(
                                      endDate.year,
                                      endDate.month,
                                      endDate.day,
                                      endTime!.hour,      
                                      endTime!.minute,
                                    );

                                    final tour = TourModel( 
                                      tourName: _tourNameController.text,
                                      tourType: _selectedTourType!,
                                      capacity: int.tryParse(_capacityController.text) ?? 0,
                                      startTime: Timestamp.fromDate(startDateTime),
                                      endTime: Timestamp.fromDate(endDateTime),
                                      note: _notesController.text,  
                                    );

                                    await widget.firestoreDatabase.createTour(
                                      widget.companyId,
                                      widget.authProvider.boatIds.first,
                                      tour,
                                    );

                                    if (mounted) {
                                      Navigator.of(context).pop(); // Close the modal
                                    }
                                  }
                                },
                                child: Text('Create Tour'),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
void showTourSelectionModal(BuildContext context, String companyId, FirestoreDatabase firestoreDatabase, AuthProvider authProvider, DateTime selectedDate, String boatId ) {
  showModalBottomSheet(
    context: context,
    isDismissible: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return TourSelectionModal(
        companyId: companyId,
        firestoreDatabase: firestoreDatabase,
        authProvider: authProvider,
        selectedDate: selectedDate,
        boatId: boatId,
      );
    },
  );
} 

//Tour data stream scrollable list
class TourDataStream extends StatelessWidget {
  final String companyId;
  final String boatId;
  final DateTime selectedDate;
  final FirestoreDatabase firestoreDatabase;

  TourDataStream({required this.companyId, required this.boatId, required this.selectedDate, required this.firestoreDatabase});

  @override

  Widget build(BuildContext context) {

    return StreamBuilder<List<TourModel>>(
      stream: firestoreDatabase.getToursStream(
        companyId, 
        boatId, 
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0), 
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59)
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No tour data available'));
        } else {
          print('Tour data: ${snapshot.data}');
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final tour = snapshot.data![index];
              return TourCard(tour: tour);
            },
          );
        }
      },
    );
  }
}

class TourCard extends StatelessWidget {
  final TourModel tour;

  TourCard({required this.tour});

  @override
  Widget build(BuildContext context) {
    return Card( 
      margin: EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [ 
                  Container(
                    height: 40, // Set a fixed height for the row
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center, // Centering vertically
                      children: [
                        Expanded(child: Text(tour.tourName  )), // Centering text
                        Expanded(child: Text('${tour.filled} / ${tour.capacity}', textAlign: TextAlign.end)),
                      ],
                    ),
                  ), 
                  Container(
                    height: 40, // Set a fixed height for the row
                    child: Center(child: Text('${tour.startTime.toDate().hour}:${tour.startTime.toDate().minute.toString().padLeft(2, '0')} - ${tour.endTime.toDate().hour}:${tour.endTime.toDate().minute.toString().padLeft(2, '0')}')), 
                  ),
                  Container(
                    height: 40, // Set a fixed height for the row
                    child: Center(
                      child: Text(tour.startTime.toDate().toLocal().toString().split(' ')[0] == tour.endTime.toDate().toLocal().toString().split(' ')[0]
                          ? tour.startTime.toDate().toLocal().toString().split(' ')[0]
                          : '${tour.startTime.toDate().toLocal().toString().split(' ')[0]} - ${tour.endTime.toDate().toLocal().toString().split(' ')[0]}'),
                    ),
                  ),
                  Container(
                    height: 40, // Set a fixed height for the row
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center, // Centering vertically
                      children: [
                        Expanded(child: Text(tour.tourType)), // Centering text
                        IconButton(onPressed: () {}, icon: Icon(Icons.open_in_browser))
                      ],
                    ),
                  )
                ], 
        ),
      ),
    );
  }
}


//TODO Update the tour

//TODO Delete the tour

//TODO Add a group to the tour

//TODO Update the group of the tour

//TODO Delete the group of the tour

//TODO Get all the tours for the date range selectedDate 00:00:00 - 23:59:59

//TODO Make the topbar infinite scrollable from 1.1.2025 to 1.2.2026
 
