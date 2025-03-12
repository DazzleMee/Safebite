import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safebite/components/constants.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:safebite/components/rounded_button.dart';
import 'package:safebite/entry/changcred.dart';
import 'package:safebite/entry/feedpage.dart';
import 'package:safebite/entry/welcome.dart';
import 'package:firebase_storage/firebase_storage.dart';

class RegisterScreen extends StatefulWidget {
  static const String id = "register_screen";
  // const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool showSpinner = false;
  String email = "";
  String password = "";
  String cfmpassword = "";
  String username = "";
  String errorMessage = "";

  void handleAuthError(FirebaseAuthException e) {
    setState(() {
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email.';
      } else if (e.message != null &&
          e.message!.contains(
              'The supplied auth credential is incorrect, malformed or has expired')) {
        errorMessage = 'Incorrect Credentials.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      } else {
        errorMessage = e.message ?? 'An unknown error occurred.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 200,
                child: Image.asset('images/logo.png'),
              ),
              SizedBox(
                height: 48,
              ),
              TextField(
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    email = value;
                  });
                },
                decoration:
                    kTextFieldDecoration.copyWith(hintText: "Enter Your Email"),
              ),
              SizedBox(height: 8),
              TextField(
                obscureText: true,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    password = value;
                  });
                },
                decoration:
                    kTextFieldDecoration.copyWith(hintText: "Create Password"),
              ),
              SizedBox(height: 8),
              TextField(
                obscureText: true,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    cfmpassword = value;
                  });
                },
                decoration: kTextFieldDecoration.copyWith(
                    hintText: "Re-Enter password"),
              ),
              SizedBox(height: 8),
              TextField(
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    username = value;
                  });
                },
                decoration:
                    kTextFieldDecoration.copyWith(hintText: "Create Username"),
              ),
              SizedBox(height: 8),
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              RoundedButton(
                  title: "Register",
                  onPressed: () async {
                    setState(() {
                      showSpinner = true;
                    });
                    try {
                      if (password == cfmpassword) {
                        final newUser =
                            await _auth.createUserWithEmailAndPassword(
                          email: email,
                          password: password,
                        );

                        if (newUser != null) {
                          print("Success");
                          await _firestore
                              .collection('users')
                              .doc(newUser.user!.uid)
                              .set({
                            'email': email,
                            'username': username,
                          });
                          print("Success");
                          Navigator.popAndPushNamed(context, Allergenpicker.id);
                        }
                      } else if (password != cfmpassword) {
                        setState(() {
                          errorMessage = "Passwords not matched";
                          showSpinner = false;
                        });
                        return;
                      }

                      setState(() {
                        showSpinner = false;
                      });
                    } on FirebaseAuthException catch (e) {
                      handleAuthError(e);
                    } catch (e) {
                      print(e);
                      setState(() {
                        showSpinner = false;
                        errorMessage = "An error occurred. Please try again.";
                      });
                    }
                  }),
              SizedBox(
                height: 20,
              ),
              GestureDetector(
                onTap: () {
                  Navigator.popAndPushNamed(context, WelcomeScreen.id);
                },
                child: Text(
                  "Don't Have an Account?",
                  style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
