import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safebite/entry/feedpage.dart';
import 'package:safebite/components/rounded_button.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Allergenpicker extends StatefulWidget {
  // const Allergenpicker({super.key});
  static const String id = "allergen_picker";

  @override
  State<Allergenpicker> createState() => _AllergenpickerState();
}

class _AllergenpickerState extends State<Allergenpicker> {
  @override
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, bool> allergens = {
    "Gluten": false,
    "Vegan": false,
    "Vegetarian": false,
    "Peanut": false,
    "Dairy": false,
    "Soy": false,
    "Peanuts": false,
    "Fish": false,
    "None": false,
  };

  Future<String> getDefaultImageUrl() async {
    try {
      String downloadURL = await FirebaseStorage.instance
          .ref('profilepic/default_profile_pic.jpg')
          .getDownloadURL();

      print(downloadURL);
      return downloadURL;
    } catch (e) {
      print("Error retrieving image URL: $e");
      return '';
    }
  }

  Future<void> saveAllergens() async {
    User? user = _auth.currentUser;
    if (user == null) return;
    String defaultImageUrl = await getDefaultImageUrl();

    List<String> selectedAllergens = allergens.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

    if (selectedAllergens.isEmpty) {
      selectedAllergens = ["None"];
    }

    await _firestore.collection('users').doc(user.uid).update({
      'allergens': selectedAllergens,
      'profilePic': defaultImageUrl,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Allergens saved!")),
      );
    }

    print("Saved allergens: $selectedAllergens");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Pick Your Allergens"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 20),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: allergens.keys.map((allergen) {
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(
                        allergen,
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      value: allergens[allergen],
                      onChanged: (bool? value) {
                        setState(() {
                          allergens[allergen] = value!;
                        });
                      },
                      activeColor: Colors.blueAccent,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              RoundedButton(
                title: "Create Account",
                onPressed: () async {
                  await saveAllergens();
                  Navigator.popAndPushNamed(context, FeedPage.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
