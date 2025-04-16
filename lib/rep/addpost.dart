import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AddPostScreen extends StatefulWidget {
  @override
  static const String id = 'rep_add_post';
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  File? _image;
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
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

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage(File image) async {
    try {
      // Compress and convert to WebP
      final compressedImage = await FlutterImageCompress.compressWithFile(
        image.absolute.path,
        format: CompressFormat.webp,
        quality: 80,
      );

      if (compressedImage == null) {
        throw Exception("Image compression failed.");
      }

      // File name with .webp extension
      String fileName = 'posts/${DateTime.now().millisecondsSinceEpoch}.webp';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);

      // Upload the compressed image as WebP
      UploadTask uploadTask = ref.putData(
        compressedImage,
        SettableMetadata(contentType: 'image/webp'),
      );

      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Upload failed: $e");
      rethrow; // Let the caller handle the exception
    }
  }

  void _sharePost() async {
    if (_image == null || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an image and add a caption')),
      );
      return;
    }

    List<String> selectedTags = allergens.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    String imageUrl = await _uploadImage(_image!);
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    String username = await _fetchUsername(user.email!);
    print(user.email!);

    await _firestore.collection('posts').add({
      'business_name': username,
      'comments': [],
      'content': _contentController.text,
      'email': user.email,
      'imageUrl': imageUrl,
      'likes': [],
      'tags': selectedTags,
      'timestamp': Timestamp.now(),
      'title': _titleController.text,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Post shared successfully')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('New Post'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: _image == null
                  ? Container(
                      height: 200,
                      color: Colors.blueGrey,
                      child: Center(child: Text('Tap to select image')),
                    )
                  : Image.file(_image!, height: 200, fit: BoxFit.cover),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                  labelText: 'Caption',
                  labelStyle: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 10),
            Column(
              children: allergens.keys.map((allergen) {
                return CheckboxListTile(
                  title: Text(
                    allergen,
                    style: TextStyle(color: Colors.white),
                  ),
                  value: allergens[allergen],
                  onChanged: (bool? value) {
                    setState(() {
                      allergens[allergen] = value ?? false;
                    });
                  },
                );
              }).toList(),
            ),
            ElevatedButton(
              onPressed: _sharePost,
              child: Text('Share'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _fetchUsername(String userEmail) async {
    try {
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('rep')
          .where('email', isEqualTo: userEmail)
          .get();

      if (userQuerySnapshot.docs.isNotEmpty) {
        final userData = userQuerySnapshot.docs.first.data();
        return userData['business_name'] ?? 'Unknown';
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
    return 'Not found';
  }
}
