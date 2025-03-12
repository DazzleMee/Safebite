import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safebite/components/NavBar.dart';
import 'package:safebite/entry/changecreds.dart';

class ProfilePage extends StatefulWidget {
  static const String id = "profile_page";

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? profilePicUrl;
  String userName = "notfound";
  String userLocation = "notfound";
  String userBio = "notfound";
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final currentEmail = _auth.currentUser!.email;

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: currentEmail)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      DocumentSnapshot userDoc = querySnapshot.docs.first;
      String? fetchedProfilePic = userDoc['profilePic'];

      print("Profile Pic URL: $fetchedProfilePic"); // Debugging output

      setState(() {
        profilePicUrl = fetchedProfilePic ?? '';
        userName = userDoc['username'] ?? 'Unknown User';
        userBio = userDoc['bio'] ?? 'No bio available.';
      });
    } else {
      print("No user found with email: $currentEmail");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavBar(selectedIndex: 3),
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: Text("Profile"),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section
            Container(
              color: Colors.grey[400],
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: profilePicUrl != null &&
                            profilePicUrl!.isNotEmpty
                        ? NetworkImage(profilePicUrl!)
                        : AssetImage('images/userprofile.png') as ImageProvider,
                  ),
                  SizedBox(width: 16),
                  // User Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          userLocation,
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        SizedBox(height: 8),
                        Text(
                          userBio,
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  // Settings Icon
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, ChangeCreds.id);
                    },
                  ),
                ],
              ),
            ),

            // My Reviews Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "My Reviews",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 100, // Empty placeholder for reviews
              color: Colors.white,
              child: Center(
                child: Text("No reviews yet."),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
