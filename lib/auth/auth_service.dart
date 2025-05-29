import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  final _firestore = FirebaseFirestore.instance;

  Future<void> sendEmailVerificationLink() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> sendPasswordResetLink(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print(e.toString());
    }
  }

  // Future<User?> createUserWithEmailAndPassword(
  //   String email,
  //   String password,
  // ) async {
  //   try {
  //     final cred = await _auth.createUserWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );
  //     return cred.user;
  //   } on FirebaseAuthException catch (e) {
  //     exceptionHandler(e.code);
  //   } catch (e) {
  //     log("Something went wrong with creating user");
  //   }
  //   return null;
  // }

  Future<String?> createUserWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      //create user with email and password in firebase auth
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      // Save additional user data to Firestore
      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': role, //role determines if the user is a student or teacher
      });
      return null; // Return null if successful
    } catch (e) {
      return e.toString(); // Return error message if something goes wrong
    }
  }

  // Future<User?> loginUserWithEmailAndPassword(
  //   String email,
  //   String password,
  // ) async {
  //   try {
  //     final cred = await _auth.signInWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );
  //     return cred.user;
  //   } on FirebaseAuthException catch (e) {
  //     exceptionHandler(e.code);
  //   } catch (e) {
  //     log("Something went wrong with logging in");
  //   }
  //   return null;
  // }

  Future<String?> loginUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      //sign in user with email and password in firebase auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Fetching the user role from Firestore
      DocumentSnapshot userDoc =
          await _firestore
              .collection("users")
              .doc(userCredential.user!.uid)
              .get();
      return userDoc['role']; // Return the user's role
    } on FirebaseAuthException catch (e) {
      return exceptionHandler(e.code);
    } catch (e) {
      return e.toString(); // Return error message if something goes wrong
    }
  }

  Future<void> signout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      log("Something went wrong with signing out");
    }
  }
}

exceptionHandler(String code) {
  switch (code) {
    case "invalid-credential":
      // log("Invalid login Credentials");
      return "Invalid login Credentials";
    case "weak-password":
      // log("Your password must be at least 8 characters long");
      return "Your password must be at least 8 characters long";
    case "email-already-in-use":
      // log("User already exists");
      return "User already exists";
    default:
      // log("Something went wrong");
      return "Something went wrong";
  }
}
