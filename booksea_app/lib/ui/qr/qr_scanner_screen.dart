import 'package:booksea_app/models/group_model.dart';
import 'package:booksea_app/services/firestore_database.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class QRScannerScreen extends StatelessWidget {
  QRScannerScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreDatabase =
        Provider.of<FirestoreDatabase>(context, listen: false);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/qr.png'), // Add a background image
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Center(
          child: Container(
            width: 300, // Adjust the size as needed
            height: 300, // Adjust the size as needed
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), // Rounded corners
              color: Colors.white, // Background color
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(15), // Rounded corners for the scanner
              child: MobileScanner(
                controller: MobileScannerController(
                  facing: CameraFacing.back,
                  detectionSpeed:
                      DetectionSpeed.noDuplicates, // Adjust detection speed
                ),
                onDetect: (barcodeCapture) {
                  final String code =
                      barcodeCapture.barcodes.first.rawValue ?? '---';
                  final parts = code.split('/');
                  if (parts.length == 4) {
                    final companyId = parts[0];
                    final boatId = parts[1];
                    final tourId = parts[2];
                    final groupId = parts[3];
                    print(companyId);
                    print(boatId);
                    print(tourId);
                    print(groupId);
                    print(code);

                    firestoreDatabase
                        .getGroup(companyId, boatId, tourId, groupId)
                        .then((group) {
                      openGroupPopup(context, group, companyId, boatId, tourId,
                          firestoreDatabase);
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to fetch group'),
                        ),
                      );
                    });
                  } else {
                    // Handle invalid QR code format
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invalid QR code format'),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void openGroupPopup(BuildContext context, GroupModel group, String companyId,
    String boatId, String tourId, FirestoreDatabase firestoreDatabase) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.3,
          child: GroupPopup(group: group),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('CANCEL',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          SizedBox(width: 10),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              firestoreDatabase.updateGroupHasArrived(
                  companyId, boatId, tourId, true, group);
              Navigator.of(context).pop();
            },
            child: Text('ARRIVED',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      );
    },
  );
}

class GroupPopup extends StatelessWidget {
  final GroupModel group;

  const GroupPopup({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Text(group.groupName.toUpperCase(),
                style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            SizedBox(height: 20),
            Text(
                '${group.paymentStatus.toUpperCase()}: ${group.price.round()}€',
                style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            SizedBox(height: 25),
            Text(
                '${group.adultCount} ${group.adultCount == 1 ? 'ADULT' : 'ADULTS'}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            Text(
                group.childCount > 0
                    ? '${group.childCount} ${group.childCount == 1 ? 'CHILD' : 'CHILDREN'}'
                    : '',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
