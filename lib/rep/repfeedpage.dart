import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safebite/components/repbar.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class RepFeedPage extends StatefulWidget {
  static const String id = 'rep_feed_page';

  @override
  _RepFeedPageState createState() => _RepFeedPageState();
}

class _RepFeedPageState extends State<RepFeedPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userEmail = "";
  TextEditingController commentController = TextEditingController();

  String? currentUsername;
  List<String> followedAccounts = [];

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
      _fetchFollowedAccounts();
    }
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
        .collection("rep")
        .where('email', isEqualTo: userEmail)
        .limit(1)
        .get();

    if (userQuerySnapshot.docs.isEmpty) return;

    final DocumentReference userDocRef = userQuerySnapshot.docs.first.reference;

    final userSnapshot = await userDocRef.get();
    final Map<String, dynamic>? userData =
        userSnapshot.data() as Map<String, dynamic>?;
    List<dynamic> followingList = userData?['following'] ?? [];

    // Fetch business followers list safely
    final Map<String, dynamic>? businessData = querySnapshot.docs.first.data();
    List<dynamic> followersList = businessData?['followers'] ?? [];

    final WriteBatch batch = _firestore.batch();

    if (followersList.contains(currentUserUID)) {
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
                                      // If there's an error or no image URL, show a default avatar
                                      return CircleAvatar(
                                        backgroundColor: Colors.blueGrey,
                                        child: Text(
                                          c["user"][0].toUpperCase(),
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      );
                                    } else {
                                      // If the future is complete and has data, show the network image
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

  void _addComment(String postId, String comment) {
    if (comment.isEmpty) return;

    final postRef = FirebaseFirestore.instance.collection("posts").doc(postId);
    postRef.update({
      "comments": FieldValue.arrayUnion([
        {
          "user": currentUsername,
          "com": comment,
          "timestamp": Timestamp.now()
        } // Replace with actual username
      ])
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[999],
        elevation: 1,
        title: Center(
          child: Text(
            'For You Page',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
      bottomNavigationBar: Repbar(selectedIndex: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No posts available'));
          }

          final posts = snapshot.data!.docs;

          return SingleChildScrollView(
            child: Column(
              children: posts.map((post) => _buildPostCard(post)).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(DocumentSnapshot post) {
    final data = post.data() as Map<String, dynamic>?;

    if (data == null) return SizedBox.shrink();

    String postOwner = data['business_name'] ?? 'Unknown';
    String postTitle = data['title'] ?? 'No Title';
    String postContent = data['content'] ?? 'No Content';
    List<dynamic> likes = data?["likes"] ?? [];
    bool isLiked = likes.any((like) => like["username"] == currentUsername);
    bool isFollowing = followedAccounts.contains(postOwner);
    List<dynamic> tags = data['tags'] ?? [];
    String tagText = tags.isNotEmpty ? tags.join(", ") : "No tags";

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _fetchprofilePic(data['business_name']),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  data['imageUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.image, size: 100),
                ),
              )
            else
              SizedBox.shrink(),
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
                          _toggleLike(post.id, likes);
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
                        .doc(post.id)
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
                              _showCommentsBottomSheet(context, post.id);
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
      ),
    );
  }

  Future<String> _fetchUsername(String userId) async {
    try {
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('rep')
          .where('email', isEqualTo: userId)
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

  Future<String> _fetchprofilePic(String userId) async {
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
          .where('email', isEqualTo: _auth.currentUser?.email)
          .get();

      if (userQuery.docs.isNotEmpty) {
        return userQuery.docs.first.data()['profilePic'] ?? 'Unknown';
      }
    } catch (e) {
      print('Error fetching profile picture: $e');
    }

    return 'Not found';
  }
}
