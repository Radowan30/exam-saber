import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TeacherMarksScreen extends StatefulWidget {
  const TeacherMarksScreen({super.key});

  @override
  State<TeacherMarksScreen> createState() => _TeacherMarksScreenState();
}

class _TeacherMarksScreenState extends State<TeacherMarksScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  String _selectedSubject = 'All';
  List<String> _availableSubjects = ['All'];
  bool _isLoading = true;
  List<Map<String, dynamic>> _quizzesWithAttempts = [];
  List<Map<String, dynamic>> _filteredQuizzes = [];

  @override
  void initState() {
    super.initState();
    _loadQuizzesWithAttempts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizzesWithAttempts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Get all quizzes
      final quizzesSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .orderBy('createdAt', descending: true)
          .get();

      // 2. Get all answers
      final answersSnapshot = await FirebaseFirestore.instance
          .collection('answers')
          .get();

      // 3. Group answers by quizId
      Map<String, List<Map<String, dynamic>>> answersByQuiz = {};
      Set<String> subjects = {'All'};

      for (var answerDoc in answersSnapshot.docs) {
        final answerData = answerDoc.data();
        final quizId = answerData['quizId'];
        
        if (quizId != null) {
          if (!answersByQuiz.containsKey(quizId)) {
            answersByQuiz[quizId] = [];
          }
          answersByQuiz[quizId]!.add(answerData);
        }
      }

      // 4. Combine quiz data with attempt counts
      List<Map<String, dynamic>> quizzesWithAttempts = [];

      for (var quizDoc in quizzesSnapshot.docs) {
        final quizData = quizDoc.data();
        final quizId = quizData['quizId'];
        
        if (quizId != null) {
          final attempts = answersByQuiz[quizId] ?? [];
          
          quizzesWithAttempts.add({
            'quizData': quizData,
            'attempts': attempts,
            'attemptCount': attempts.length,
            'quizDocId': quizDoc.id,
          });

          if (quizData['subject'] != null) {
            subjects.add(quizData['subject']);
          }
        }
      }

      setState(() {
        _quizzesWithAttempts = quizzesWithAttempts;
        _filteredQuizzes = quizzesWithAttempts;
        _availableSubjects = subjects.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading quizzes with attempts: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  void _filterQuizzes() {
    List<Map<String, dynamic>> tempQuizzes = _quizzesWithAttempts;

    // Filter by subject
    if (_selectedSubject != 'All') {
      tempQuizzes = tempQuizzes.where((data) {
        final quizData = data['quizData'] as Map<String, dynamic>;
        return quizData['subject'] == _selectedSubject;
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      tempQuizzes = tempQuizzes.where((data) {
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

  Future<void> _downloadCSV(String quizTitle, List<Map<String, dynamic>> studentsWithMarks) async {
    try {
      // Create CSV data
      List<List<dynamic>> csvData = [];
      
      // Add headers
      csvData.add([
        'Rank',
        'Student Name',
        'Email',
        'Score',
        'Time Spent (seconds)',
        'Submitted At'
      ]);

      // Add student data
      for (int i = 0; i < studentsWithMarks.length; i++) {
        final student = studentsWithMarks[i];
        csvData.add([
          i + 1, // Rank
          student['studentName'] ?? 'Unknown',
          student['studentEmail'] ?? 'No Email',
          student['score'] ?? 'N/A',
          student['timeSpent'] ?? 'N/A',
          student['submittedAt'] != null 
              ? (student['submittedAt'] as Timestamp).toDate().toString()
              : 'N/A'
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = '${quizTitle.replaceAll(RegExp(r'[^\w\s-]'), '')}_marks.csv';
      final file = File('${directory.path}/$fileName');

      // Write CSV to file
      await file.writeAsString(csvString);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Quiz marks for: $quizTitle',
        subject: 'Quiz Marks Export',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV file ready to share!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error creating CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          "Student Marks",
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
                  _filterQuizzes();
                },
                decoration: const InputDecoration(
                  hintText: "Search by quiz name or ID",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
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
                      _filterQuizzes();
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
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _filteredQuizzes.isEmpty
                      ? Center(
                          child: Text(
                            _quizzesWithAttempts.isEmpty
                                ? "No quizzes found."
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
                            final quizData = data['quizData'] as Map<String, dynamic>;
                            final attemptCount = data['attemptCount'] as int;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildQuizCard(
                                title: quizData['title'] ?? 'Untitled Quiz',
                                subject: quizData['subject'] ?? 'No Subject',
                                attemptCount: attemptCount,
                                onTap: () => _showQuizMarks(context, data),
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
    required int attemptCount,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, color: Colors.blue, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "$attemptCount Attempts",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuizMarks(BuildContext context, Map<String, dynamic> data) async {
    final quizData = data['quizData'] as Map<String, dynamic>;
    final attempts = data['attempts'] as List<Map<String, dynamic>>;

    // Get student details for each attempt
    List<Map<String, dynamic>> studentsWithMarks = [];
    
    for (var attempt in attempts) {
      try {
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(attempt['studentId'])
            .get();
        
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>;
          studentsWithMarks.add({
            'studentName': studentData['name'] ?? 'Unknown Student',
            'studentEmail': studentData['email'] ?? 'No Email',
            'score': attempt['score'],
            'timeSpent': attempt['timeSpent'],
            'submittedAt': attempt['submittedAt'],
          });
        }
      } catch (e) {
        print('Error fetching student data: $e');
        studentsWithMarks.add({
          'studentName': 'Unknown Student',
          'studentEmail': 'Error loading email',
          'score': attempt['score'],
          'timeSpent': attempt['timeSpent'],
          'submittedAt': attempt['submittedAt'],
        });
      }
    }

    // Sort by score (highest first)
    studentsWithMarks.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with download button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                        ],
                      ),
                    ),
                    // Download CSV Button
                    ElevatedButton.icon(
                      onPressed: studentsWithMarks.isNotEmpty
                          ? () => _downloadCSV(
                                quizData['title'] ?? 'Untitled Quiz',
                                studentsWithMarks,
                              )
                          : null,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 4,
                  color: Colors.blue,
                ),
                const SizedBox(height: 20),

                // Statistics
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "Total Attempts",
                        "${studentsWithMarks.length}",
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        "Average Score",
                        studentsWithMarks.isNotEmpty
                            ? "${(studentsWithMarks.map((s) => s['score'] ?? 0).reduce((a, b) => a + b) / studentsWithMarks.length).toStringAsFixed(1)}"
                            : "0",
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Student Results
                const Text(
                  "Student Results",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                if (studentsWithMarks.isEmpty)
                  const Center(
                    child: Text(
                      "No attempts yet",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: studentsWithMarks.length,
                    itemBuilder: (context, index) {
                      final student = studentsWithMarks[index];
                      return _buildStudentResultCard(student, index + 1);
                    },
                  ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentResultCard(Map<String, dynamic> student, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: rank <= 3 ? Colors.amber : Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                "$rank",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['studentName'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  student['studentEmail'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (student['submittedAt'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Submitted: ${(student['submittedAt'] as Timestamp).toDate().toString().substring(0, 16)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getScoreColor(student['score']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getScoreColor(student['score'])),
            ),
            child: Text(
              "${student['score'] ?? 'N/A'}",
              style: TextStyle(
                color: _getScoreColor(student['score']),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}