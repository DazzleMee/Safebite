import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:safebite/components/repbar.dart';
import 'package:safebite/entry/changecreds.dart';
import 'package:safebite/rep/addpost.dart';

import '../components/NavBar.dart';

class ProfilePage extends StatefulWidget {
  @override
  static const String id = "prof_screen";
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
  int interactionCount = 0;
  List<String> followedAccounts = [];

  @override
  void initState() {
    super.initState();
    print(_auth.currentUser!.email);
    _loadProfileData();
    User? user = _auth.currentUser;
    if (user != null) {
      userEmail = user.email!;
      _fetchUsername(userEmail!).then((username) {
        setState(() {
          currentUsername = username;
        });
      });
      _fetchFollowedAccounts();
    }
  }

  Future<List<DocumentSnapshot>> getLikedPosts() async {
    QuerySnapshot postSnapshot = await _firestore.collection("posts").get();
    List<DocumentSnapshot> likedPosts = [];

    for (var post in postSnapshot.docs) {
      var postData = post.data() as Map<String, dynamic>;

      if (postData.containsKey("likes") && postData["likes"] is List) {
        List<dynamic> likes = postData["likes"];
        bool isLikedByUser = likes
            .where((like) =>
                like is Map<String, dynamic> &&
                like['username'] == currentUsername)
            .isNotEmpty;

        if (isLikedByUser) {
          likedPosts.add(post);
        }
      }
    }

    return likedPosts;
  }

  Future<void> _loadProfileData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      userEmail = user.email ?? "";

      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          String username = userDoc["username"] ?? "Name Not Found";
          profilePicUrl = userDoc["profilePic"] ?? "";
        });
      }
      int totalInteractions = 0;

      QuerySnapshot postSnapshot = await _firestore.collection("posts").get();

      for (var post in postSnapshot.docs) {
        var postData = post.data() as Map<String, dynamic>;

        if (postData.containsKey("likes") && postData["likes"] is List) {
          List<dynamic> likes = postData["likes"];
          totalInteractions += likes
              .where((comment) =>
                  comment is Map<String, dynamic> &&
                  comment.containsKey("username") &&
                  comment["username"] == currentUsername)
              .length;
        }

        if (postData.containsKey("comments") && postData["comments"] is List) {
          List<dynamic> comments = postData["comments"];
          totalInteractions += comments
              .where((comment) =>
                  comment is Map<String, dynamic> &&
                  comment.containsKey("user") &&
                  comment["user"] == currentUsername)
              .length;
        }
      }

      int followingCount = 0;

      QuerySnapshot repSnapshot = await _firestore.collection("rep").get();
      for (var rep in repSnapshot.docs) {
        var repData = rep.data() as Map<String, dynamic>;

        if (repData.containsKey("followers") && repData["followers"] is List) {
          List<dynamic> followers = repData["followers"];
          if (followers.contains(user.uid)) {
            followingCount++;
          }
        }
      }

      // Update state with calculated values
      setState(() {
        postCount = postSnapshot.size;
        following = followingCount;
        interactionCount = totalInteractions;
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
      // Compress and convert the image to WebP
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        format: CompressFormat.webp,
        quality: 80,
      );

      if (compressedBytes == null) throw Exception("Compression failed");

      // Construct the file name with .webp extension
      String fileName = 'profile_pics/${_auth.currentUser!.email}.webp';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      // Upload the compressed WebP data
      UploadTask uploadTask = storageRef.putData(
        compressedBytes,
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

    QuerySnapshot querySnapshot = await _firestore
        .collection("users")
        .where("email", isEqualTo: email)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      String docId = querySnapshot.docs.first.id;

      if (_selectedImage != null) {
        _uploadedImageUrl = await _uploadImageToFirebase(_selectedImage!);
      }

      await _firestore.collection("users").doc(docId).update({
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        bottomNavigationBar: NavBar(selectedIndex: 4),
        appBar: AppBar(
          centerTitle: true,
          title: Text("Profile"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, ChangeCreds.id);
                },
                icon: Icon(Icons.settings))
          ],
        ),
        body: Column(
          children: [
            // Profile Section
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
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.camera_alt,
                                size: 24, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    currentUsername!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text("$interactionCount"),
                          Text("Interactions"),
                        ],
                      ),
                      SizedBox(width: 16),
                      Column(
                        children: [
                          Text("$following"),
                          Text("Following"),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),

            TabBar(
              tabs: [
                Tab(text: "Liked Posts"),
                Tab(text: "Commented Posts"),
              ],
            ),

            // TabBarView
            Expanded(
              child: TabBarView(
                children: [
                  // Liked Posts
                  FutureBuilder<List<DocumentSnapshot>>(
                    future: getLikedPosts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text("No liked posts found."));
                      }
                      return ListView(
                        children: snapshot.data!.map(_buildPost).toList(),
                      );
                    },
                  ),

                  // Commented Posts
                  FutureBuilder<List<DocumentSnapshot>>(
                    future: getCommentedPosts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text("No commented posts found."));
                      }
                      return ListView(
                        children: snapshot.data!.map(_buildPost).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addComment(String postId, String comment) {
    if (comment.isEmpty) return;

    FirebaseFirestore.instance.collection('posts').doc(postId).update({
      "comments": FieldValue.arrayUnion([
        {"user": currentUsername, "com": comment}
      ])
    });
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
                          // print(c['user']);
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

  Future<List<DocumentSnapshot>> getCommentedPosts() async {
    QuerySnapshot postSnapshot = await _firestore.collection("posts").get();
    List<DocumentSnapshot> commentedPosts = [];

    for (var post in postSnapshot.docs) {
      var postData = post.data() as Map<String, dynamic>;

      if (postData.containsKey("comments") && postData["comments"] is List) {
        List<dynamic> comments = postData["comments"];
        bool hasUserCommented = comments.any((comment) =>
            comment is Map<String, dynamic> &&
            comment['user'] == currentUsername);

        if (hasUserCommented) {
          commentedPosts.add(post);
        }
      }
    }
    return commentedPosts;
  }

  void _toggleLike(String postId, List<dynamic> likes) async {
    final postRef = FirebaseFirestore.instance.collection("posts").doc(postId);
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: user.email)
        .get();

    String username = userDoc.docs.isNotEmpty
        ? userDoc.docs.first.data()['username'] ?? 'Unknown'
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

    print(likesList);

    await postRef.update({"likes": likesList});
    setState(() {});
  }

  Future<void> _toggleFollow(String accountToFollow) async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final String? currentUserUID = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserUID == null) return;

    final querySnapshot = await _firestore
        .collection("rep")
        .where('business_name', isEqualTo: accountToFollow)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final DocumentReference businessDocRef = querySnapshot.docs.first.reference;
    final String businessUID = querySnapshot.docs.first.id;

    final userQuerySnapshot = await _firestore
        .collection("users")
        .where('email', isEqualTo: userEmail)
        .limit(1)
        .get();

    if (userQuerySnapshot.docs.isEmpty) return;

    final DocumentReference userDocRef = userQuerySnapshot.docs.first.reference;

    final userSnapshot = await userDocRef.get();
    final Map<String, dynamic>? userData =
        userSnapshot.data() as Map<String, dynamic>?;
    List<dynamic> followingList = userData?['following'] ?? [];

    final Map<String, dynamic>? businessData = querySnapshot.docs.first.data();
    List<dynamic> followersList = businessData?['followers'] ?? [];

    final WriteBatch batch = _firestore.batch();

    if (followersList.contains(currentUserUID)) {
      print("YESS");
      batch.update(businessDocRef, {
        "followers": FieldValue.arrayRemove([currentUserUID])
      });

      batch.update(userDocRef, {
        "following": FieldValue.arrayRemove([businessUID])
      });

      setState(() {
        followedAccounts.remove(accountToFollow);
      });
    } else {
      // If not following, add to followers & following
      batch.update(businessDocRef, {
        "followers": FieldValue.arrayUnion([currentUserUID])
      });

      batch.update(userDocRef, {
        "following": FieldValue.arrayUnion([businessUID])
      });

      setState(() {
        followedAccounts.add(accountToFollow);
      });
    }

    await batch.commit();
  }

  Future<void> _fetchFollowedAccounts() async {
    if (userEmail == null) return;

    final querySnapshot =
        await FirebaseFirestore.instance.collection("rep").get();

    List<String> tempFollowedAccounts = [];

    for (var doc in querySnapshot.docs) {
      List<dynamic> followers = doc.data()?['followers'] ?? [];

      if (followers.contains(_auth.currentUser!.uid)) {
        tempFollowedAccounts.add(doc.data()?['business_name']);
      }
    }

    setState(() {
      followedAccounts = tempFollowedAccounts;
    });
  }

  Widget _buildPost(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return SizedBox.shrink();

    String postOwner = data['business_name'] ?? 'Unknown';
    bool isFollowing = followedAccounts.contains(postOwner);
    String postTitle = data['title'] ?? 'No Title';
    String postContent = data['content'] ?? 'No Title';

    List<dynamic> tags = data['tags'] ?? [];
    String tagText = tags.isNotEmpty ? tags.join(", ") : "No tags";
    List<dynamic> likes = data["likes"] ?? [];
    bool isLiked = likes.any((like) =>
        like is Map<String, dynamic> && like['username'] == currentUsername);

    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: _fetchprofilePicforcomment(data['business_name']),
            builder: (context, snapshot) {
              final profilePicUrl = snapshot.data ?? '';
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: profilePicUrl.isNotEmpty
                      ? NetworkImage(profilePicUrl)
                      : AssetImage('images/defaultprofilepic.jpg')
                          as ImageProvider,
                  backgroundColor: Colors.grey[200],
                ),
                title: Text(
                  postOwner,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle:
                    Text(tagText, style: TextStyle(color: Colors.grey[400])),
                trailing: ElevatedButton(
                  onPressed: () => _toggleFollow(postOwner),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                  ),
                  child: Text(isFollowing ? "Unfollow" : "Follow"),
                ),
              );
            },
          ),
          if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
            Image.network(data["imageUrl"]),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 50,
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
                  ],
                ),
                SizedBox(
                  width: 50,
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(doc.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return Row(
                        children: [
                          Icon(Icons.comment, size: 30),
                          SizedBox(width: 5),
                          Text("0"),
                        ],
                      );
                    }

                    var postData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    List<dynamic> commentsList = postData['comments'] ?? [];

                    return Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.comment, size: 30),
                          onPressed: () {
                            _showCommentsBottomSheet(context, doc.id);
                          },
                        ),
                        SizedBox(width: 5),
                        Text("${commentsList.length}"),
                      ],
                    );
                  },
                ),
                SizedBox(
                  width: 50,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              postTitle,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              postContent,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String> _fetchUsername(String userEmail) async {
  try {
    final userQuerySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuerySnapshot.docs.isNotEmpty) {
      final userData = userQuerySnapshot.docs.first.data();
      return userData['username'] ?? 'Unknown';
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
