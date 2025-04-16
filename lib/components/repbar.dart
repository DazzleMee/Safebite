import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safebite/entry/barcode.dart';
import 'package:safebite/entry/profilescreen.dart';
import 'package:safebite/entry/feedpage.dart';
import 'package:safebite/entry/maps.dart';
import 'package:safebite/entry/welcome.dart';
import 'package:safebite/entry/changecreds.dart';
import 'package:safebite/entry/profilescreen.dart';
import 'package:safebite/rep/notifications.dart';
import 'package:safebite/rep/repfeedpage.dart';
import 'package:safebite/rep/repprofile.dart';
import 'package:safebite/rep/repsearchaccounts.dart';

class Repbar extends StatefulWidget {
  int selectedIndex = 0;
  final User? user;

  Repbar({required this.selectedIndex, this.user});

  @override
  _RepBarState createState() => _RepBarState();
}

class _RepBarState extends State<Repbar> {
  int _currentIndex = 0;
  final _auth = FirebaseAuth.instance;

  User? _currentUser;
  @override
  void initState() {
    _currentUser = FirebaseAuth.instance.currentUser;
    super.initState();
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: GNav(
          selectedIndex: widget.selectedIndex,
          onTabChange: onTabTapped,
          backgroundColor: Colors.black,
          activeColor: Colors.white,
          color: Colors.white,
          rippleColor: Colors.grey,
          haptic: true,
          tabBackgroundColor: Colors.grey.shade800,
          padding: EdgeInsets.all(16),
          curve: Curves.easeInCirc,
          gap: 5,
          tabs: [
            GButton(
              icon: (Icons.home),
              text: "Home",
              onPressed: () {
                Navigator.popAndPushNamed(context, RepFeedPage.id);
              },
            ),
            GButton(
              icon: Icons.notifications,
              text: "Notifications",
              onPressed: () {
                Navigator.popAndPushNamed(context, NotificationsPage.id);
              },
            ),
            GButton(
              icon: Icons.search,
              text: "Search",
              onPressed: () {
                Navigator.popAndPushNamed(context, RepSearchPage.id);
              },
            ),
            GButton(
              icon: Icons.person,
              text: "Profile",
              onPressed: () {
                Navigator.popAndPushNamed(context, RepProfileScreen.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
