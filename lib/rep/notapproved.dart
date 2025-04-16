import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RepWaitingApproval extends StatelessWidget {
  static const String id = "not_approved";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Waiting for Approval'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.hourglass_empty,
                size: 80,
                color: Colors.grey,
              ),
              SizedBox(height: 20),
              Text(
                'Your profile is currently pending admin approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                'An email will be sent to your email once you have been approved',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 20),
              if (user != null) // Only show email if user is logged in
                Text(
                  'Email: ${user.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
