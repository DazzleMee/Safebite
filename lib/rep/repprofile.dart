import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:safebite/components/repbar.dart';
import 'package:safebite/rep/addpost.dart';

class RepProfileScreen extends StatefulWidget {
  @override
  static const String id = "rep_prof_screen";
  _RepProfileScreenState createState() => _RepProfileScreenState();
}

class _RepProfileScreenState extends State<RepProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String userEmail = "";
  String businessName = "";
  int followers = 0;
  int following = 0;
  int postCount = 0;
  String profilePicUrl = "";
  File? _selectedImage;
  String? _uploadedImageUrl;
  String? currentUsername = "";
  final ImagePicker _picker = ImagePicker();
  bool _showPosts = true;
  TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    User? user = _auth.currentUser;
    if (user != null) {
      userEmail = user.email!;
      _fetchUsername(userEmail!).then((username) {
        setState(() {
          currentUsername = username;
          print(currentUsername);
        });
      });
    }
  }

  void _showCommentsBottomSheet(BuildContext context, String postId) {
    TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets, // Avoid keyboard overlap
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                // Title
                Text(
                  "Comments",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),

                // Comments List
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return Center(child: CircularProgressIndicator());
                      }

                      var postData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      List<dynamic> commentsList = postData['comments'] ?? [];

                      return ListView(
                        children: commentsList.map<Widget>((c) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 15),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<String>(
                                  future: _fetchprofilePicforcomment(c['user']),
                                  builder: (BuildContext context,
                                      AsyncSnapshot<String> snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return CircleAvatar(
                                        backgroundColor: Colors.blueGrey,
                                        child: Text(
                                          c["user"][0].toUpperCase(),
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      );
                                    } else if (snapshot.hasError ||
                                        snapshot.data == null ||
                                        snapshot.data!.isEmpty) {
                                      return CircleAvatar(
                                        backgroundColor: Colors.blueGrey,
                                        child: Text(
                                          c["user"][0].toUpperCase(),
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      );
                                    } else {
                                      return CircleAvatar(
                                        backgroundImage:
                                            NetworkImage(snapshot.data!),
                                      );
                                    }
                                  },
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c["user"],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        c["com"],
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),

                Divider(),

                // Comment Input Field
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: "Add a comment...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 15),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.send, color: Colors.blue),
                        onPressed: () {
                          _addComment(postId, commentController.text.trim());
                          commentController
                              .clear(); // Clear input after submission
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadProfileData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      userEmail = user.email ?? "";

      DocumentSnapshot repDoc =
          await _firestore.collection("rep").doc(user.uid).get();
      if (repDoc.exists) {
        setState(() {
          businessName = repDoc["business_name"] ?? "Business Name";
          List<dynamic> followersList = repDoc["followers"] ?? [];
          followers = followersList.length;
          List<dynamic> followingList = repDoc["following"] ?? [];
          following = followingList.length;
          profilePicUrl = repDoc["profilePic"] ?? "";
        });
      }

      print(profilePicUrl);
      print("yes");

      QuerySnapshot postSnapshot = await _firestore
          .collection("posts")
          .where("email", isEqualTo: userEmail)
          .get();
      setState(() {
        postCount = postSnapshot.size;
      });
    }
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
      String fileName = 'profile_pics/${_auth.currentUser!.email}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
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
        "profilePic": _uploadedImageUrl ?? "",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profile updated successfully!")),
      );
    } else {
      print("No user found with email: $email");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: Repbar(selectedIndex: 3),
      appBar: AppBar(
        title: Center(child: Text("Profile")),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              color: Colors.grey[800],
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _pickImage();
                      if (_selectedImage != null) {
                        await _updateUserProfile();
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (_uploadedImageUrl != null &&
                                      _uploadedImageUrl!.isNotEmpty)
                                  ? NetworkImage(_uploadedImageUrl!)
                                  : (profilePicUrl.isNotEmpty
                                      ? NetworkImage(profilePicUrl)
                                      : AssetImage(
                                              "images/defaultprofilepic.jpg")
                                          as ImageProvider),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors
                                  .white, // White background for better visibility
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            padding:
                                EdgeInsets.all(5), // Adjust padding for size
                            child: Icon(Icons.camera_alt,
                                size: 24, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(businessName,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(children: [Text("$postCount"), Text("Posts")]),
                      SizedBox(width: 16),
                      Column(children: [Text("$followers"), Text("Followers")]),
                      SizedBox(width: 16),
                      Column(children: [Text("$following"), Text("Following")]),
                    ],
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AddPostScreen.id);
                      },
                      child: Text("Add a post")),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showPosts = true;
                    });
                  },
                  child: Text(
                    "Posts",
                    style: TextStyle(
                      color: _showPosts ? Colors.blue : Colors.grey,
                      fontWeight:
                          _showPosts ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showPosts = false;
                    });
                  },
                  child: Text(
                    "Menu",
                    style: TextStyle(
                      color: !_showPosts ? Colors.blue : Colors.grey,
                      fontWeight:
                          !_showPosts ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            if (_showPosts)
              StreamBuilder(
                stream: _firestore
                    .collection("posts")
                    .where("email", isEqualTo: userEmail)
                    .orderBy("timestamp", descending: true)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      return _buildPost(doc);
                    }).toList(),
                  );
                },
              )
            else
              _buildMenuSection()
          ],
        ),
      ),
    );
  }

  void _toggleLike(String postId, List<dynamic> likes) async {
    final postRef = FirebaseFirestore.instance.collection("posts").doc(postId);
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('rep')
        .where('email', isEqualTo: user.email)
        .get();

    String username = userDoc.docs.isNotEmpty
        ? userDoc.docs.first.data()['business_name'] ?? 'Unknown'
        : 'Unknown';

    List<Map<String, dynamic>> likesList = likes.cast<Map<String, dynamic>>();

    bool alreadyLiked = likesList.any((like) => like['username'] == username);

    if (alreadyLiked) {
      likesList.removeWhere((like) => like['username'] == username);
    } else {
      likesList.add({
        "username": username,
        "timestamp": Timestamp.now(),
      });
    }

    await postRef.update({"likes": likesList});
  }

  void _showCommentDialog(String postId, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add a Comment"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter your comment..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _addComment(postId, controller.text);
                Navigator.pop(context);
              },
              child: Text("Post"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMenu() async {
    try {
      await _firestore.collection("rep").doc(_auth.currentUser!.uid).update({
        "menu": FieldValue.delete(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Menu deleted successfully!")),
      );
      setState(() {}); // Refresh the UI
    } catch (e) {
      print("Error deleting menu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting menu.")),
      );
    }
  }

  Widget _buildMenuSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection("rep").doc(_auth.currentUser!.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                _uploadMenu();
              },
              child: Text("Add Menu Pages"),
            ),
          );
        }

        Map<String, dynamic>? data =
            snapshot.data!.data() as Map<String, dynamic>?;
        dynamic menuData = data?['menu'];

        List<String> menuUrls = [];

        if (menuData is String) {
          menuUrls.add(menuData);
        } else if (menuData is List) {
          menuUrls = menuData.cast<String>();
        }

        if (menuUrls.isNotEmpty) {
          return Column(
            children: [
              _buildScrollableMenu(menuUrls), // Build scrollable menu
              ElevatedButton(
                onPressed: () {
                  _uploadMenu();
                },
                child: Text("Update Menu"),
              ),

              ElevatedButton(
                onPressed: () {
                  _deleteMenu(); // Call deleteMenu function
                },
                child: Text("Delete Menu"),
              )
            ],
          );
        } else {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                _uploadMenu();
              },
              child: Text("Add Menu"),
            ),
          );
        }
      },
    );
  }

  Widget _buildScrollableMenu(List<String> menuUrls) {
    return SizedBox(
      height: 400,
      child: PageView.builder(
        itemCount: menuUrls.length,
        itemBuilder: (context, index) {
          return Image.network(menuUrls[index]);
        },
      ),
    );
  }

  Future<void> _uploadMenu() async {
    try {
      final List<XFile>? pickedFiles = await ImagePicker().pickMultiImage();

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        List<String> imageUrls = [];

        for (var pickedFile in pickedFiles) {
          final compressedImage = await FlutterImageCompress.compressWithFile(
            pickedFile.path,
            format: CompressFormat.webp,
            quality: 80,
          );

          if (compressedImage == null) continue;
          String fileName =
              'menus/${_auth.currentUser!.email}_${DateTime.now().millisecondsSinceEpoch}_${pickedFiles.indexOf(pickedFile)}.webp';

          Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

          UploadTask uploadTask = storageRef.putData(
            compressedImage,
            SettableMetadata(contentType: 'image/webp'),
          );

          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();
          imageUrls.add(downloadUrl);
        }

        // Save image URLs to Firestore
        await _firestore.collection("rep").doc(_auth.currentUser!.uid).update({
          "menu": FieldValue.arrayUnion(imageUrls),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Menu uploaded successfully!")),
        );
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Menu upload cancelled.")),
        );
      }
    } catch (e) {
      print("Error uploading menu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading menu.")),
      );
    }
  }

  void _addComment(String postId, String comment) {
    if (comment.isEmpty) return;

    final postRef = FirebaseFirestore.instance.collection("posts").doc(postId);
    postRef.update({
      "comments": FieldValue.arrayUnion([
        {"user": businessName, "com": comment, "timestamp": Timestamp.now()}
      ])
    });
  }

  Widget _buildPost(DocumentSnapshot doc) {
    List<dynamic> likes = doc["likes"] ?? [];
    bool isLiked = likes.any((like) =>
        like is Map<String, dynamic> && like['username'] == currentUsername);
    String postTitle = doc['title'] ?? 'No Title';
    String postContent = doc['content'] ?? 'No Content';
    List<dynamic> tags = doc['tags'] ?? [];
    String tagText = tags.isNotEmpty ? tags.join(", ") : "No tags";

    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!)
                  : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
                      ? NetworkImage(_uploadedImageUrl!)
                      : (profilePicUrl.isNotEmpty
                          ? NetworkImage(profilePicUrl)
                          : AssetImage("images/defaultprofilepic.jpg")
                              as ImageProvider),
            ),
            title: Text(businessName),
            subtitle: Text(tagText, style: TextStyle(color: Colors.grey[400])),
          ),
          Image.network(doc["imageUrl"]),
          Row(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 80,
                  ),
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : null,
                      size: 30,
                    ),
                    onPressed: () {
                      _toggleLike(doc.id, likes);
                    },
                  ),
                  Text(" ${likes.length}"),
                  SizedBox(
                    width: 100,
                  )
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.comment,
                  size: 30,
                ),
                onPressed: () {
                  _showCommentsBottomSheet(context, doc.id);
                },
              ),
              SizedBox(
                width: 50,
              ),
            ],
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection("posts")
                .doc(doc.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return CircularProgressIndicator();
              }

              var postData = snapshot.data!.data() as Map<String, dynamic>;
              List<dynamic> commentsList = postData['comments'] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: commentsList.map<Widget>((c) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 25),
                    child: Text(
                      "${c["user"]}: ${c["com"]}",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
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

Future<String> _fetchprofilePicforcomment(String userId) async {
  try {
    final repQuery = await FirebaseFirestore.instance
        .collection('rep')
        .where('business_name', isEqualTo: userId)
        .get();

    if (repQuery.docs.isNotEmpty) {
      return repQuery.docs.first.data()['profilePic'] ?? 'Unknown';
    }

    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: userId)
        .get();

    if (userQuery.docs.isNotEmpty) {
      return userQuery.docs.first.data()['profilePic'] ?? 'Unknown';
    }
  } catch (e) {
    print('Error fetching profile picture: $e');
  }

  return 'Not found';
}
