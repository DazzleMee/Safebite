import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safebite/components/NavBar.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class FeedPage extends StatelessWidget {
  static const String id = 'feed_page';

  @override
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _nicknameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _prfimg;
  String? _imglink;

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Center(
          child: Text(
            'For You Page',
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
      bottomNavigationBar: NavBar(selectedIndex: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').snapshots(),
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

    if (data == null) {
      return SizedBox.shrink();
    }

    print(data['imageUrl']);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _fetchUsername(data['userId']),
              builder: (context, snapshot) {
                final username = snapshot.data ?? 'Unknown';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      username.isNotEmpty
                          ? username[0]
                          : '?', // First letter of username
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    username, // Display the fetched username
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Following'),
                  trailing: Icon(Icons.more_vert),
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
                      Icon(Icons.male, size: 100),
                ),
              )
            else
              SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                data['title'] ?? 'No Title', // Post title from posts collection
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                data['content'] ??
                    'No Content', // Post content from posts collection
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_border, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                          '${data['likes'] ?? 0}'), // Likes from posts collection
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                          '${data['comments'] ?? 0}'), // Comments from posts collection
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.share_outlined, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                          '${data['shares'] ?? 0}'), // Shares from posts collection
                    ],
                  ),
                ],
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
          .collection('users')
          .where('userId', isEqualTo: userId)
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
}
