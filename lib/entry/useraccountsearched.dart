import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safebite/components/NavBar.dart';

class UserAccountSearched extends StatefulWidget {
  final String businessAccountEmail;

  UserAccountSearched({required this.businessAccountEmail});

  @override
  static const String id = "user_account_searched";
  _UserAccountSearchedState createState() => _UserAccountSearchedState();
}

class _UserAccountSearchedState extends State<UserAccountSearched> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String businessName = "";
  String profilePicUrl = "";
  String? currentUserUID;
  String? searchedUID;
  int followers = 0;
  int following = 0;
  int postCount = 0;
  bool isFollowing = false;
  String? userEmail = "";
  String? currentUsername = "";
  bool _showPosts = true;

  @override
  void initState() {
    super.initState();
    User? user = _auth.currentUser;
    if (user != null) {
      userEmail = user.email;
      _fetchUsername(userEmail!).then((username) {
        setState(() {
          currentUsername = username;
        });
      });
    }
    _loadProfileData();
  }

  Future<String> _fetchUsername(String userId) async {
    try {
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userId)
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

  Future<void> _loadProfileData() async {
    currentUserUID = _auth.currentUser?.uid;

    QuerySnapshot querySnapshot = await _firestore
        .collection("rep")
        .where("email", isEqualTo: widget.businessAccountEmail)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    DocumentSnapshot repDoc = querySnapshot.docs.first;
    searchedUID = repDoc.id;

    if (repDoc.exists) {
      List<dynamic> followersList = repDoc["followers"] ?? [];

      setState(() {
        businessName = repDoc["business_name"] ?? "Business Name";
        profilePicUrl = repDoc["profilePic"] ?? "";
        followers = followersList.length;
        following = (repDoc["following"] ?? []).length;
        isFollowing = followersList.contains(currentUserUID);
      });
    }

    QuerySnapshot postSnapshot = await _firestore
        .collection("posts")
        .where("email", isEqualTo: widget.businessAccountEmail)
        .get();

    setState(() {
      postCount = postSnapshot.size;
    });
  }

  void _addComment(String postId, String comment) {
    if (comment.isEmpty) return;

    FirebaseFirestore.instance.collection('posts').doc(postId).update({
      "comments": FieldValue.arrayUnion([
        {"user": currentUsername, "com": comment, "timestamp": Timestamp.now()}
      ])
    });
  }

  void _toggleFollow() async {
    if (currentUserUID == null || searchedUID == null) return;

    DocumentReference repRef = _firestore.collection("rep").doc(searchedUID);
    DocumentReference currentUserRef =
        _firestore.collection("users").doc(currentUserUID);

    if (isFollowing) {
      await repRef.update({
        "followers": FieldValue.arrayRemove([currentUserUID])
      });
      await currentUserRef.update({
        "following": FieldValue.arrayRemove([searchedUID])
      });
      setState(() {
        followers--;
        isFollowing = false;
      });
    } else {
      await repRef.update({
        "followers": FieldValue.arrayUnion([currentUserUID])
      });
      await currentUserRef.update({
        "following": FieldValue.arrayUnion([searchedUID])
      });
      setState(() {
        followers++;
        isFollowing = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: NavBar(selectedIndex: 1),
      appBar: AppBar(
        title: Text("Search Accounts"),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: profilePicUrl.isNotEmpty
                      ? NetworkImage(profilePicUrl)
                      : AssetImage("images/defaultprofilepic.jpg")
                          as ImageProvider,
                ),
                SizedBox(height: 10),
                Text(
                  businessName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(postCount, "Posts"),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection("rep")
                          .doc(searchedUID)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return _buildStatColumn(0, "Followers");
                        }

                        var docData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        int updatedFollowers =
                            (docData["followers"] as List?)?.length ?? 0;

                        return _buildStatColumn(updatedFollowers, "Followers");
                      },
                    ),
                    _buildStatColumn(following, "Following"),
                  ],
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(isFollowing ? "Unfollow" : "Follow"),
                ),
              ],
            ),
          ),

          // Posts / Menu toggle
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

          // Posts or Menu content
          Expanded(
            child: _showPosts
                ? StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection("posts")
                        .where("email", isEqualTo: widget.businessAccountEmail)
                        .orderBy("timestamp", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      return ListView(
                        children: snapshot.data!.docs
                            .map((doc) => _buildPost(doc))
                            .toList(),
                      );
                    },
                  )
                : _buildMenuSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      children: [
        Text("$count",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
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
          padding: MediaQuery.of(context).viewInsets,
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

  Widget _buildPost(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    String postTitle = data?['title'] ?? 'No Title';
    String postContent = data?['content'] ?? 'No Title';
    List<dynamic> tags = data?['tags'] ?? [];
    String tagText = tags.isNotEmpty ? tags.join(", ") : "No tags";
    List<dynamic> likes = data?["likes"] ?? [];
    bool isLiked = likes.any((like) =>
        like is Map<String, dynamic> && like['username'] == currentUsername);
    if (data == null) return SizedBox.shrink();
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
                  businessName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle:
                    Text(tagText, style: TextStyle(color: Colors.grey[400])),
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

  Widget _buildMenuSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore
          .collection("rep")
          .where("email", isEqualTo: widget.businessAccountEmail)
          .get()
          .then((querySnapshot) => querySnapshot.docs.first),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Text("No menu available."),
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
          return _buildScrollableMenu(menuUrls); // Build scrollable menu
        } else {
          return Center(
            child: Text("No menu available."),
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
