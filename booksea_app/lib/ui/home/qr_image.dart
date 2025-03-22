import 'package:booksea_app/models/group_model.dart';
import 'package:booksea_app/models/tour_model.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screenshot/screenshot.dart';

class QRImage extends StatelessWidget {
  final GroupModel group;
  final String companyId;
  final String boatId;
  final TourModel tour;
  final ScreenshotController screenshotController = ScreenshotController();

  QRImage(this.group, this.companyId, this.boatId, this.tour, {super.key});

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
                          '${tour.startTime.toDate().hour}:${tour.startTime.toDate().minute.toString().padLeft(2, '0')} - ${tour.endTime.toDate().hour}:${tour.endTime.toDate().minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          tour.startTime.toDate().day ==
                                      tour.endTime.toDate().day &&
                                  tour.startTime.toDate().month ==
                                      tour.endTime.toDate().month &&
                                  tour.startTime.toDate().year ==
                                      tour.endTime.toDate().year
                              ? '${tour.startTime.toDate().day}.${tour.startTime.toDate().month}.${tour.startTime.toDate().year}'
                              : '${tour.startTime.toDate().day}.${tour.startTime.toDate().month}.${tour.startTime.toDate().year} - ${tour.endTime.toDate().day}.${tour.endTime.toDate().month}.${tour.endTime.toDate().year}',
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
                IconButton(
                  icon:
                      Image.asset('assets/whatsapp.png', width: 50, height: 50),
                  onPressed: () => _sendToWhatsApp(context),
                  tooltip: 'Send via WhatsApp',
                ),
                IconButton(
                  icon:
                      Image.asset('assets/telegram.png', width: 50, height: 50),
                  onPressed: () => _sendToTelegram(context),
                  tooltip: 'Send via Telegram',
                ),
                IconButton(
                  icon: Image.asset('assets/viber.png', width: 50, height: 50),
                  onPressed: () => _sendToViber(context),
                  tooltip: 'Send via Viber',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // Add this import for sharing functionality

  Future<void> _sendToWhatsApp(BuildContext context) async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        final whatsappUrl = Uri.parse(
            'whatsapp://send?phone=${group.countryDialogCode}${group.mobileNumber}');
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
          // Use Share package to send the image
          await Share.shareXFiles(
              [XFile.fromData(image, mimeType: 'image/png')],
              text: 'Here is the QR code');
        } else {
          _showError(context, 'WhatsApp is not installed');
        }
      }
    } catch (e) {
      _showError(context, 'Could not launch WhatsApp');
    }
  }

  Future<void> _sendToTelegram(BuildContext context) async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        final telegramUrl = Uri.parse(
            'tg://msg?to=${group.countryDialogCode}${group.mobileNumber}');
        if (await canLaunchUrl(telegramUrl)) {
          await launchUrl(telegramUrl);
          // Use Share package to send the image
          await Share.shareXFiles(
              [XFile.fromData(image, mimeType: 'image/png')],
              text: 'Here is the QR code');
        } else {
          _showError(context, 'Telegram is not installed');
        }
      }
    } catch (e) {
      _showError(context, 'Could not launch Telegram');
    }
  }

  Future<void> _sendToViber(BuildContext context) async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        final viberUrl = Uri.parse('viber://forward');
        if (await canLaunchUrl(viberUrl)) {
          await launchUrl(viberUrl);
          // Use Share package to send the image
          await Share.shareXFiles(
              [XFile.fromData(image, mimeType: 'image/png')],
              text: 'Here is the QR code');
        } else {
          _showError(context, 'Viber is not installed');
        }
      }
    } catch (e) {
      _showError(context, 'Could not launch Viber');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
