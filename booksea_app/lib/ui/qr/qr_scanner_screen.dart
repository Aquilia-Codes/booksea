import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
              onDetect: (barcodeCapture) {
                final String code =
                    barcodeCapture.barcodes.first.rawValue ?? '---';
                print('QR Code found: $code');
                // You can handle the scanned code here
              },
            ),
          ),
        ),
      ),
    );
  }
}

class GroupCard extends StatelessWidget {
  final String groupId;

  const GroupCard({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(groupId),
        subtitle: Text(groupId),
      ),
    );
  }
}
