import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:safebite/components/NavBar.dart';
import 'package:image/image.dart' as img;

class Barcode extends StatefulWidget {
  static const String id = "barcode_screen";
  @override
  _BarcodeState createState() => _BarcodeState();
}

class _BarcodeState extends State<Barcode> {
  File? _image;
  String _extractedText = "";
  final ImagePicker _picker = ImagePicker();
  User? currentUser = FirebaseAuth.instance.currentUser;
  List<String> userAllergens = [];

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _processImage();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserAllergens();
  }

  Future<void> _captureImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_image == null) return;

    final imageBytes = await _image!.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) return;

    img.Image resizedImage =
        img.copyResize(originalImage, width: 800); // Resize to max 800px width

    final processedBytes = img.encodeJpg(resizedImage, quality: 85);
    final processedImageFile = File(_image!.path)
      ..writeAsBytesSync(processedBytes);

    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFile(processedImageFile);

    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    setState(() {
      _extractedText = recognizedText.text;
    });

    textRecognizer.close();
    _sendTextToServer(_extractedText);
  }

  Future<void> _sendTextToServer(String text) async {
    final url = Uri.parse("http://192.168.68.106:5007/process_text");

    final requestBody = jsonEncode({"text": text, "allergens": userAllergens});
    print("Sending request to: $url");
    print("Request Body: $requestBody");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json; charset=UTF-8",
          "Accept": "application/json",
        },
        body: requestBody,
      );

      print("Server Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        bool isSafe = responseData["safe"];
        List<dynamic> detectedAllergens = responseData["allergens"];

        String message = isSafe
            ? "Safe to consume"
            : "This product contains:\n" +
                detectedAllergens
                    .map((a) =>
                        "${a['ingredient']} (Allergen: ${a['category']})")
                    .join("\n");

        _showResultDialog(message, isSafe, detectedAllergens);
      } else {
        _showResultDialog(
            "Server Error: ${response.statusCode} - ${response.body}",
            false, []);
      }
    } catch (e) {
      _showResultDialog("Error connecting to server: $e", false, []);
    }
  }

  Future<void> _fetchUserAllergens() async {
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    setState(() {
      userAllergens = (userDoc.data()?['allergens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      print(userAllergens);
    });
  }

  void _showResultDialog(String message, bool isSafe, List<dynamic> allergens) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isSafe ? "Safe to Consume" : "Allergy Alert",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSafe ? "No allergens detected." : "This product contains:",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              if (allergens.isNotEmpty)
                Column(
                  children: allergens.map<Widget>((a) {
                    return Row(
                      children: [
                        Icon(Icons.warning, color: Colors.yellow, size: 20),
                        SizedBox(width: 5),
                        Text(
                          "${a['ingredient']}",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                )
              else if (!isSafe)
                Text(
                  "Allergen detected but not recognized.",
                  style: TextStyle(fontSize: 16, color: Colors.red),
                )
              else
                Text(
                  "Safe to consume.",
                  style: TextStyle(fontSize: 16, color: Colors.green),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Center(child: Text("Ingredients Reader")),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: NavBar(selectedIndex: 3),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 20),
          _image != null
              ? Image.file(_image!, height: 250)
              : Container(
                  height: 250,
                  color: Colors.grey[300],
                  child: Icon(Icons.image, size: 200)),
          SizedBox(height: 70),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: _captureImage,
                  child: Text("Capture Image",
                      style: TextStyle(color: Colors.white))),
              SizedBox(width: 10),
              ElevatedButton(
                  onPressed: _pickImage,
                  child: Text(
                    "Select Image",
                    style: TextStyle(color: Colors.white),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
