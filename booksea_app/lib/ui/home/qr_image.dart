import 'package:booksea_app/models/group_model.dart';
import 'package:booksea_app/models/tour_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

class QRImage extends StatelessWidget {
  final GroupModel group;
  final String companyId;
  final String boatId;
  final TourModel tour;
  final ScreenshotController screenshotController = ScreenshotController();

  QRImage(this.group, this.companyId, this.boatId, this.tour, {super.key}) {
    // Print the group, companyId, boatId, tour, and QR data
    print(
        'Group: ${group.groupName}, Company ID: $companyId, Boat ID: $boatId, Tour ID: ${tour.id}');
    print(
        'QR Data: $companyId/${boatId.replaceAll(' ', '_')}/${tour.id}/${group.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.onPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Screenshot(
              controller: screenshotController,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                color: Theme.of(context).colorScheme.onPrimary,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tour.tourName,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    // start Time - end Time
                    Column(
                      children: [
                        Text(
                          group.groupName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${tour.startTime.hour}:${tour.startTime.minute.toString().padLeft(2, '0')} - ${tour.endTime.hour}:${tour.endTime.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          tour.startTime.day ==
                                      tour.endTime.day &&
                                  tour.startTime.month ==
                                      tour.endTime.month &&
                                  tour.startTime.year ==
                                      tour.endTime.year
                              ? '${tour.startTime.day}.${tour.startTime.month}.${tour.startTime.year}'
                              : '${tour.startTime.day}.${tour.startTime.month}.${tour.startTime.year} - ${tour.endTime.day}.${tour.endTime.month}.${tour.endTime.year}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                    QrImageView(
                      data:
                          '$companyId/${boatId.replaceAll(' ', '_')}/${tour.id}/${group.id}',
                      size: 280,
                      embeddedImageStyle: QrEmbeddedImageStyle(
                        size: const Size(
                          100,
                          100,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    icon: Icon(Icons.share),
                    onPressed: () => _shareQRCode(context),
                    tooltip: 'Share QR Code',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareQRCode(BuildContext context) async {
    // Copy phone number to clipboard
    await Clipboard.setData(
        ClipboardData(text: "${group.countryDialogCode}${group.mobileNumber}"));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Phone number copied to clipboard')),
    );

    final image = await screenshotController.capture();
    if (image != null) {
      await Share.shareXFiles([XFile.fromData(image, mimeType: 'image/png')]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture QR code')),
      );
    }
  }
}
