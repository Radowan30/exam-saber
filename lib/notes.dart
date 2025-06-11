import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotesScreen extends StatefulWidget {
  final String quizId;

  const NotesScreen({super.key, required this.quizId});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _notesController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isDirty = false; // Tracks if the text has been changed
  String _initialNoteContent = '';
  String? _noteDocId; // To store the document ID of an existing note
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _studentId = _auth.currentUser?.uid;
    if (_studentId != null) {
      _loadNote();
    } else {
      // Handle case where user is not logged in
      setState(() {
        _isLoading = false;
      });
      // Optionally, pop the screen or show an error
    }
    _notesController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _notesController.removeListener(_onTextChanged);
    _notesController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_notesController.text != _initialNoteContent) {
      if (!_isDirty) {
        setState(() {
          _isDirty = true;
        });
      }
    } else {
      if (_isDirty) {
        setState(() {
          _isDirty = false;
        });
      }
    }
  }

  Future<void> _loadNote() async {
    try {
      final querySnapshot =
          await _firestore
              .collection('notes')
              .where('quizId', isEqualTo: widget.quizId)
              .where('studentId', isEqualTo: _studentId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final noteDoc = querySnapshot.docs.first;
        final noteData = noteDoc.data();
        _noteDocId = noteDoc.id;
        _initialNoteContent = noteData['content'] ?? '';
        _notesController.text = _initialNoteContent;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading note: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNote() async {
    if (!_isDirty || _studentId == null) return;

    setState(() {
      _isLoading = true;
    });

    final noteContent = _notesController.text;
    final noteData = {
      'quizId': widget.quizId,
      'studentId': _studentId,
      'content': noteContent,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_noteDocId != null) {
        // Update existing note
        await _firestore.collection('notes').doc(_noteDocId).update(noteData);
      } else {
        // Create new note
        final newDocRef = await _firestore.collection('notes').add(noteData);
        _noteDocId = newDocRef.id;
      }

      setState(() {
        _initialNoteContent = noteContent;
        _isDirty = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote() async {
    if (_noteDocId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No note to delete.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Note?'),
            content: const Text(
              'Are you sure you want to permanently delete this note?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('notes').doc(_noteDocId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted.'),
            backgroundColor: Colors.red,
          ),
        );
        // Navigate back to the previous screen
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting note: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _noteDocId == null ? null : _deleteNote,
            tooltip: 'Delete Note',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _notesController,
                    maxLines:
                        null, // Allows the text field to expand vertically
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      hintText: 'Write your notes about this quiz here...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isDirty ? _saveNote : null, // Disabled if no changes
          style: ElevatedButton.styleFrom(
            backgroundColor: _isDirty ? Colors.blue : Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: const Text('Save'),
        ),
      ),
    );
  }
}
