//TODO make all loads happen better
import 'dart:async';
import 'package:booksea_app/models/group_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/services/firestore_database.dart';
import 'package:booksea_app/models/type_model.dart';
import 'package:booksea_app/models/tour_model.dart';
import 'package:booksea_app/ui/home/qr_image.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime selectedDate;
  late String boatId;
  late String companyId;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    boatId = authProvider.boatIds.first;
    companyId = authProvider.companyId!;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final firestoreDatabase =
        Provider.of<FirestoreDatabase>(context, listen: false);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.onPrimary,
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
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/home.png'),
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
          TourDataStream(
            companyId: companyId,
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
              heroTag: 'add_tour_fab',
              onPressed: () async {
                showTourSelectionModal(context, companyId, firestoreDatabase,
                    authProvider, selectedDate, boatId);
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
  bool _isButtonEnabled = true; // Ensure the button is enabled on load
  List<TypeModel> types = [];

  @override
  void initState() {
    modalSelectedDate = widget.selectedDate;
    startDate = widget.selectedDate; // Initialize startDate
    endDate = widget.selectedDate; // Initialize endDate
    super.initState();
    _tourTypesAndBoatInfoFuture = widget.firestoreDatabase
        .getTourTypesAndBoatInfo(widget.companyId, widget.boatId);
    _tourTypesAndBoatInfoFuture.then((data) {
      types = data['tourTypes'];
      if (types.isNotEmpty) {
        setState(() {
          _tourNameController.text =
              '${data['boatInfo'].name} ${types.first.typeName}';
          _selectedTourType = types.first.typeName;
          _capacityController.text = data['boatInfo'].capacity.toString();
          startTime = TimeOfDay.fromDateTime(types.first.startTime);
          endTime = TimeOfDay.fromDateTime(types.first.endTime);
        });
      }
    });
    _tourNameController.addListener(_updateButtonState);
    _capacityController.addListener(_updateButtonState);
    _notesController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _tourNameController.text.isNotEmpty &&
          _capacityController.text.isNotEmpty &&
          _selectedTourType != null &&
          startTime != null &&
          endTime != null;
    });
  }

  void _validateAndSubmit() async {
    if (_isButtonEnabled) {
      final companyId = widget.companyId;
      final firestoreDatabase = widget.firestoreDatabase;
      final selectedDate = widget.selectedDate;
      final boatId = widget.boatId;

      final tour = TourModel(
        tourName: _tourNameController.text,
        tourType: _selectedTourType!,
        capacity: int.tryParse(_capacityController.text) ?? 0,
        startTime: Timestamp.fromDate(DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          startTime!.hour,
          startTime!.minute,
        )),
        endTime: Timestamp.fromDate(DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          endTime!.hour,
          endTime!.minute,
        )),
        note: _notesController.text,
        typeImage: types
            .firstWhere((type) => type.typeName == _selectedTourType!)
            .typeImage,
      );

      try {
        await firestoreDatabase.createTour(companyId, boatId, tour);
        if (mounted) {
          Navigator.of(context).pop(); // Close the modal
        }
      } catch (error) {
        // Handle the error (e.g., show a snackbar or dialog)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('There was an error creating the tour. Please try again.'),
          ),
        );
        if (mounted) {
          Navigator.of(context).pop(); // Close the modal
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields before creating a tour'),
        ),
      );
    }
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
                        return Center(child: Text(''));
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData ||
                          snapshot.data!['tourTypes'].isEmpty) {
                        return Center(child: Text(''));
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
                                  startTime = TimeOfDay.fromDateTime(
                                      selectedType.startTime);
                                  endTime = TimeOfDay.fromDateTime(
                                      selectedType.endTime);
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
                              cursorColor:
                                  Theme.of(context).colorScheme.primary,
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
                              cursorColor:
                                  Theme.of(context).colorScheme.primary,
                              decoration:
                                  InputDecoration(labelText: 'Capacity'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
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
                                        firstDate:
                                            startDate, // Ensure end date is after start date
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
                                          DateTime potentialEndDateTime =
                                              DateTime(
                                            pickedDate.year,
                                            pickedDate.month,
                                            pickedDate.day,
                                            pickedTime.hour,
                                            pickedTime.minute,
                                          );
                                          DateTime startDateTime = DateTime(
                                            startDate.year,
                                            startDate.month,
                                            startDate.day,
                                            startTime?.hour ?? 0,
                                            startTime?.minute ?? 0,
                                          );
                                          if (potentialEndDateTime
                                              .isAfter(startDateTime)) {
                                            setState(() {
                                              endDate = pickedDate;
                                              endTime = pickedTime;
                                            });
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'End time must be after start time.'),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              maxLength: 20,
                              cursorColor:
                                  Theme.of(context).colorScheme.primary,
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
                                onPressed: _isButtonEnabled
                                    ? _validateAndSubmit
                                    : null,
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

  const TourDataStream(
      {super.key,
      required this.companyId,
      required this.boatId,
      required this.selectedDate,
      required this.firestoreDatabase});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: firestoreDatabase.getSumOfPriceStream(
          companyId,
          boatId,
          DateTime(
              selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0),
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23,
              59, 59)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Text(''));
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return Center(child: Text(''));
        } else {
          final totalPrice = snapshot.data!['totalPrice'];
          final totalProvision = snapshot.data!['totalProvision'];
          return Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Column(
                  children: [
                    Text(
                        'TOTAL: ${totalPrice.toStringAsFixed(0)}€ | PROVISION: ${totalProvision.toStringAsFixed(0)}€',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<TourModel>>(
                  stream: firestoreDatabase.getToursStream(
                      companyId,
                      boatId,
                      DateTime(selectedDate.year, selectedDate.month,
                          selectedDate.day, 0, 0, 0),
                      DateTime(selectedDate.year, selectedDate.month,
                          selectedDate.day, 23, 59, 59)),
                  builder: (context, tourSnapshot) {
                    if (tourSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(child: Text(''));
                    } else if (tourSnapshot.hasError) {
                      return Center(
                          child: Text('Error: ${tourSnapshot.error}'));
                    } else if (!tourSnapshot.hasData ||
                        tourSnapshot.data!.isEmpty) {
                      return Center(child: Text(''));
                    } else {
                      return ListView.builder(
                        itemCount: tourSnapshot.data!.length,
                        itemBuilder: (context, index) {
                          final tour = tourSnapshot.data![index];
                          return Column(
                            children: [
                              TourCard(
                                  tour: tour,
                                  firestoreDatabase: firestoreDatabase,
                                  companyId: companyId,
                                  boatId: boatId),
                              if (index == tourSnapshot.data!.length - 1)
                                const SizedBox(height: 100),
                            ],
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
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

  const TourCard(
      {super.key,
      required this.tour,
      required this.firestoreDatabase,
      required this.companyId,
      required this.boatId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          openTourPopup(context, tour, firestoreDatabase, companyId, boatId),
      child: Card(
        color: Theme.of(context).colorScheme.onPrimary,
        margin:
            EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 0.0),
        child: Container(
          decoration: BoxDecoration(
            image: tour.typeImage != 0
                ? DecorationImage(
                    image: AssetImage('assets/${tour.typeImage}.png'),
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomRight,
                  )
                : null,
          ),
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
                        child: tour.arrived > 0
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 0, horizontal: 8.0),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                child: Center(
                                  child: Text(
                                    '${tour.arrived} / ${tour.filled}',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                '${tour.filled} / ${tour.capacity}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                      ),
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
                          child: Text(
                              tour.note.isNotEmpty
                                  ? '${tour.tourType.toUpperCase()}   -   ${tour.note}'
                                  : tour.tourType.toUpperCase(),
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

  const TourPopup({
    super.key,
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
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: CircleBorder(),
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () => openTourDeletePopup(context, widget.tour,
                    widget.companyId, widget.boatId, widget.firestoreDatabase),
                child: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.error),
              ),
              Container(
                width: MediaQuery.of(context).size.width * 0.4,
                margin: EdgeInsets.only(top: 15.0),
                child: Column(
                  children: [
                    Text(
                      widget.tour.tourName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                        widget.tour.startTime.toDate().day ==
                                    widget.tour.endTime.toDate().day &&
                                widget.tour.startTime.toDate().month ==
                                    widget.tour.endTime.toDate().month &&
                                widget.tour.startTime.toDate().year ==
                                    widget.tour.endTime.toDate().year
                            ? '${widget.tour.startTime.toDate().hour}:${widget.tour.startTime.toDate().minute.toString().padLeft(2, '0')} - ${widget.tour.endTime.toDate().hour}:${widget.tour.endTime.toDate().minute.toString().padLeft(2, '0')}'
                            : '${widget.tour.startTime.toDate().day}.${widget.tour.startTime.toDate().month}. - ${widget.tour.endTime.toDate().day}.${widget.tour.endTime.toDate().month}.',
                        style: TextStyle(
                            fontSize: 20,
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: CircleBorder(),
                  fixedSize: Size(10, 10),
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () => openTourEditPopup(context, widget.companyId,
                    widget.boatId, widget.tour, widget.firestoreDatabase),
                child: Icon(Icons.edit,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          SingleChildScrollView(
            child: GroupDataStream(
              companyId: widget.companyId,
              boatId: widget.boatId,
              tour: widget.tour,
              firestoreDatabase: widget.firestoreDatabase,
            ),
          ),
        ],
      ),
    );
  }
}

void openTourEditPopup(BuildContext context, String companyId, String boatId,
    TourModel tour, FirestoreDatabase firestoreDatabase) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: TourEditPopup(
            tour: tour,
            companyId: companyId,
            boatId: boatId,
            firestoreDatabase: firestoreDatabase,
          ),
        ),
      );
    },
  );
}

class TourEditPopup extends StatefulWidget {
  final TourModel tour;
  final String companyId;
  final String boatId;
  final FirestoreDatabase firestoreDatabase;

  const TourEditPopup({
    super.key,
    required this.tour,
    required this.companyId,
    required this.boatId,
    required this.firestoreDatabase,
  });

  @override
  _TourEditPopupState createState() => _TourEditPopupState();
}

class _TourEditPopupState extends State<TourEditPopup> {
  late TextEditingController _tourNameController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _capacityController;
  late TextEditingController _noteController;
  late DateTime startDate;
  late DateTime endDate;
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    _tourNameController = TextEditingController(text: widget.tour.tourName);
    _startTimeController =
        TextEditingController(text: widget.tour.startTime.toDate().toString());
    _endTimeController =
        TextEditingController(text: widget.tour.endTime.toDate().toString());
    _capacityController =
        TextEditingController(text: widget.tour.capacity.toString());
    _noteController = TextEditingController(text: widget.tour.note);

    // Initialize date and time values from the tour
    startDate = widget.tour.startTime.toDate();
    endDate = widget.tour.endTime.toDate();
    startTime = TimeOfDay.fromDateTime(startDate);
    endTime = TimeOfDay.fromDateTime(endDate);

    // Add listeners for button state
    _tourNameController.addListener(_updateButtonState);
    _startTimeController.addListener(_updateButtonState);
    _endTimeController.addListener(_updateButtonState);
    _capacityController.addListener(_updateButtonState);
    _noteController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _tourNameController.text.isNotEmpty &&
          _startTimeController.text.isNotEmpty &&
          _endTimeController.text.isNotEmpty &&
          _capacityController.text.isNotEmpty;
    });
  }

  void saveTour() {
    if (_isButtonEnabled) {
      final updatedTour = TourModel(
        id: widget.tour.id,
        tourName: _tourNameController.text,
        startTime: Timestamp.fromDate(DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          startTime.hour,
          startTime.minute,
        )),
        endTime: Timestamp.fromDate(DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          endTime.hour,
          endTime.minute,
        )),
        capacity: int.parse(_capacityController.text),
        filled: widget.tour.filled,
        tourType: widget.tour.tourType,
        typeImage: widget.tour.typeImage,
        note: _noteController.text,
      );
      widget.firestoreDatabase.updateTour(
          widget.companyId, widget.boatId, widget.tour.id, updatedTour);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields before updating the tour'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _tourNameController,
                    decoration: InputDecoration(labelText: 'Tour Name'),
                    cursorColor: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _capacityController,
                    decoration: InputDecoration(labelText: 'Capacity'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    cursorColor: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: 20),
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
                              '${startDate.day}.${startDate.month}.${startDate.year} at ${startTime.format(context)}'),
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
                                initialTime: startTime,
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  startDate = pickedDate;
                                  startTime = pickedTime;
                                  // Update controller for consistency
                                  _startTimeController.text = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  ).toString();
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
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
                              '${endDate.day}.${endDate.month}.${endDate.year} at ${endTime.format(context)}'),
                          trailing: Icon(Icons.keyboard_arrow_right),
                          onTap: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate:
                                  startDate, // Ensure end date is after start date
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (pickedTime != null) {
                                DateTime potentialEndDateTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                                DateTime startDateTime = DateTime(
                                  startDate.year,
                                  startDate.month,
                                  startDate.day,
                                  startTime.hour,
                                  startTime.minute,
                                );
                                if (potentialEndDateTime
                                    .isAfter(startDateTime)) {
                                  setState(() {
                                    endDate = pickedDate;
                                    endTime = pickedTime;
                                    // Update controller for consistency
                                    _endTimeController.text = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    ).toString();
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'End time must be after start time.'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(labelText: 'Note'),
                    maxLength: 20,
                    cursorColor: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(left: 10, right: 10, top: 10),
              color: Colors.white, // Set background to white
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cancel action
                    },
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                  ElevatedButton(
                    onPressed: _isButtonEnabled
                        ? () {
                            saveTour();
                            Navigator.of(context)
                                .pop(); // Push navigator after saving
                          }
                        : null,
                    child: Text('UPDATE TOUR',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void openTourDeletePopup(BuildContext context, TourModel tour, String companyId,
    String boatId, FirestoreDatabase firestoreDatabase) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: TourDeletePopup(
          tour: tour,
          companyId: companyId,
          boatId: boatId,
          firestoreDatabase: firestoreDatabase,
        ),
      );
    },
  );
}

class TourDeletePopup extends StatefulWidget {
  final TourModel tour;
  final String companyId;
  final String boatId;
  final FirestoreDatabase firestoreDatabase;

  const TourDeletePopup(
      {super.key,
      required this.tour,
      required this.companyId,
      required this.boatId,
      required this.firestoreDatabase});

  @override
  _TourDeletePopupState createState() => _TourDeletePopupState();
}

class _TourDeletePopupState extends State<TourDeletePopup> {
  final TextEditingController _tourNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(
                minHeight: 75.0, // Set the minimal height here
              ),
              child: Text(
                'For deleting the tour, please write the tour name:\n${widget.tour.tourName.toUpperCase()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: 10.0),
              child: TextField(
                controller: _tourNameController,
                decoration: InputDecoration(labelText: 'Write the tour name'),
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_tourNameController.text.toUpperCase() ==
                          widget.tour.tourName.toUpperCase()) {
                        widget.firestoreDatabase.deleteTour(
                            widget.companyId, widget.boatId, widget.tour.id);
                        Navigator.of(context).pop<Object?>();
                        Navigator.of(context).pop<Object?>();
                      } else {
                        // Optionally, show an error message or feedback to the user
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Tour name does not match. Please enter the correct name in uppercase.')),
                        );
                      }
                    },
                    child: Text(
                      'Delete',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupDataStream extends StatelessWidget {
  final String companyId;
  final String boatId;
  final TourModel tour;
  final FirestoreDatabase firestoreDatabase;

  const GroupDataStream({
    super.key,
    required this.companyId,
    required this.boatId,
    required this.tour,
    required this.firestoreDatabase,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupModel>>(
      stream: firestoreDatabase.getGroups(companyId, boatId, tour.id),
      builder: (context, snapshot) {
        print(snapshot.data);
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
          height: MediaQuery.of(context).size.height * 0.6 - 94,
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
                    tour: tour,
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
  final TourModel tour;
  final FirestoreDatabase firestoreDatabase;

  const GroupCard({
    super.key,
    required this.group,
    required this.companyId,
    required this.boatId,
    required this.tour,
    required this.firestoreDatabase,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        group.hasArrived ? Theme.of(context).colorScheme.primary : Colors.white;
    final textColor = group.hasArrived
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => openGroupPopup(
          context, group, companyId, boatId, tour, firestoreDatabase),
      child: Card(
        color: cardColor,
        margin:
            EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 20.0),
        child: Padding(
          padding: const EdgeInsets.only(
              left: 15.0, right: 15.0, top: 25.0, bottom: 25.0),
          child: Column(
            children: [
              Text(group.groupName.toUpperCase(),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              Text(
                  '${group.paymentStatus.toUpperCase()}: ${group.price.round()}€',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              Text('Arrived: ${group.hasArrived ? 'Yes' : 'No'}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
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
          height: MediaQuery.of(context).size.height * 0.7,
          child: GroupAddPopup(
            tourId: tourId,
            tour: tour,
            companyId: companyId,
            boatId: boatId,
            firestoreDatabase: firestoreDatabase,
          ),
        ),
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

  const GroupAddPopup({
    super.key,
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
      TextEditingController(text: 'Paid');
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController();
  final TextEditingController _countryDialogCodeController =
      TextEditingController();
  bool _isButtonEnabled = false;
  bool _isPriceManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _groupNameController.addListener(_updateButtonState);
    _adultCountController.addListener(() {
      _updateButtonState();
      _isPriceManuallyEdited = false;
    });
    _childCountController.addListener(() {
      _updateButtonState();
      _isPriceManuallyEdited = false;
    });
    _priceController.addListener(_updateButtonState);
    _mobileNumberController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _groupNameController.text.isNotEmpty &&
          _adultCountController.text.isNotEmpty &&
          _childCountController.text.isNotEmpty &&
          _priceController.text.isNotEmpty &&
          _mobileNumberController.text.isNotEmpty;
    });
  }

  void _validateAndSubmit() async {
    if (_isButtonEnabled) {
      // Ensure default values if controllers are empty
      if (_countryCodeController.text.isEmpty) {
        _countryCodeController.text = 'US';
      }
      if (_countryDialogCodeController.text.isEmpty) {
        _countryDialogCodeController.text = '+1';
      }

      final group = GroupModel(
        groupName: _groupNameController.text,
        adultCount: int.tryParse(_adultCountController.text) ?? 0,
        childCount: int.tryParse(_childCountController.text) ?? 0,
        price: double.tryParse(_priceController.text) ?? 0.0,
        paymentStatus: _paymentStatusController.text,
        bookerId: '',
        mobileNumber: _mobileNumberController.text,
        countryCode: _countryCodeController.text,
        countryDialogCode: _countryDialogCodeController.text,
      );
      if (widget.tour.filled + group.adultCount <= widget.tour.capacity) {
        try {
          // Add the group to the database
          GroupModel createdGroup = (await widget.firestoreDatabase.createGroup(
            widget.companyId,
            widget.boatId,
            widget.tour.id,
            group,
          ));

          if (!context.mounted) return;
          // Close the add group dialog
          Navigator.of(context).pop();
          // Close the tour dialog
          Navigator.of(context).pop();
          // Navigate to QR image screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QRImage(
                createdGroup,
                widget.companyId,
                widget.boatId,
                widget.tour,
              ),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create group'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group capacity exceeds tour capacity'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields before adding a group'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _groupNameController,
                    cursorColor: Theme.of(context).colorScheme.primary,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                    ),
                    maxLength: 20,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _adultCountController,
                    cursorColor: Theme.of(context).colorScheme.primary,
                    decoration: InputDecoration(
                      labelText: 'Adult Count',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 2,
                  ),
                  TextField(
                    controller: _childCountController,
                    cursorColor: Theme.of(context).colorScheme.primary,
                    decoration: InputDecoration(
                      labelText: 'Child Count',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 2,
                  ),
                  SizedBox(height: 10),
                  FutureBuilder(
                    future: widget.firestoreDatabase.getTypeInfo(
                        widget.companyId, widget.boatId, widget.tour.tourType),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final typeInfo = snapshot.data as TypeModel;
                        final pricePerAdult = typeInfo.pricePerAdult;
                        final pricePerChild = typeInfo.pricePerChild;

                        void updatePrice() {
                          if (!_isPriceManuallyEdited) {
                            final adultCount =
                                int.tryParse(_adultCountController.text) ?? 0;
                            final childCount =
                                int.tryParse(_childCountController.text) ?? 0;
                            final totalPrice = (pricePerAdult * adultCount) +
                                (pricePerChild * childCount);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _priceController.text = totalPrice.toString();
                            });
                          }
                        }

                        _adultCountController.addListener(updatePrice);
                        _childCountController.addListener(updatePrice);

                        updatePrice();

                        return TextField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: 'Price',
                          ),
                          cursorColor: Theme.of(context).colorScheme.primary,
                          keyboardType: TextInputType.number,
                          onTap: () {
                            setState(() {
                              _isPriceManuallyEdited = true;
                            });
                          },
                        );
                      }
                      return Text('');
                    },
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _paymentStatusController.text,
                    items: ['Paid', 'Reserved'].map((String status) {
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
                    decoration: InputDecoration(
                      labelText: 'Payment Status',
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: IntlPhoneField(
                          controller: _mobileNumberController,
                          disableLengthCheck: true,
                          decoration: InputDecoration(
                            labelText: 'Mobile Number',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(),
                            ),
                          ),
                          initialCountryCode: 'US',
                          onCountryChanged: (country) {
                            setState(() {
                              _countryCodeController.text = country.code;
                              _countryDialogCodeController.text =
                                  '+${country.dialCode}';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 50),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(left: 10, right: 10, top: 10),
              color: Colors.white, // Set background to white
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cancel action
                    },
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                  ElevatedButton(
                    onPressed: _isButtonEnabled ? _validateAndSubmit : null,
                    child: Text('Add Group',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void openGroupEditPopup(
    BuildContext context,
    GroupModel group,
    String companyId,
    String boatId,
    String tourId,
    TourModel tour,
    FirestoreDatabase firestoreDatabase) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: GroupEditPopup(
            group: group,
            companyId: companyId,
            boatId: boatId,
            tourId: tourId,
            tour: tour,
            firestoreDatabase: firestoreDatabase,
          ),
        ),
      );
    },
  );
}

class GroupEditPopup extends StatefulWidget {
  final GroupModel group;
  final String companyId;
  final String boatId;
  final String tourId;
  final TourModel tour;
  final FirestoreDatabase firestoreDatabase;

  const GroupEditPopup({
    super.key,
    required this.group,
    required this.companyId,
    required this.boatId,
    required this.tourId,
    required this.tour,
    required this.firestoreDatabase,
  });

  @override
  _GroupEditPopupState createState() => _GroupEditPopupState();
}

class _GroupEditPopupState extends State<GroupEditPopup> {
  late TextEditingController _groupNameController;
  late TextEditingController _adultCountController;
  late TextEditingController _childCountController;
  late TextEditingController _priceController;
  late TextEditingController _paymentStatusController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _countryCodeController;
  late TextEditingController _countryDialogCodeController;
  bool _isButtonEnabled = false;
  bool _isPriceManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController(text: widget.group.groupName);
    _adultCountController =
        TextEditingController(text: widget.group.adultCount.toString());
    _childCountController =
        TextEditingController(text: widget.group.childCount.toString());
    _priceController =
        TextEditingController(text: widget.group.price.toString());
    _paymentStatusController =
        TextEditingController(text: widget.group.paymentStatus);
    _mobileNumberController =
        TextEditingController(text: widget.group.mobileNumber);
    _countryCodeController =
        TextEditingController(text: widget.group.countryCode);
    _countryDialogCodeController =
        TextEditingController(text: widget.group.countryDialogCode);

    _groupNameController.addListener(_updateButtonState);
    _adultCountController.addListener(() {
      _updateButtonState();
      _isPriceManuallyEdited = false;
    });
    _childCountController.addListener(() {
      _updateButtonState();
      _isPriceManuallyEdited = false;
    });
    _priceController.addListener(_updateButtonState);
    _mobileNumberController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _groupNameController.text.isNotEmpty &&
          _adultCountController.text.isNotEmpty &&
          _childCountController.text.isNotEmpty &&
          _priceController.text.isNotEmpty &&
          _mobileNumberController.text.isNotEmpty;
    });
  }

  void saveGroup() {
    if (_isButtonEnabled) {
      final adultCount = int.tryParse(_adultCountController.text) ?? 0;
      final childCount = int.tryParse(_childCountController.text) ?? 0;

      if (widget.tour.filled - widget.group.adultCount + adultCount <=
          widget.tour.capacity) {
        final updatedGroup = GroupModel(
          id: widget.group.id,
          groupName: _groupNameController.text,
          adultCount: adultCount,
          childCount: childCount,
          price: double.tryParse(_priceController.text) ?? 0.0,
          paymentStatus: _paymentStatusController.text,
          bookerId: widget.group.bookerId,
          mobileNumber: _mobileNumberController.text,
          countryCode: _countryCodeController.text,
          countryDialogCode: _countryDialogCodeController.text,
          hasArrived: widget.group.hasArrived,
        );
        widget.firestoreDatabase.updateGroup(widget.companyId, widget.boatId,
            widget.tourId, widget.group.id, updatedGroup);
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group capacity exceeds tour capacity'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields before updating the group'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _adultCountController.dispose();
    _childCountController.dispose();
    _priceController.dispose();
    _paymentStatusController.dispose();
    _mobileNumberController.dispose();
    _countryCodeController.dispose();
    _countryDialogCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _groupNameController,
                    cursorColor: Theme.of(context).colorScheme.primary,
                    decoration: InputDecoration(labelText: 'Group Name'),
                    maxLength: 20,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _adultCountController,
                    cursorColor: Theme.of(context).colorScheme.primary,
                    decoration: InputDecoration(labelText: 'Adult Count'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 2,
                  ),
                  TextField(
                    controller: _childCountController,
                    cursorColor: Theme.of(context).colorScheme.primary,
                    decoration: InputDecoration(labelText: 'Child Count'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 2,
                  ),
                  SizedBox(height: 10),
                  FutureBuilder(
                    future: widget.firestoreDatabase.getTypeInfo(
                        widget.companyId, widget.boatId, widget.tour.tourType),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final typeInfo = snapshot.data as TypeModel;
                        final pricePerAdult = typeInfo.pricePerAdult;
                        final pricePerChild = typeInfo.pricePerChild;

                        void updatePrice() {
                          if (!_isPriceManuallyEdited) {
                            final adultCount =
                                int.tryParse(_adultCountController.text) ?? 0;
                            final childCount =
                                int.tryParse(_childCountController.text) ?? 0;
                            final totalPrice = (pricePerAdult * adultCount) +
                                (pricePerChild * childCount);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _priceController.text = totalPrice.toString();
                            });
                          }
                        }

                        _adultCountController.addListener(updatePrice);
                        _childCountController.addListener(updatePrice);

                        updatePrice();

                        return TextField(
                          controller: _priceController,
                          cursorColor: Theme.of(context).colorScheme.primary,
                          decoration: InputDecoration(
                            labelText: 'Price',
                          ),
                          keyboardType: TextInputType.number,
                          onTap: () {
                            setState(() {
                              _isPriceManuallyEdited = true;
                            });
                          },
                        );
                      }
                      return Text('');
                    },
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _paymentStatusController.text.isNotEmpty
                        ? _paymentStatusController.text
                        : null,
                    items:
                        ['Paid', 'Reserved', 'Cancelled'].map((String status) {
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
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: IntlPhoneField(
                          controller: _mobileNumberController,
                          disableLengthCheck: true,
                          decoration: InputDecoration(
                            labelText: 'Mobile Number',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(),
                            ),
                          ),
                          initialCountryCode: widget.group.countryCode,
                          onCountryChanged: (country) {
                            setState(() {
                              _countryCodeController.text = country.code;
                              _countryDialogCodeController.text =
                                  '+${country.dialCode}';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 50),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(left: 10, right: 10, top: 10),
              color: Colors.white, // Set background to white
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cancel action
                    },
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                  ElevatedButton(
                    onPressed: _isButtonEnabled
                        ? () {
                            saveGroup();
                            Navigator.of(context)
                                .pop(); // Push navigator after saving
                          }
                        : null,
                    child: Text('UPDATE GROUP',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void openGroupPopup(BuildContext context, GroupModel group, String companyId,
    String boatId, TourModel tour, FirestoreDatabase firestoreDatabase) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.3,
          child: GroupPopup(
            group: group,
            companyId: companyId,
            boatId: boatId,
            tour: tour,
            firestoreDatabase: firestoreDatabase,
          ),
        ),
      );
    },
  );
}

class GroupPopup extends StatelessWidget {
  final GroupModel group;
  final String companyId;
  final String boatId;
  final TourModel tour;
  final FirestoreDatabase firestoreDatabase;
  const GroupPopup({
    super.key,
    required this.group,
    required this.companyId,
    required this.boatId,
    required this.tour,
    required this.firestoreDatabase,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              children: [
                if (!group.hasArrived) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: CircleBorder(),
                        ),
                        onPressed: () {
                          openGroupDeletePopup(context, group, companyId,
                              boatId, tour.id, firestoreDatabase);
                        },
                        child: Icon(Icons.delete,
                            color: Theme.of(context).colorScheme.error),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: CircleBorder(),
                        ),
                        onPressed: () {
                          openGroupEditPopup(context, group, companyId, boatId,
                              tour.id, tour, firestoreDatabase);
                        },
                        child: Icon(Icons.edit,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(height: 20),
                ],
                Text(group.groupName.toUpperCase(),
                    style: TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${group.paymentStatus.toUpperCase()}:',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${group.price.round()}€',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${group.adultCount} ${group.adultCount == 1 ? 'ADULT' : 'ADULTS'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          group.childCount > 0
                              ? '${group.childCount} ${group.childCount == 1 ? 'CHILD' : 'CHILDREN'}'
                              : '',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(group.hasArrived ? 'HAS ARRIVED' : 'HAS NOT ARRIVED',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: EdgeInsets.only(left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CallButton(
                    phoneNumber:
                        '${group.countryDialogCode}${group.mobileNumber}',
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    color: Theme.of(context).colorScheme.secondary,
                    icon: Icon(Icons.qr_code),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QRImage(
                            group,
                            companyId,
                            boatId,
                            tour,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 10),
                  MessageButton(
                    phoneNumber:
                        '${group.countryDialogCode}${group.mobileNumber}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void openGroupDeletePopup(
    BuildContext context,
    GroupModel group,
    String companyId,
    String boatId,
    String tourId,
    FirestoreDatabase firestoreDatabase) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Delete Group'),
        content: Text(
            'Are you sure you want to delete the group "${group.groupName}"?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text('No'),
          ),
          TextButton(
            onPressed: () {
              // Call the delete group function here
              deleteGroup(
                  group.id, companyId, boatId, tourId, firestoreDatabase);
              Navigator.of(context).pop(); // Close the current dialog
              Navigator.of(context).pop(); // Close the previous dialog
            },
            child: Text(
              'Yes',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      );
    },
  );
}

void deleteGroup(String groupId, String companyId, String boatId, String tourId,
    FirestoreDatabase firestoreDatabase) {
  firestoreDatabase.deleteGroup(companyId, boatId, tourId, groupId);
}

class CallButton extends StatelessWidget {
  final String phoneNumber;

  const CallButton({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        shape: CircleBorder(),
        padding: EdgeInsets.all(10),
      ),
      onPressed: () {
        launchUrl(Uri.parse('tel:$phoneNumber'));
      },
      child: Icon(Icons.call, color: Theme.of(context).colorScheme.onPrimary),
    );
  }
}

class MessageButton extends StatelessWidget {
  final String phoneNumber;

  const MessageButton({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        shape: CircleBorder(),
        padding: EdgeInsets.all(10),
      ),
      onPressed: () {
        launchUrl(Uri.parse('sms:$phoneNumber'));
      },
      child:
          Icon(Icons.message, color: Theme.of(context).colorScheme.onPrimary),
    );
  }
}
