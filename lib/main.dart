import 'package:flutter/material.dart';
import 'package:safebite/entry/changcred.dart';
import 'package:safebite/entry/barcode.dart';
import 'package:safebite/entry/profilescreen.dart';
import 'package:safebite/entry/maps.dart';
import './entry/login.dart';
import './entry/welcome.dart';
import './entry/register.dart';
import 'package:firebase_core/firebase_core.dart';
import 'entry/feedpage.dart';
import 'entry/changecreds.dart';
import 'entry/maps.dart';
import 'entry/changcred.dart';
// import './components/NavBar.dart';

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensures that Firebase is initialized before the app starts.
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Color(0xFFD9D9D9),
          //primaryColor: Colors.deepOrange,
          textTheme: TextTheme(bodyMedium: TextStyle(color: Colors.white))),
      initialRoute: WelcomeScreen.id,
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
      },
    );
  }
}
