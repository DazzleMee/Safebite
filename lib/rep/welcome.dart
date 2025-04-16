import 'package:flutter/material.dart';
import 'package:safebite/rep/register.dart';
import 'package:safebite/rep/replogin.dart';
import 'package:safebite/components/rounded_button.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BusinessAccountScreen(),
    );
  }
}

class BusinessAccountScreen extends StatelessWidget {
  static const String id = "rep_welcome";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 60),

              // Logo
              Image.asset(
                'images/logo.png',
                width: 220,
              ),

              const SizedBox(height: 20),

              // Title
              const Text(
                "Business Account",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              // const Spacer(),

              // Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RoundedButton(
                            title: "Get Started",
                            onPressed: () {
                              Navigator.pushNamed(
                                  context, RegisterBusinessScreen.id);
                            }),
                        const SizedBox(height: 15),
                        RoundedButton(
                            title: "Login ",
                            onPressed: () {
                              Navigator.pushNamed(context, RepLoginScreen.id);
                            }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
}
