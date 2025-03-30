import 'package:booksea_app/models/user_model.dart';
import 'package:flutter/material.dart';

class BusinessCard extends StatelessWidget {
  final UserModel user;

  const BusinessCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/business_card.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Text(user.nickname,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(user.boatIds.toString(), style: TextStyle(fontSize: 20)),
          Text(user.email, style: TextStyle(fontSize: 20)),
          Text(user.phoneNumber!, style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}
