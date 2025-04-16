import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safebite/components/repbar.dart';
import 'package:safebite/rep/repaccountsearched.dart';

class RepSearchPage extends StatefulWidget {
  static const String id = 'rep_search_accounts';

  @override
  _RepSearchPageState createState() => _RepSearchPageState();
}

class _RepSearchPageState extends State<RepSearchPage> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];

  void searchAccounts(String query) async {
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('rep')
        .where('business_name', isGreaterThanOrEqualTo: query)
        .where('business_name', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    setState(() {
      searchResults = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: Repbar(selectedIndex: 2),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Center(
            child:
                Text('Search Accounts', style: TextStyle(color: Colors.white))),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: searchAccounts,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Search accounts',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.white),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                var user = searchResults[index];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    title: Text(user['business_name'],
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(user['email'] ?? 'No email',
                        style: TextStyle(color: Colors.white70)),
                    leading: CircleAvatar(
                      backgroundImage: user['profilePic'] != null
                          ? NetworkImage(user['profilePic'])
                          : null,
                      child: user['profilePic'] == null
                          ? Icon(Icons.person, color: Colors.white)
                          : null,
                      backgroundColor: Colors.grey[700],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RepAccountSearched(
                              businessAccountEmail: user['email']),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
