import 'package:booksea_app/auth_widget_builder.dart';
import 'package:booksea_app/constants/app_themes.dart';
import 'package:booksea_app/flavour.dart';
import 'package:booksea_app/models/tour_model.dart';
import 'package:booksea_app/models/type_model.dart';
import 'package:booksea_app/models/user_model.dart';
import 'package:booksea_app/providers/auth_provider.dart';
import 'package:booksea_app/routes.dart';
import 'package:booksea_app/services/firestore_database.dart';
import 'package:booksea_app/ui/search/search_and_filter.dart';
import 'package:booksea_app/ui/home/home.dart';
import 'package:booksea_app/ui/home/no_code_home.dart';
import 'package:booksea_app/ui/home/something_is_missing_screen.dart';
import 'package:booksea_app/ui/qr/qr_scanner_screen.dart';
import 'package:booksea_app/ui/settings/settings_screen.dart';
import 'package:booksea_app/ui/splash/splash_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:booksea_app/providers/theme_provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({required Key key, required this.databaseBuilder})
      : super(key: key);

  // Expose builders for 3rd party services at the root of the widget tree
  // This is useful when mocking services while testing
  final FirestoreDatabase Function(BuildContext context, String uid)
      databaseBuilder;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 1;
  String? boatId; // Store boatId in app memory, can be null
  late DateTime selectedDate; // Store selected date

  // Update screens to pass and receive boatId
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now(); // Initialize with today's date
    _initializeScreens();
  }

  void _initializeScreens() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Set initial boatId if null
    if (boatId == null && authProvider.boatIds.isNotEmpty) {
      boatId = authProvider.boatIds.first;
    }

    _screens = [
      SearchAndFilterScreen(
        onBoatIdChanged: (String newBoatId) {
          setState(() {
            boatId = newBoatId;
            selectedDate = DateTime.now(); // Reset date when changing screens
          });
        },
        currentBoatId: boatId,
      ),
      HomeScreen(
        onBoatIdChanged: (String newBoatId) {
          setState(() {
            boatId = newBoatId;
            selectedDate = DateTime.now(); // Reset date when changing screens
          });
        },
        currentBoatId: boatId,
        selectedDate: selectedDate,
        onDateChange: _handleDateChange,
      ),
      QRScannerScreen(),
      SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      selectedDate = DateTime.now(); // Reset date when changing screens
      // Update screens to ensure they have the latest boatId
      _initializeScreens();
    });
  }

  void _handleDateChange(DateTime date) {
    setState(() {
      selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (_, themeProviderRef, authProviderRef, __) {
        // Ensure screens have the latest boatId
        _initializeScreens();

        return AuthWidgetBuilder(
          databaseBuilder: widget.databaseBuilder,
          builder:
              (BuildContext context, AsyncSnapshot<UserModel> userSnapshot) {
            return MaterialApp(
              title: Provider.of<Flavor>(context).toString(),
              routes: Routes.routes,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProviderRef.isDarkModeOn
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: Builder(
                builder: (context) {
                  switch (authProviderRef.status) {
                    case Status.Authenticated:
                      // We'll still keep this check as a fallback
                      if (userSnapshot.hasData &&
                          !userSnapshot.data!.hasAccess) {
                        return const SomethingIsMissingScreen();
                      }
                      return Scaffold(
                        body: _screens[_selectedIndex],
                        bottomNavigationBar: BottomAppBar(
                          height: 60,
                          padding: EdgeInsets.zero,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(Icons.search, size: 25),
                                onPressed: () => _onItemTapped(0),
                                color: _selectedIndex == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              IconButton(
                                icon: Icon(Icons.home, size: 25),
                                onPressed: () => _onItemTapped(1),
                                color: _selectedIndex == 1
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.add, size: 25),
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  onPressed: () {
                                    final user = userSnapshot.data;
                                    if (user != null) {
                                      showTourAddModal(
                                        context,
                                        user.companyId,
                                        widget.databaseBuilder(
                                            context, user.uid),
                                        authProviderRef,
                                        selectedDate,
                                        boatId!,
                                      );
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.qr_code, size: 25),
                                onPressed: () => _onItemTapped(2),
                                color: _selectedIndex == 2
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              IconButton(
                                icon: Icon(Icons.settings, size: 25),
                                onPressed: () => _onItemTapped(3),
                                color: _selectedIndex == 3
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    case Status.Unauthenticated:
                      boatId =
                          null; // Reset boatId when user is not authenticated
                      return const SplashScreen();
                    case Status.Uninitialized:
                      return const Material(
                        child: Center(child: Text('')),
                      );
                    case Status.NoCode:
                      return const NoCodeHomeScreen();
                    case Status.NoAccess:
                      return const SomethingIsMissingScreen();
                    default:
                      return const Material(
                        child: Center(child: Text('')),
                      );
                  }
                },
              ),
            );
          },
          key: const Key('AuthWidget'),
        );
      },
    );
  }
}

class TourAddModal extends StatefulWidget {
  final String companyId;
  final FirestoreDatabase firestoreDatabase;
  final AuthProvider authProvider;
  final DateTime selectedDate;
  final String boatId;

  const TourAddModal({
    super.key,
    required this.companyId,
    required this.firestoreDatabase,
    required this.authProvider,
    required this.selectedDate,
    required this.boatId,
  });

  @override
  _TourAddModalState createState() => _TourAddModalState();
}

class _TourAddModalState extends State<TourAddModal> {
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
    // Check if selected date is before today
    final now = DateTime.now();
    if (widget.selectedDate.isBefore(DateTime(now.year, now.month, now.day))) {
      startDate = now;
      endDate = now;
    } else {
      startDate = widget.selectedDate;
      endDate = widget.selectedDate;
    }
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
          // Make sure to update button state after setting these values
          _updateButtonState();
        });
      }
    });
    _tourNameController.addListener(_updateButtonState);
    _capacityController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {
      // The button should be enabled when all required fields are filled
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
                                        firstDate: DateTime.now(),
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
                                        firstDate: startDate,
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

void showTourAddModal(
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
      return TourAddModal(
        companyId: companyId,
        firestoreDatabase: firestoreDatabase,
        authProvider: authProvider,
        selectedDate: selectedDate,
        boatId: boatId,
      );
    },
  );
}
