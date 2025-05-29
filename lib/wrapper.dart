import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exam_saber/auth/login_screen.dart';
import 'package:exam_saber/auth/verification_screen.dart';
import 'package:exam_saber/teacher_screen.dart';
import 'package:exam_saber/student_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Wrapper extends StatelessWidget {
  final String? role;

  const Wrapper({super.key, this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("Error"));
          } else {
            if (snapshot.data == null) {
              return const LoginScreen();
            } else {
              if (snapshot.data?.emailVerified == true) {
                // If role is provided (from login), use it directly
                if (role != null) {
                  if (role == "Teacher") {
                    return const TeacherScreen();
                  } else {
                    return const StudentScreen();
                  }
                } else {
                  // If no role provided, fetch from Firestore
                  return FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection("users")
                            .doc(snapshot.data!.uid)
                            .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (userSnapshot.hasError) {
                        return const Center(
                          child: Text("Error fetching user data"),
                        );
                      } else if (userSnapshot.hasData &&
                          userSnapshot.data!.exists) {
                        String userRole = userSnapshot.data!['role'];
                        if (userRole == "Teacher") {
                          return const TeacherScreen();
                        } else {
                          return const StudentScreen();
                        }
                      } else {
                        return const Center(child: Text("User data not found"));
                      }
                    },
                  );
                }
              } else {
                return VerificationScreen(user: snapshot.data!, role: role);
              }
            }
          }
        },
      ),
    );
  }
}
