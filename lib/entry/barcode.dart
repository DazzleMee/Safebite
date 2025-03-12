import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:safebite/components/NavBar.dart';

class Barcode extends StatefulWidget {
  static const String id = "barcode_screen";
  @override
  _BarcodeState createState() => _BarcodeState();
}

class _BarcodeState extends State<Barcode> {
  File? _image;
  String _extractedText = "";
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _processImage();
    }
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
    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFile(_image!);
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    setState(() {
      _extractedText = recognizedText.text;
    });
    textRecognizer.close();
    _sendTextToServer(_extractedText);
  }

  Future<void> _sendTextToServer(String text) async {
    final url = Uri.parse("http://192.168.1.7:5007/process_text");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json; charset=UTF-8",
          "Accept": "application/json",
        },
        body: jsonEncode({"text": text}),
      );

      print("Server Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        bool isSafe = responseData["safe"];
        String message = isSafe
            ? " Safe to consume"
            : "Allergens detected: ${responseData["allergens"].join(", ")}";

        _showResultDialog(message, isSafe);
      } else {
        _showResultDialog("Server Error: ${response.statusCode}", false);
      }
    } catch (e) {
      _showResultDialog("Error connecting to server: $e", false);
    }
  }

  void _showResultDialog(String message, bool isSafe) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isSafe ? "Safe to Consume" : "Allergy Alert"),
          content: Text(message, style: TextStyle(fontSize: 16)),
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
      appBar: AppBar(
        title: Center(child: Text("Ingredients Reader")),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: NavBar(selectedIndex: 1),
      body: Column(
        children: [
          SizedBox(height: 20),
          _image != null
              ? Image.file(_image!, height: 250)
              : Container(
                  height: 250,
                  color: Colors.grey[300],
                  child: Icon(Icons.image, size: 100)),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: _pickImage, child: Text("Select Image")),
              SizedBox(width: 10),
              ElevatedButton(
                  onPressed: _captureImage, child: Text("Capture Image")),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Text(_extractedText, style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
