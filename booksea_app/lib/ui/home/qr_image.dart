import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class QRImage extends StatelessWidget {
  final String groupId;
  final String phoneNumber;
  const QRImage(this.groupId, this.phoneNumber, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: groupId,
              size: 280,
              embeddedImageStyle: QrEmbeddedImageStyle(
                size: const Size(
                  100,
                  100,
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

  Future<void> _sendToWhatsApp(BuildContext context) async {
    final qrCodeUrl =
        'https://api.qrserver.com/v1/create-qr-code/?data=$groupId&size=280x280';
    final message = Uri.encodeComponent('Check out this QR code: $qrCodeUrl');
    final whatsappUrl =
        Uri.parse('whatsapp://send?phone=$phoneNumber&text=$message');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else {
        _showError(context, 'WhatsApp is not installed');
      }
    } catch (e) {
      _showError(context, 'Could not launch WhatsApp');
    }
  }

  Future<void> _sendToTelegram(BuildContext context) async {
    final qrCodeUrl =
        'https://api.qrserver.com/v1/create-qr-code/?data=$groupId&size=280x280';
    final message = Uri.encodeComponent('Check out this QR code: $qrCodeUrl');
    final telegramUrl = Uri.parse('tg://msg?to=$phoneNumber&text=$message');

    try {
      if (await canLaunchUrl(telegramUrl)) {
        await launchUrl(telegramUrl);
      } else {
        _showError(context, 'Telegram is not installed');
      }
    } catch (e) {
      _showError(context, 'Could not launch Telegram');
    }
  }

  Future<void> _sendToViber(BuildContext context) async {
    final qrCodeUrl =
        'https://api.qrserver.com/v1/create-qr-code/?data=$groupId&size=280x280';
    final message = Uri.encodeComponent('Check out this QR code: $qrCodeUrl');
    final viberUrl = Uri.parse('viber://forward?text=$message');

    try {
      if (await canLaunchUrl(viberUrl)) {
        await launchUrl(viberUrl);
      } else {
        _showError(context, 'Viber is not installed');
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
