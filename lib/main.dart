import 'package:flutter/material.dart';
import 'package:safebite/entry/changcred.dart';
import 'package:safebite/entry/barcode.dart';
import 'package:safebite/entry/profilescreen.dart';
import 'package:safebite/entry/maps.dart';
import 'package:safebite/entry/useraccountsearched.dart';
import 'package:safebite/entry/usersearch.dart';
import 'package:safebite/rep/addpost.dart';
import 'package:safebite/rep/notapproved.dart';
import 'package:safebite/rep/notifications.dart';
import 'package:safebite/rep/repaccountsearched.dart';
import 'package:safebite/rep/repfeedpage.dart';
import 'package:safebite/rep/replogin.dart';
import 'package:safebite/rep/repprofile.dart';
import 'package:safebite/rep/repsearchaccounts.dart';
import './entry/login.dart';
import './entry/welcome.dart';
import './entry/register.dart';
import 'package:firebase_core/firebase_core.dart';
import 'entry/feedpage.dart';
import 'entry/changecreds.dart';
import 'entry/maps.dart';
import 'entry/changcred.dart';
// import './components/NavBar.dart';
import 'rep/welcome.dart';
import 'rep/register.dart';
import 'rep/repcreds.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Color(0xFFD9D9D9),
          //primaryColor: Colors.deepOrange,
          textTheme: TextTheme(bodyMedium: TextStyle(color: Colors.white))),
      initialRoute: BusinessAccountScreen.id,
      routes: {
        WelcomeScreen.id: (context) => WelcomeScreen(),
        LoginScreen.id: (context) => LoginScreen(),
        RegisterScreen.id: (context) => RegisterScreen(),
        Allergenpicker.id: (context) => Allergenpicker(),
        FeedPage.id: (context) => FeedPage(),
        Barcode.id: (context) => Barcode(),
        GoogleMapsScreen.id: (context) => GoogleMapsScreen(),
        ChangeCreds.id: (context) => ChangeCreds(),
        ProfilePage.id: (context) => ProfilePage(),
        BusinessAccountScreen.id: (context) => BusinessAccountScreen(),
        RegisterBusinessScreen.id: (context) => RegisterBusinessScreen(),
        ProfileUpdateScreen.id: (context) => ProfileUpdateScreen(),
        RepFeedPage.id: (context) => RepFeedPage(),
        RepLoginScreen.id: (context) => RepLoginScreen(),
        RepProfileScreen.id: (context) => RepProfileScreen(),
        AddPostScreen.id: (context) => AddPostScreen(),
        NotificationsPage.id: (context) => NotificationsPage(),
        RepSearchPage.id: (context) => RepSearchPage(),
        RepAccountSearched.id: (context) => RepAccountSearched(
              businessAccountEmail: '',
            ),
        UserSearchPage.id: (context) => UserSearchPage(),
        UserAccountSearched.id: (context) =>
            UserAccountSearched(businessAccountEmail: ''),
        RepWaitingApproval.id: (context) => RepWaitingApproval(),
      },
    );
  }
}
