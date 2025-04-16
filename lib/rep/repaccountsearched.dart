import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safebite/components/repbar.dart';

class RepAccountSearched extends StatefulWidget {
  final String businessAccountEmail;

  RepAccountSearched({required this.businessAccountEmail});

  @override
  static const String id = "rep_account_searched";
  _RepAccountSearchedState createState() => _RepAccountSearchedState();
}

class _RepAccountSearchedState extends State<RepAccountSearched> {
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
  bool _showPosts = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
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

  void _toggleFollow() async {
    if (currentUserUID == null || searchedUID == null) return;

    DocumentReference repRef = _firestore.collection("rep").doc(searchedUID);
    DocumentReference currentUserRef =
        _firestore.collection("rep").doc(currentUserUID);

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
      bottomNavigationBar: Repbar(selectedIndex: 2),
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
                    _buildStatColumn(followers, "Followers"),
                    _buildStatColumn(following, "Following"),
                  ],
                ),
                SizedBox(height: 10),
                !isFollowing
                    ? ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text("Follow"),
                      )
                    : ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text("Unfollow"),
                      ),
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
          Expanded(
            child: _showPosts
                ? StreamBuilder(
                    stream: _firestore
                        .collection("posts")
                        .where("email", isEqualTo: widget.businessAccountEmail)
                        .orderBy("timestamp", descending: true)
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (!snapshot.hasData)
                        return Center(child: CircularProgressIndicator());

                      return ListView(
                        children: snapshot.data!.docs.map((doc) {
                          return _buildPost(doc);
                        }).toList(),
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

  Widget _buildPost(DocumentSnapshot doc) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: profilePicUrl.isNotEmpty
                  ? NetworkImage(profilePicUrl)
                  : AssetImage("images/defaultprofilepic.jpg") as ImageProvider,
            ),
            title: Text(businessName,
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Image.network(doc["imageUrl"], fit: BoxFit.cover),
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
