import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:safebite/components/NavBar.dart';

class ChangeCreds extends StatefulWidget {
  static const String id = "profile_screen";

  @override
  _ChangeCredsState createState() => _ChangeCredsState();
}

class _ChangeCredsState extends State<ChangeCreds> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _prfimg;
  String? _imglink;
  bool _editname = false;
  bool _editbio = false;
  bool _initialized = false;
  List<String> _allAllergens = [
    "Gluten",
    "Vegan",
    "Vegetarian",
    "Peanut",
    "Dairy",
    "Soy",
    "Peanuts",
    "Fish",
    "None"
  ];
  List<String> _selectedAllergens = [];

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _selImg() async {
    final chosenf = await _picker.pickImage(source: ImageSource.gallery);
    if (chosenf != null) {
      setState(() {
        _prfimg = File(chosenf.path);
      });
      await _ulImg();
    }
  }

  Future<void> _ulImg() async {
    try {
      if (_prfimg == null) return;
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final storageRef =
          _storage.ref().child('profilepic').child('${currentUser.uid}.jpg');
      await storageRef.putFile(_prfimg!);
      final imageUrl = await storageRef.getDownloadURL();

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({'profilePic': imageUrl});

      setState(() {
        _imglink = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profile picture updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload profile picture: $e")),
      );
    }
  }

  Future<void> _updateAllergens() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({'allergens': _selectedAllergens});

      // Delay a tiny bit to ensure context is mounted
      if (mounted) {
        Future.delayed(Duration(milliseconds: 100), () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Allergens updated!")),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update allergens: $e")),
        );
      }
    }
  }

  Future<void> _updateNickname(String newNickname) async {
    if (newNickname.isEmpty) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({'username': newNickname});

      setState(() {
        _editname = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nickname updated!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }
  }

  Future<void> _updateBio(String newBio) async {
    if (newBio.isEmpty) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({'bio': newBio});

      setState(() {
        _editbio = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bio updated!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: null,
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: Colors.white),
            ),
          ],
          title: Text('Change Credentials',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(currentUser?.uid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Text(
                  'Profile not found.',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            if (!_initialized) {
              _selectedAllergens =
                  List<String>.from(userData['allergens'] ?? []);
              _initialized = true;
            }
            final email = currentUser?.email ?? 'No email';
            final nickname = userData['username'] ?? email;
            final bio = userData['bio'] ?? "No bio added";
            _imglink = userData['profilePic'];

            if (!_editname) {
              _nicknameController.text = nickname;
            }
            if (!_editbio) {
              _bioController.text = bio;
            }

            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _imglink != null
                            ? NetworkImage(_imglink!)
                            : (_prfimg != null
                                    ? FileImage(_prfimg!)
                                    : AssetImage(
                                        'components/defaultprofilepic.jpg'))
                                as ImageProvider,
                        child: (_prfimg == null && _imglink == null)
                            ? Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _selImg,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[800],
                            child: Icon(Icons.camera_alt, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildLabel('Email'),
                  _buildValue(email, isEmail: true),
                  _buildLabel('Username'),
                  _editname
                      ? _buildEditableTextField(
                          controller: _nicknameController,
                          onSave: () =>
                              _updateNickname(_nicknameController.text.trim()))
                      : _buildValue(nickname,
                          isEditable: true,
                          onEdit: () => setState(() => _editname = true)),
                  _buildLabel('Your Allergens'),
                  Wrap(
                    spacing: 8.0,
                    children: _allAllergens.map((allergen) {
                      final isSelected = _selectedAllergens.contains(allergen);
                      return FilterChip(
                        label: Text(allergen),
                        selected: isSelected,
                        selectedColor: Colors.red[300],
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAllergens.add(allergen);
                            } else {
                              _selectedAllergens.remove(allergen);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text("Save Allergens"),
                    onPressed: _updateAllergens,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildValue(
    String text, {
    bool isEditable = false,
    VoidCallback? onEdit,
    bool isEmail = false, // Add this flag to identify if it's an email
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment:
            isEmail ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                text,
                textAlign: isEmail ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          if (isEditable) ...[
            SizedBox(width: 8.0),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableTextField({
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 8.0, horizontal: 8.0), // Added padding
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 12.0), // Added inner padding
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.0), // Space between text field and button
          IconButton(
            icon: Icon(Icons.check, color: Colors.green),
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
