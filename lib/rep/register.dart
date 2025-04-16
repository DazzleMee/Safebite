import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:safebite/components/rounded_button.dart';
import 'package:safebite/rep/repcreds.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RegisterBusinessScreen(),
    );
  }
}

class RegisterBusinessScreen extends StatefulWidget {
  @override
  static const String id = "rep_register";
  _RegisterBusinessScreenState createState() => _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _cfmpasswordController = TextEditingController();
  final TextEditingController _establishmentController =
      TextEditingController();

  File? _selectedImage;
  GoogleMapController? mapController;
  LatLng _selectedLocation = const LatLng(3.1390, 101.6869);
  Marker? _marker;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _searchLocation() async {
    String query = _establishmentController.text;
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location newLocation = locations.first;
        LatLng newLatLng = LatLng(newLocation.latitude, newLocation.longitude);

        setState(() {
          _selectedLocation = newLatLng;
          _marker = Marker(
            markerId: const MarkerId("searched_location"),
            position: newLatLng,
          );
        });

        mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));
      } else {
        _showError("Location not found!");
      }
    } catch (e) {
      _showError("Error finding location. Try again.");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadBusinessCert() async {
    if (_selectedImage == null) return null;

    try {
      // Compress and convert to WebP
      final result = await FlutterImageCompress.compressWithFile(
        _selectedImage!.absolute.path,
        format: CompressFormat.webp,
        quality: 80,
      );

      if (result == null) {
        _showError("Compression failed.");
        return null;
      }

      String fileName =
          "certificates/${DateTime.now().millisecondsSinceEpoch}.webp";
      Reference ref = _storage.ref().child(fileName);

      UploadTask uploadTask = ref.putData(
        result,
        SettableMetadata(contentType: 'image/webp'),
      );

      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Upload error: $e");
      _showError("Failed to upload certificate.");
      return null;
    }
  }

  Future<void> _registerBusiness() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String cfmpassword = _cfmpasswordController.text.trim();
    String establishmentName = _establishmentController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        cfmpassword.isEmpty ||
        establishmentName.isEmpty ||
        _selectedImage == null) {
      _showError("Please fill all fields and upload a business certificate.");
      return;
    }

    if (password != cfmpassword) {
      _showError("Passwords do not match!");
      return;
    }

    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      String uid = userCredential.user!.uid;

      String? certURL = await _uploadBusinessCert();
      if (certURL == null) return;

      await _firestore.collection("rep").doc(uid).set({
        "email": email,
        "business_name": establishmentName,
        "business_location":
            GeoPoint(_selectedLocation.latitude, _selectedLocation.longitude),
        "cert": certURL,
        "registered_at": FieldValue.serverTimestamp(),
        "accountName": "",
        "accountDesc": "",
        "profilePic": "",
        "followers": [],
        "following": [],
        "approved": "no",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Business Registered Successfully!")),
      );

      Future.delayed(Duration(seconds: 1), () {
        Navigator.pushNamed(context, ProfileUpdateScreen.id);
      });

      _emailController.clear();
      _passwordController.clear();
      _cfmpasswordController.clear();
      _establishmentController.clear();
      setState(() {
        _selectedImage = null;
        _marker = null;
      });
    } catch (e) {
      _showError("Registration failed: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: AppBar(
        title: Center(child: const Text("Register Business Account")),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildTextField("Email", controller: _emailController),
            _buildTextField("Password",
                controller: _passwordController, obscureText: true),
            _buildTextField("Confirm Password",
                controller: _cfmpasswordController, obscureText: true),
            const SizedBox(height: 10),
            const Text("Establishment Name"),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _establishmentController,
                    decoration: InputDecoration(
                      hintText: "Search for your establishment...",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.search), onPressed: _searchLocation),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition:
                    CameraPosition(target: _selectedLocation, zoom: 14.0),
                markers: _marker != null ? {_marker!} : {},
              ),
            ),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: GestureDetector(
                  onTap: () {
                    launch("https://www.google.com/business/");
                  },
                  child: const Text(
                    "Can't find your location? Tap here to Register Business on Google Maps",
                    style: TextStyle(color: Colors.blue),
                    textAlign: TextAlign.center, // Add this line
                  ),
                )),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Submit Business Cert."),
                TextButton(
                    onPressed: _pickImage, child: const Text("Choose File")),
              ],
            ),
            _selectedImage != null
                ? Image.file(_selectedImage!, height: 80)
                : const Text("No file chosen",
                    style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            RoundedButton(
              onPressed: _registerBusiness,
              title: 'Register',
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildTextField(String label,
    {TextEditingController? controller, bool obscureText = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
      style: TextStyle(color: Colors.white),
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white),
        hintStyle: (TextStyle(color: Colors.white)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
