import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'register.dart';
import '../components/constants.dart';
import '../components/rounded_button.dart';

class WelcomeScreen extends StatefulWidget {
  static const String id = "welcome_screen";
  // const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage('images/mainmenu_screen.png'),
                fit: BoxFit.cover,
                opacity: 0.6)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                        tag: 'logo',
                        child: Container(
                            child: Image.asset(
                          'images/logo.png',
                          width: 200,
                          height: 300,
                        )))
                  ],
                ),
                SizedBox(height: 20),
                RoundedButton(
                    title: "Login",
                    onPressed: () {
                      Navigator.pushNamed(context, LoginScreen.id);
                    }),
                SizedBox(height: 20),
                Material(
                  elevation: 5,
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  child: MaterialButton(
                    onPressed: () {
                      Navigator.pushNamed(context, RegisterScreen.id);
                    },
                    minWidth: 200,
                    height: 42,
                    child: Text(
                      "Sign Up".toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
