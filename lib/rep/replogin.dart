import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safebite/entry/feedpage.dart';
import 'package:safebite/rep/repcreds.dart';
import 'package:safebite/rep/repfeedpage.dart';
import 'package:safebite/entry/welcome.dart';
import 'package:safebite/rep/welcome.dart';
import '../components/constants.dart';
import '../components/rounded_button.dart';
import 'notapproved.dart';

class RepLoginScreen extends StatefulWidget {
  static const String id = "rep_login_screen";

  @override
  _RepLoginScreenState createState() => _RepLoginScreenState();
}

class _RepLoginScreenState extends State<RepLoginScreen> {
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool showSpinner = false;
  String email = "";
  String password = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            children: [
              SizedBox(height: 120),
              Container(height: 200, child: Image.asset('images/logo.png')),
              SizedBox(height: 90),
              Center(
                child: Text(
                  "Business Safebite Login",
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 50),
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
                decoration: kTextFieldDecoration.copyWith(
                    hintText: "Enter Your Password"),
              ),
              SizedBox(height: 24),
              RoundedButton(
                title: "Login",
                onPressed: () async {
                  setState(() {
                    showSpinner = true;
                  });

                  try {
                    UserCredential userCredential =
                        await _auth.signInWithEmailAndPassword(
                            email: email, password: password);

                    if (userCredential.user != null) {
                      // Fetch user data from Firestore
                      QuerySnapshot querySnapshot = await _firestore
                          .collection("rep")
                          .where("email", isEqualTo: email)
                          .get();

                      if (querySnapshot.docs.isNotEmpty) {
                        Map<String, dynamic> userData = querySnapshot.docs.first
                            .data() as Map<String, dynamic>;

                        String approved = userData['approved'];
                        String accountName = userData['accountName'];

                        print("hi");
                        print("Your account name is: $accountName");
                        print("Your account name is: $approved");
                        print("helo");

                        if (accountName == "") {
                          print("it works?");
                        }

                        if (approved == 'yes' && accountName == "") {
                          Navigator.popAndPushNamed(
                              context, ProfileUpdateScreen.id);
                        } else if (approved == 'no') {
                          Navigator.popAndPushNamed(
                              context, RepWaitingApproval.id);
                        } else {
                          Navigator.popAndPushNamed(context, RepFeedPage.id);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("User data not found.")),
                        );
                      }
                    }
                  } on FirebaseAuthException catch (e) {
                    print(e);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "Login failed. Please check your credentials.")),
                    );
                  } finally {
                    setState(() {
                      showSpinner = false;
                    });
                  }
                },
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, BusinessAccountScreen.id);
                },
                child: Center(
                  child: Text(
                    "Don't Have an Account?",
                    style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
