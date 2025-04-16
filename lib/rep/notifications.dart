import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safebite/components/repbar.dart';

class NotificationsPage extends StatefulWidget {
  static const String id = 'rep_notifications';

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    String userEmail = currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.black, // Dark theme background
      bottomNavigationBar: Repbar(selectedIndex: 1),
      appBar: AppBar(
        title: Center(
            child:
                Text('Notifications', style: TextStyle(color: Colors.white))),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: currentUser == null
          ? Center(
              child: Text(
                "Please log in to see notifications.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: getNotifications(userEmail),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                      child: Text(
                    'No notifications',
                    style: TextStyle(color: Colors.white70),
                  ));
                }

                var notifications = snapshot.data!;

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    var notification = notifications[index];
                    bool isComment = notification['type'] == 'comment';

                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey[900], // Dark gray for contrast
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isComment ? Icons.chat_bubble : Icons.thumb_up,
                          color: Colors.white70,
                        ),
                        title: Text(
                          '${notification['username']} ${notification['message']}',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          timeAgo(notification['timestamp']),
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Stream<List<Map<String, dynamic>>> getNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('email', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      List<Map<String, dynamic>> notifications = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();

        if (data.containsKey('comments')) {
          for (var comment in data['comments']) {
            notifications.add({
              'type': 'comment',
              'username': comment['user'],
              'message': 'commented on your post: ${comment['com']}',
              'timestamp': comment['timestamp'],
            });
          }
        }

        if (data.containsKey('likes')) {
          for (var like in data['likes']) {
            notifications.add({
              'type': 'like',
              'username': like['username'],
              'message': 'liked your post',
              'timestamp': like['timestamp'],
            });
          }
        }
      }

      notifications.sort((a, b) =>
          (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

      return notifications;
    });
  }

  String timeAgo(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);

    if (diff.inSeconds < 60) return '${diff.inSeconds} sec ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }
}
