import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safebite/components/NavBar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedPage extends StatefulWidget {
  static const String id = 'feed_page';

  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userEmail = "";
  String? currentUsername = "";
  TextEditingController commentController = TextEditingController();
  List<String> followedAccounts = [];
  bool showFollowing = false;
  List<String> userAllergens = [];
  String selectedFeed = "Following";

  void initState() {
    super.initState();
    User? user = _auth.currentUser;
    if (user != null) {
      userEmail = user.email;
      _fetchUsername(userEmail!).then((username) {
        setState(() {
          currentUsername = username;
        });
        _fetchFollowedAccounts();
        _fetchUserAllergens();
      });
    }
  }

  void _addComment(String postId, String comment) {
    if (comment.isEmpty) return;

    FirebaseFirestore.instance.collection('posts').doc(postId).update({
      "comments": FieldValue.arrayUnion([
        {"user": currentUsername, "com": comment, "timestamp": Timestamp.now()}
      ])
    });
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

  Stream<QuerySnapshot> _getRecommendedPosts() {
    if (userAllergens.isEmpty) {
      return FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('posts')
          .where('tags', arrayContainsAny: userAllergens)
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  Stream<QuerySnapshot> _getFollowingPosts() {
    if (followedAccounts.isEmpty) {
      return Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('posts')
        .where('business_name', whereIn: followedAccounts)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _toggleFeed(String feedType) {
    setState(() {
      selectedFeed = feedType;
    });
  }

  Future<void> _fetchFollowedAccounts() async {
    if (userEmail == null || currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("rep")
          .where("followers", arrayContains: currentUser!.uid)
          .get();

      List<String> tempFollowedAccounts = [];

      for (var doc in querySnapshot.docs) {
        String? businessName = doc.data()['business_name'];

        if (businessName != null) {
          tempFollowedAccounts.add(businessName);
        }
      }

      setState(() {
        followedAccounts = tempFollowedAccounts;
        print("Followed Accounts: $followedAccounts");
      });
    } catch (e) {
      print("Error fetching followed accounts: $e");
    }
  }

  Future<void> _toggleFollow(String accountToFollow) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection("rep")
        .where('business_name', isEqualTo: accountToFollow)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final docRef = querySnapshot.docs.first.reference;
    List<dynamic> followers =
        querySnapshot.docs.first.data()['followers'] ?? [];

    if (followers.contains(currentUser!.uid)) {
      await docRef.update({
        "followers": FieldValue.arrayRemove([currentUser!.uid])
      });
      setState(() {
        followedAccounts.remove(accountToFollow);
      });
    } else {
      await docRef.update({
        "followers": FieldValue.arrayUnion([currentUser!.uid])
      });
      setState(() {
        followedAccounts.add(accountToFollow);
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

  Future<String> _fetchprofilePic(String userId) async {
    try {
      final userQuerySnapshot = await FirebaseFirestore.instance
          .collection('rep')
          .where('email', isEqualTo: userId)
          .get();

      if (userQuerySnapshot.docs.isNotEmpty) {
        final userData = userQuerySnapshot.docs.first.data();
        return userData['profilePic'] ?? 'Unknown';
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
    return 'Not found';
  }

  Widget _buildPostCard(DocumentSnapshot post) {
    final data = post.data() as Map<String, dynamic>?;

    if (data == null) return SizedBox.shrink();

    String postOwner = data['business_name'] ?? 'Unknown';
    String postTitle = data['title'] ?? 'No Title';
    String postContent = data['content'] ?? 'No Content';
    List<dynamic> likes = data["likes"] ?? [];
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
              future: _fetchprofilePic(data['email']),
              builder: (context, snapshot) {
                final profilePicUrl = snapshot.data ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    radius: 15,
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
                      Text(tagText, style: TextStyle(color: Colors.grey[600])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _toggleFollow(postOwner),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isFollowing ? Colors.grey : Colors.blue,
                        ),
                        child: Text(isFollowing ? "Unfollow" : "Follow"),
                      ),
                      SizedBox(width: 8),
                      // Report (Flag) Button
                      IconButton(
                        icon: Icon(Icons.flag, color: Colors.red),
                        onPressed: () {
                          _showReportDialog(context, post.id);
                        },
                      ),
                    ],
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
                      SizedBox(width: 50),
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
                  SizedBox(width: 50),
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
                  SizedBox(width: 50),
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

// Report Dialog Function
  void _showReportDialog(BuildContext context, String postId) {
    List<String> reportTypes = [
      "Spam",
      "Misinformation",
      "Harassment",
      "Hate Speech",
      "Other"
    ];
    String? selectedReport;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Report Post"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reportTypes.map((type) {
              return RadioListTile<String>(
                title: Text(type),
                value: type,
                groupValue: selectedReport,
                onChanged: (value) {
                  selectedReport = value;
                  Navigator.of(context).pop();
                  _submitReport(postId, selectedReport!);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

// Function to Handle Report Submission
  void _submitReport(String postId, String reportType) async {
    final reportRef =
        FirebaseFirestore.instance.collection('reports').doc(postId);

    final doc = await reportRef.get();

    if (doc.exists) {
      // Document exists, add report to array
      await reportRef.update({
        'reports': FieldValue.arrayUnion([
          {
            'reportType': reportType,
            'reportedAt': Timestamp.now(),
          }
        ]),
      });
    } else {
      // Document does not exist, create a new document with an array
      await reportRef.set({
        'reports': [
          {
            'reportType': reportType,
            'reportedAt': Timestamp.now(),
          }
        ],
      });
    }

    print("Report submitted: $reportType for post ID $postId");
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

  void _toggleLike(String postId, List<dynamic> likes) async {
    final postRef = FirebaseFirestore.instance.collection("posts").doc(postId);

    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: currentUser!.email)
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
        title: selectedFeed == "Following"
            ? Text('Following Posts', style: TextStyle(color: Colors.white))
            : Text('Recommended Posts', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          PopupMenuButton<int>(
            icon: Icon(Icons.swap_horiz, color: Colors.white),
            color: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 1) {
                _toggleFeed("Following");
              } else {
                _toggleFeed("Recommended");
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    Icon(Icons.groups, color: Colors.white),
                    // SizedBox(width: 8),
                    Text('Following', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(Icons.thumb_up, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Recommended', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavBar(selectedIndex: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: selectedFeed == "Following"
            ? _getFollowingPosts()
            : _getRecommendedPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No posts available"));
          }

          var posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return _buildPostCard(posts[index]);
            },
          );
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
