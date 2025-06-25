import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exam_saber/notes.dart';
import 'package:exam_saber/ai_explanations.dart';

class PastQuizzesScreen extends StatefulWidget {
  const PastQuizzesScreen({super.key});

  @override
  State<PastQuizzesScreen> createState() => _PastQuizzesScreenState();
}

class _PastQuizzesScreenState extends State<PastQuizzesScreen> {
  final TextEditingController _searchController = TextEditingController();

  // State variables for combined data, search, and filtering
  List<Map<String, dynamic>> _pastQuizzes = [];
  List<Map<String, dynamic>> _filteredQuizzes = [];
  String _searchQuery = '';
  String _selectedSubject = 'All';
  List<String> _availableSubjects = ['All'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPastQuizzes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPastQuizzes() async {
    setState(() {
      _isLoading = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch all answers for the current student
      final answersSnapshot =
          await FirebaseFirestore.instance
              .collection('answers')
              .where('studentId', isEqualTo: currentUser.uid)
              .get();

      if (answersSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _pastQuizzes = [];
          _filteredQuizzes = [];
        });
        return;
      }

      // Map answers by quizId for easy lookup
      final Map<String, QueryDocumentSnapshot> studentAnswers = {
        for (var doc in answersSnapshot.docs) doc.data()['quizId']: doc,
      };

      final List<String> attemptedQuizIds = studentAnswers.keys.toList();

      if (attemptedQuizIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _pastQuizzes = [];
          _filteredQuizzes = [];
        });
        return;
      }

      // 2. Fetch all corresponding quizzes using 'whereIn'
      final quizzesSnapshot =
          await FirebaseFirestore.instance
              .collection('quizzes')
              .where('quizId', whereIn: attemptedQuizIds)
              .get();

      final Set<String> subjects = {'All'};
      final List<Map<String, dynamic>> combinedData = [];

      for (var quizDoc in quizzesSnapshot.docs) {
        final quizData = quizDoc.data();
        final quizId = quizData['quizId'];

        if (studentAnswers.containsKey(quizId)) {
          final answerDoc = studentAnswers[quizId]!;
          final answerData = answerDoc.data() as Map<String, dynamic>;

          combinedData.add({
            'quizData': quizData,
            'answerData': answerData,
            'quizDocId': quizDoc.id,
          });

          if (quizData['subject'] != null) {
            subjects.add(quizData['subject']);
          }
        }
      }

      // Sort quizzes by submission time (most recent first)
      combinedData.sort((a, b) {
        Timestamp timeA = a['answerData']['submittedAt'] ?? Timestamp.now();
        Timestamp timeB = b['answerData']['submittedAt'] ?? Timestamp.now();
        return timeB.compareTo(timeA);
      });

      setState(() {
        _pastQuizzes = combinedData;
        _filteredQuizzes = combinedData;
        _availableSubjects = subjects.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading past quizzes: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading past quizzes: $e')));
    }
  }

  void _filterAndSearchQuizzes() {
    List<Map<String, dynamic>> tempQuizzes = _pastQuizzes;

    // Filter by subject
    if (_selectedSubject != 'All') {
      tempQuizzes =
          tempQuizzes.where((data) {
            final quizData = data['quizData'] as Map<String, dynamic>;
            return quizData['subject'] == _selectedSubject;
          }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      tempQuizzes =
          tempQuizzes.where((data) {
            final quizData = data['quizData'] as Map<String, dynamic>;
            final title = quizData['title']?.toString().toLowerCase() ?? '';
            final quizId = quizData['quizId']?.toString().toLowerCase() ?? '';
            return title.contains(_searchQuery.toLowerCase()) ||
                quizId.contains(_searchQuery.toLowerCase());
          }).toList();
    }

    setState(() {
      _filteredQuizzes = tempQuizzes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Past Quizzes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _filterAndSearchQuizzes();
                },
                decoration: InputDecoration(
                  hintText: "Search by quiz name or ID",
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filter by Subject
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableSubjects.length,
                itemBuilder: (context, index) {
                  final subject = _availableSubjects[index];
                  bool isSelected = _selectedSubject == subject;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSubject = subject;
                      });
                      _filterAndSearchQuizzes();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          subject,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Quizzes List
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                      : _filteredQuizzes.isEmpty
                      ? Center(
                        child: Text(
                          _pastQuizzes.isEmpty
                              ? "You haven't attempted any quizzes yet."
                              : "No quizzes match your search criteria.",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : ListView.builder(
                        itemCount: _filteredQuizzes.length,
                        itemBuilder: (context, index) {
                          final data = _filteredQuizzes[index];
                          final quizData =
                              data['quizData'] as Map<String, dynamic>;
                          final answerData =
                              data['answerData'] as Map<String, dynamic>;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildQuizCard(
                              title: quizData['title'] ?? 'Untitled Quiz',
                              subject: quizData['subject'] ?? 'No Subject',
                              score: answerData['score'],
                              onTap: () => _showQuizDetails(context, data),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard({
    required String title,
    required String subject,
    required int? score,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              "Subject: $subject",
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Your Score: ${score ?? 'Not Graded'}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuizDetails(
    BuildContext context,
    Map<String, dynamic> combinedData,
  ) {
    final quizData = combinedData['quizData'] as Map<String, dynamic>;
    final answerData = combinedData['answerData'] as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (_, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Text(
                          quizData['title'] ?? 'Untitled Quiz',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Subject: ${quizData['subject'] ?? 'No Subject'}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 4,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 20),

                        // Result Information
                        const Text(
                          "Your Result",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildQuizInfoItem(
                          Icons.star,
                          "Score: ${answerData['score'] ?? 'Not Graded'}",
                          "Your grade for this quiz.",
                          Colors.amber,
                        ),
                        const SizedBox(height: 12),
                        _buildQuizInfoItem(
                          Icons.timer,
                          "Time Spent: ${answerData['timeSpent'] ?? 'N/A'} seconds",
                          "How long you took to complete the quiz.",
                          Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildQuizInfoItem(
                          Icons.calendar_today,
                          "Submitted: ${((answerData['submittedAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? 'N/A')}",
                          "The date and time you submitted your answers.",
                          Colors.green,
                        ),
                        const SizedBox(height: 30),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.lightbulb_outline,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Get AI Explanation",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AIExplanationsScreen(
                                        quizId: quizData['quizId'],
                                        studentId:
                                            FirebaseAuth
                                                .instance
                                                .currentUser!
                                                .uid,
                                      ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.edit_note,
                              color: Colors.black,
                            ),
                            label: const Text(
                              "Write Notes",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              // Pop the modal first
                              Navigator.pop(context);
                              // Then push the new notes screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => NotesScreen(
                                        quizId: quizData['quizId'],
                                      ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildQuizInfoItem(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
