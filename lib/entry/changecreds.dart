import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:gui/screens/chat.dart';
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
  final ImagePicker _picker = ImagePicker();
  File? _prfimg;
  String? _imglink;
  bool _editname = false;
  bool _editbio = false;

  @override
  void dispose() {
    _nicknameController.dispose();
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

      final storageRef =
          _storage.ref().child('profilepic').child('${currentUser!.uid}.jpg');

      await storageRef.putFile(_prfimg!);

      final imageUrl = await storageRef.getDownloadURL();

      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: currentUser.email)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docId = snapshot.docs[0].id;

        await _firestore.collection('users').doc(docId).update({
          'profilePic': imageUrl,
        });
        setState(() {
          _imglink = imageUrl;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profile picture updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload profile picture: $e")),
      );
    }
  }

  Future<void> _updateNickname(String newNickname) async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        QuerySnapshot snapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: currentUser.email)
            .get();

        for (var doc in snapshot.docs) {
          await _firestore.collection('users').doc(doc.id).update({
            'username': newNickname,
          });

          setState(() {
            _editname = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Nickname updated!")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("update failed: $e")),
      );
    }
  }

  Future<void> _updatebio(String newbio) async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        QuerySnapshot snapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: currentUser.email)
            .get();

        for (var doc in snapshot.docs) {
          await _firestore.collection('users').doc(doc.id).update({
            'bio': newbio,
          });

          setState(() {
            _editname = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Nickname updated!")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("update failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: NavBar(selectedIndex: 3),
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: null,
          actions: [
            IconButton(
              onPressed: () async {
                // await Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => ChatScreen()),
                // );
              },
              icon: Icon(Icons.close),
            ),
          ],
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Center(
              child: Text(
                'Profile',
                style: TextStyle(fontSize: 25, color: Colors.white),
              ),
            ),
          ),
        ),
        body: FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('users')
              .where('email', isEqualTo: currentUser?.email)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'Profile not found.',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            final userData =
                snapshot.data!.docs[0].data() as Map<String, dynamic>;
            final email = currentUser?.email ?? 'No email';
            final nickname = userData['username'] ?? email;
            final bio = userData['bio'] ?? "no bio added";
            _imglink = userData['profilePic'];

            if (!_editname) {
              _nicknameController.text = nickname;
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _selImg,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.lightBlueAccent,
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Email
                    Text(
                      'Email:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      email,
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),

                    // Nickname
                    Text(
                      'Username:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _editname
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nicknameController,
                                  decoration: InputDecoration(
                                    hintText: "Enter your nickname",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.check, color: Colors.green),
                                onPressed: () {
                                  _updateNickname(
                                      _nicknameController.text.trim());
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  nickname,
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  setState(() {
                                    _editname = true;
                                  });
                                },
                              ),
                            ],
                          ),
                    Text(
                      'Bio',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _editbio
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nicknameController,
                                  decoration: InputDecoration(
                                    hintText: "Enter your nickname",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.check, color: Colors.green),
                                onPressed: () {
                                  _updateNickname(
                                      _nicknameController.text.trim());
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bio,
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  setState(() {
                                    _editbio = true;
                                  });
                                },
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
