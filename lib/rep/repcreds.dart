import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:safebite/rep/repfeedpage.dart';
import 'package:safebite/rep/notapproved.dart';

class ProfileUpdateScreen extends StatefulWidget {
  @override
  static const String id = "rep_creds";
  _ProfileUpdateScreenState createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountDescController = TextEditingController();
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isApproved = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _loadUserData() async {
    String email = _auth.currentUser?.email ?? "";
    if (email.isEmpty) return;

    QuerySnapshot querySnapshot = await _firestore
        .collection("rep")
        .where("email", isEqualTo: email)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      DocumentSnapshot userDoc = querySnapshot.docs.first;
      setState(() {
        _accountNameController.text = userDoc["accountName"] ?? "";
        _accountDescController.text = userDoc["accountDesc"] ?? "";
        _uploadedImageUrl = userDoc["profilePic"] ?? "";
        _isApproved = userDoc["approved"] ?? false;
      });
    } else {
      print("No user found with email: $email");
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      // Convert and compress the image to WebP
      final compressedWebP = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        format: CompressFormat.webp,
        quality: 80,
      );

      if (compressedWebP == null) {
        print("Image compression failed.");
        return null;
      }

      // Use .webp extension in Firebase Storage
      String fileName = 'profile_pics/${_auth.currentUser!.email}.webp';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      // Upload compressed WebP image bytes
      UploadTask uploadTask = storageRef.putData(
        compressedWebP,
        SettableMetadata(contentType: 'image/webp'),
      );

      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  Future<void> _updateUserProfile() async {
    String email = _auth.currentUser?.email ?? "";
    if (email.isEmpty) return;

    String accountName = _accountNameController.text;
    String accountDesc = _accountDescController.text;

    QuerySnapshot querySnapshot = await _firestore
        .collection("rep")
        .where("email", isEqualTo: email)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      String docId = querySnapshot.docs.first.id;

      if (_selectedImage != null) {
        _uploadedImageUrl = await _uploadImageToFirebase(_selectedImage!);
      }

      await _firestore.collection("rep").doc(docId).update({
        "accountName": accountName,
        "accountDesc": accountDesc,
        "profilePic": _uploadedImageUrl ?? "",
      });

      Navigator.pushNamed(context, RepWaitingApproval.id);
    } else {
      print("No user found with email: $email");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Update Profile"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : _uploadedImageUrl != null &&
                                  _uploadedImageUrl!.isNotEmpty
                              ? NetworkImage(_uploadedImageUrl!)
                              : AssetImage("images/defaultprofilepic.jpg")
                                  as ImageProvider,
                    ),
                    if (_selectedImage == null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(1),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 25,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _accountNameController,
                decoration: InputDecoration(labelText: "Enter Account Name"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Account name cannot be empty';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _accountDescController,
                decoration:
                    InputDecoration(labelText: "Enter Account Description"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Account description cannot be empty';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _updateUserProfile();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please fill in all required fields'),
                      ),
                    );
                  }
                },
                child: Text(
                  "Register",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
