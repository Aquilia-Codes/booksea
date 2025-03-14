//TODO remove all the circular progress indicators where they are not needed
import 'dart:async';
import 'package:booksea_app/models/group_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:provider/provider.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/services/firestore_database.dart';
import 'package:booksea_app/models/type_model.dart';
import 'package:booksea_app/models/tour_model.dart';
import 'package:provider/single_child_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime selectedDate;
  late String boatId;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    boatId = authProvider.boatIds.first;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final firestoreDatabase =
        Provider.of<FirestoreDatabase>(context, listen: false);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(160),
        child: AppBar(
          flexibleSpace: SizedBox(
            child: Padding(
              padding: const EdgeInsets.only(top: 40.0),
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
                  value: boatId,
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
                      borderSide: BorderSide(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 7,
            right: authProvider.boatIds.length < 2
                ? (MediaQuery.of(context).size.width / 2) - 28
                : 15,
            child: FloatingActionButton(
              onPressed: () async {
                final companyId = authProvider.companyId;

                if (companyId != null) {
                  showTourSelectionModal(context, companyId, firestoreDatabase,
                      authProvider, selectedDate, boatId);
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

  const InfiniteDatePicker(
      {super.key, required this.initialDate, required this.onDateChange});

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
        Positioned.fill(
          child: Image.asset(
            'assets/Wave.png',
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: [
            SizedBox(height: 25),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 55,
                          margin: EdgeInsets.only(
                              left: 12, right: 12, top: 8, bottom: 7),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: selectedDate == date
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Theme.of(context).colorScheme.primary,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 10.0,
                                right: 10.0,
                                top: 15.0,
                                bottom: 15.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  date.day.toString(),
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: selectedDate == date
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : DateTime.now().day == date.day &&
                                                  DateTime.now().month ==
                                                      date.month &&
                                                  DateTime.now().year ==
                                                      date.year
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .secondary
                                                  .withOpacity(0.5)),
                                ),
                                Text(
                                  _getMonthName(date.month),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: selectedDate == date
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : DateTime.now().day == date.day &&
                                                  DateTime.now().month ==
                                                      date.month &&
                                                  DateTime.now().year ==
                                                      date.year
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .secondary
                                                  .withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ), // Add space between selected date and scrollable dates
            Container(
              margin: EdgeInsets.only(bottom: 2),
              child: Center(
                child: Text(
                  '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.tertiary),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const List<String> monthNames = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
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
    _tourTypesAndBoatInfoFuture = widget.firestoreDatabase
        .getTourTypesAndBoatInfo(widget.companyId, widget.boatId);
    _tourTypesAndBoatInfoFuture.then((data) {
      List<TypeModel> types = data['tourTypes'];
      if (types.isNotEmpty) {
        setState(() {
          _tourNameController.text =
              '${data['boatInfo'].name} ${types.first.typeName}';
          _selectedTourType = types.first.typeName;
          _capacityController.text = data['boatInfo'].capacity.toString();
          if (startTime == null && endTime == null) {
            // Ensure initialization happens only once
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
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      } else if (!snapshot.hasData ||
                          snapshot.data!['tourTypes'].isEmpty) {
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
                                  TypeModel selectedType = types.firstWhere(
                                      (type) => type.typeName == newValue);
                                  _tourNameController.text =
                                      '${snapshot.data!['boatInfo'].name} ${selectedType.typeName}';
                                  _capacityController.text = snapshot
                                      .data!['boatInfo'].capacity
                                      .toString();
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Select a Tour Type',
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              decoration:
                                  InputDecoration(labelText: 'Tour Name'),
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
                              decoration:
                                  InputDecoration(labelText: 'Capacity'),
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
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer),
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                        '${startDate.day}.${startDate.month}.${startDate.year} at ${startTime?.format(context) ?? 'Select Time'}'),
                                    trailing: Icon(Icons.keyboard_arrow_right),
                                    onTap: () async {
                                      DateTime? pickedDate =
                                          await showDatePicker(
                                        context: context,
                                        initialDate: startDate,
                                        firstDate: DateTime(2024),
                                        lastDate: DateTime(2101),
                                      );
                                      if (pickedDate != null) {
                                        TimeOfDay? pickedTime =
                                            await showTimePicker(
                                          context: context,
                                          initialTime:
                                              startTime ?? TimeOfDay.now(),
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
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer),
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                        '${endDate.day}.${endDate.month}.${endDate.year} at ${endTime?.format(context) ?? 'Select Time'}'),
                                    trailing: Icon(Icons.keyboard_arrow_right),
                                    onTap: () async {
                                      DateTime? pickedDate =
                                          await showDatePicker(
                                        context: context,
                                        initialDate: endDate,
                                        firstDate: DateTime(2024),
                                        lastDate: DateTime(2101),
                                      );
                                      if (pickedDate != null) {
                                        TimeOfDay? pickedTime =
                                            await showTimePicker(
                                          context: context,
                                          initialTime:
                                              endTime ?? TimeOfDay.now(),
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
                                  if (_selectedTourType != null &&
                                      startTime != null &&
                                      endTime != null) {
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
                                      capacity: int.tryParse(
                                              _capacityController.text) ??
                                          0,
                                      startTime:
                                          Timestamp.fromDate(startDateTime),
                                      endTime: Timestamp.fromDate(endDateTime),
                                      note: _notesController.text,
                                    );

                                    try {
                                      await widget.firestoreDatabase.createTour(
                                        widget.companyId,
                                        widget.boatId,
                                        tour,
                                      );

                                      if (mounted) {
                                        Navigator.of(context)
                                            .pop(); // Close the modal
                                      }
                                    } catch (error) {
                                      // Handle the error (e.g., show a snackbar or dialog)
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'There was an error creating the tour. Please try again.')),
                                      );
                                      if (mounted) {
                                        Navigator.of(context)
                                            .pop(); // Close the modal
                                      }
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

void showTourSelectionModal(
    BuildContext context,
    String companyId,
    FirestoreDatabase firestoreDatabase,
    AuthProvider authProvider,
    DateTime selectedDate,
    String boatId) {
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

  TourDataStream(
      {required this.companyId,
      required this.boatId,
      required this.selectedDate,
      required this.firestoreDatabase});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TourModel>>(
      stream: firestoreDatabase.getToursStream(
          companyId,
          boatId,
          DateTime(
              selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0),
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23,
              59, 59)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No tour data available'));
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final tour = snapshot.data![index];
              return TourCard(
                  tour: tour,
                  firestoreDatabase: firestoreDatabase,
                  companyId: companyId,
                  boatId: boatId);
            },
          );
        }
      },
    );
  }
}

class TourCard extends StatelessWidget {
  final TourModel tour;
  final FirestoreDatabase firestoreDatabase;
  final String companyId;
  final String boatId;

  TourCard(
      {required this.tour,
      required this.firestoreDatabase,
      required this.companyId,
      required this.boatId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          openTourPopup(context, tour, firestoreDatabase, companyId, boatId),
      child: Card(
        margin:
            EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 20.0),
        child: Padding(
          padding: const EdgeInsets.only(
              left: 20.0, right: 20.0, top: 15.0, bottom: 15.0),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 10.0),
                height: 40, // Set a fixed height for the row
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Centering vertically
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text(tour.tourName.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary))), // Centering text
                    Expanded(
                        flex: 1,
                        child: Text('${tour.filled} / ${tour.capacity}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.secondary))),
                  ],
                ),
              ),
              Container(
                height: 30, // Set a fixed height for the row
                child: Center(
                    child: Text(
                        '${tour.startTime.toDate().hour}:${tour.startTime.toDate().minute.toString().padLeft(2, '0')} - ${tour.endTime.toDate().hour}:${tour.endTime.toDate().minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary))),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 10.0),
                height: 20, // Set a fixed height for the row
                child: Center(
                  child: Text(
                      tour.startTime
                                  .toDate()
                                  .toLocal()
                                  .toString()
                                  .split(' ')[0] ==
                              tour.endTime
                                  .toDate()
                                  .toLocal()
                                  .toString()
                                  .split(' ')[0]
                          ? tour.startTime
                              .toDate()
                              .toLocal()
                              .toString()
                              .split(' ')[0]
                          : '${tour.startTime.toDate().day}.${tour.startTime.toDate().month}.${tour.startTime.toDate().year}. - ${tour.endTime.toDate().day}.${tour.endTime.toDate().month}.${tour.endTime.toDate().year}.',
                      style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.secondary)),
                ),
              ),
              Container(
                height: 40, // Set a fixed height for the row
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Centering vertically
                  children: [
                    Expanded(
                        child: Text(tour.tourType.toUpperCase(),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary))), // Centering text
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Open the tour in a popup
void openTourPopup(BuildContext context, TourModel tour,
    FirestoreDatabase firestoreDatabase, String companyId, String boatId) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          width:
              MediaQuery.of(context).size.width * 0.9, // Set the desired width
          height: MediaQuery.of(context).size.height *
              0.6, // Set the desired height
          child: Stack(
            children: [
              TourPopup(
                tour: tour,
                firestoreDatabase: firestoreDatabase,
                companyId: companyId,
                boatId: boatId,
              ),
            ],
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment(1.5, 0),
            children: [
              Container(
                margin: EdgeInsets.only(right: 12.0),
                width: 120, // Adjust width as needed
                height: 46,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .tertiaryContainer
                          .withOpacity(0.5),
                      blurRadius: 2,
                      offset: Offset(-1, 0),
                    ),
                  ],
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary, // Match button shape
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(50),
                    bottomLeft: Radius.circular(50),
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 20.0), // Adjust padding as needed
                      child: Text(
                        '${tour.price.round()}€',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  iconSize: 25,
                  padding: EdgeInsets.all(10),
                  shape: CircleBorder(),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => openGroupAddPopup(context, tour.id, companyId,
                    boatId, firestoreDatabase, tour),
                child: Icon(Icons.add,
                    color: Theme.of(context).colorScheme.onPrimary),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class TourPopup extends StatefulWidget {
  final TourModel tour;
  final FirestoreDatabase firestoreDatabase;
  final String companyId;
  final String boatId;

  TourPopup({
    required this.tour,
    required this.firestoreDatabase,
    required this.companyId,
    required this.boatId,
  });

  @override
  _TourPopupState createState() => _TourPopupState();
}

class _TourPopupState extends State<TourPopup> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
          children: [
            Center(
              child: Text(
                widget.tour.tourName.toUpperCase(),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: 10.0, bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      '${widget.tour.startTime.toDate().hour}:${widget.tour.startTime.toDate().minute.toString().padLeft(2, '0')} - ${widget.tour.endTime.toDate().hour}:${widget.tour.endTime.toDate().minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                  Text('${widget.tour.filled} / ${widget.tour.capacity}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            SingleChildScrollView(
              child: GroupDataStream(
                companyId: widget.companyId,
                boatId: widget.boatId,
                tourId: widget.tour.id,
                firestoreDatabase: widget.firestoreDatabase,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openTourEditPopup(BuildContext context, TourModel tour) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return TourEditPopup(tour: tour);
    },
  );
}

class TourEditPopup extends StatelessWidget {
  final TourModel tour;

  TourEditPopup({required this.tour});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(tour.tourName),
    );
  }
}

void openTourDeletePopup(BuildContext context, TourModel tour) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return TourDeletePopup(tour: tour);
    },
  );
}

class TourDeletePopup extends StatelessWidget {
  final TourModel tour;

  TourDeletePopup({required this.tour});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(tour.tourName),
    );
  }
}

class GroupDataStream extends StatelessWidget {
  final String companyId;
  final String boatId;
  final String tourId;
  final FirestoreDatabase firestoreDatabase;

  GroupDataStream({
    required this.companyId,
    required this.boatId,
    required this.tourId,
    required this.firestoreDatabase,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupModel>>(
      stream: firestoreDatabase.getGroups(companyId, boatId, tourId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('Add Groups!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
          );
        }
        return Container(
          height: MediaQuery.of(context).size.height * 0.6 - 75,
          child: SingleChildScrollView(
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return GroupCard(
                    group: snapshot.data![index],
                    companyId: companyId,
                    boatId: boatId,
                    tourId: tourId,
                    firestoreDatabase: firestoreDatabase);
              },
            ),
          ),
        );
      },
    );
  }
}

class GroupCard extends StatelessWidget {
  final GroupModel group;
  final String companyId;
  final String boatId;
  final String tourId;
  final FirestoreDatabase firestoreDatabase;

  GroupCard({
    required this.group,
    required this.companyId,
    required this.boatId,
    required this.tourId,
    required this.firestoreDatabase,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openGroupEditPopup(context, group),
      child: Card(
        margin:
            EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 20.0),
        child: Padding(
          padding: const EdgeInsets.only(
              left: 20.0, right: 20.0, top: 15.0, bottom: 15.0),
          child: Column(
            children: [
              Text(group.groupName),
              Text('${group.adultCount} adults'),
              Text('${group.childCount} children'),
              Text('${group.price.round()}€'),
              Text(group.paymentStatus),
              Text(group.bookerId),
              Text(group.mobileNumber),
            ],
          ),
        ),
      ),
    );
  }
}

void openGroupAddPopup(BuildContext context, String tourId, String companyId,
    String boatId, FirestoreDatabase firestoreDatabase, TourModel tour) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.6,
          child: GroupAddPopup(
            tourId: tourId,
            tour: tour,
            companyId: companyId,
            boatId: boatId,
            firestoreDatabase: firestoreDatabase,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
        ],
      );
    },
  );
}

class GroupAddPopup extends StatefulWidget {
  final String tourId;
  final TourModel tour;
  final String companyId;
  final String boatId;
  final FirestoreDatabase firestoreDatabase;

  GroupAddPopup({
    required this.tourId,
    required this.tour,
    required this.companyId,
    required this.boatId,
    required this.firestoreDatabase,
  });

  @override
  _GroupAddPopupState createState() => _GroupAddPopupState();
}

class _GroupAddPopupState extends State<GroupAddPopup> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _adultCountController = TextEditingController();
  final TextEditingController _childCountController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _paymentStatusController =
      TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    _adultCountController.dispose();
    _childCountController.dispose();
    _priceController.dispose();
    _paymentStatusController.dispose();
    _numberController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          TextField(
            controller: _groupNameController,
            decoration: InputDecoration(labelText: 'Group Name'),
          ),
          TextField(
            controller: _adultCountController,
            decoration: InputDecoration(labelText: 'Adult Count'),
          ),
          TextField(
            controller: _childCountController,
            decoration: InputDecoration(labelText: 'Child Count'),
          ),
          TextField(
            controller: _priceController,
            decoration: InputDecoration(labelText: 'Price'),
          ),
          DropdownButtonFormField<String>(
            value: _paymentStatusController.text.isNotEmpty
                ? _paymentStatusController.text
                : null,
            items: ['Paid', 'Reserved', 'Cancelled'].map((String status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(status),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _paymentStatusController.text = newValue!;
              });
            },
            decoration: InputDecoration(labelText: 'Payment Status'),
          ),
          Row(
            children: [
              Expanded(
                child: IntlPhoneField(
                  controller: _numberController,
                  disableLengthCheck: true,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(),
                    ),
                  ),
                  initialCountryCode: 'US',
                  onChanged: (phone) {
                    setState(() {
                      _mobileNumberController.dispose();
                      _mobileNumberController.text = phone.completeNumber;
                    });
                  },
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              final group = GroupModel(
                groupName: _groupNameController.text,
                adultCount: int.tryParse(_adultCountController.text) ?? 0,
                childCount: int.tryParse(_childCountController.text) ?? 0,
                price: double.tryParse(_priceController.text) ?? 0.0,
                paymentStatus: _paymentStatusController.text,
                bookerId: '',
                mobileNumber:
                    _mobileNumberController.text + _numberController.text,
              );
              if (widget.tour.filled + group.adultCount <=
                  widget.tour.capacity) {
                widget.firestoreDatabase.createGroup(
                    widget.companyId, widget.boatId, widget.tourId, group);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Group capacity exceeds tour capacity'),
                  ),
                );
              }
              Navigator.of(context).pop();
            },
            child: Text('Add Group'),
          ),
        ],
      ),
    );
  }
}

void openGroupEditPopup(BuildContext context, GroupModel group) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return GroupEditPopup(group: group);
    },
  );
}

class GroupEditPopup extends StatelessWidget {
  final GroupModel group;

  GroupEditPopup({required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(group.groupName),
    );
  }
}

void openGroupPopup(BuildContext context, GroupModel group) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return GroupPopup(group: group);
    },
  );
}

class GroupPopup extends StatelessWidget {
  final GroupModel group;

  GroupPopup({required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(group.groupName),
    );
  }
}

void openGroupDeletePopup(BuildContext context, GroupModel group) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return GroupDeletePopup(group: group);
    },
  );
}

class GroupDeletePopup extends StatelessWidget {
  final GroupModel group;

  GroupDeletePopup({required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(group.groupName),
    );
  }
}

//TODO Update the group of the tour (first filled-= adult count, price-= adult price*adult count + child price*child count, then filled += adult count, price += adult price*adult count + child price*child count)

//TODO Delete the group of the tour (filled -= adult count, price -= adult price*adult count + child price*child count)
