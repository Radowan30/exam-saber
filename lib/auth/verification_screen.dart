import 'dart:async';

import 'package:exam_saber/auth/auth_service.dart';
import 'package:exam_saber/widgets/button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:exam_saber/wrapper.dart';

class VerificationScreen extends StatefulWidget {
  final User user;

  const VerificationScreen({required this.user, super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _auth = AuthService();
  late Timer timer;
  @override
  void initState() {
    super.initState();
    _auth.sendEmailVerificationLink();
    timer = Timer.periodic(Duration(seconds: 5), (timer) {
      FirebaseAuth.instance.currentUser?.reload();
      if (FirebaseAuth.instance.currentUser!.emailVerified == true) {
        timer.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Wrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "We have sent you a verification email",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: "Resend Email",
                onPressed: () async {
                  _auth.sendEmailVerificationLink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
