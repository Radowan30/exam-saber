import 'package:exam_saber/auth/auth_service.dart';
import 'package:exam_saber/auth/login_screen.dart';
import 'package:exam_saber/widgets/button.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exam_saber/student_answer.dart';
import 'package:exam_saber/past_quizes.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedSubject = 'All';
  List<String> _availableSubjects = ['All'];
  bool _showFilter = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadAvailableSubjects() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('quizzes').get();

      Set<String> subjects = {'All'};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['subject'] != null) {
          subjects.add(data['subject'].toString());
        }
      }

      setState(() {
        _availableSubjects = subjects.toList()..sort();
      });
    } catch (e) {
      print('Error loading subjects: $e');
    }
  }

  Stream<QuerySnapshot> _getQuizzesStream() {
    return FirebaseFirestore.instance
        .collection('quizzes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _getAnswersStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('answers')
        .where('studentId', isEqualTo: currentUser.uid)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterQuizzes(
    List<QueryDocumentSnapshot> quizzes,
    Set<String> attemptedQuizIds,
  ) {
    return quizzes.where((quiz) {
      final data = quiz.data() as Map<String, dynamic>;
      final quizId = data['quizId']?.toString() ?? '';
      final title = data['title']?.toString().toLowerCase() ?? '';
      final subject = data['subject']?.toString() ?? '';

      // Filter out attempted quizzes
      if (attemptedQuizIds.contains(quizId)) {
        return false;
      }

      // Apply search filter
      bool matchesSearch =
          _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          quizId.toLowerCase().contains(_searchQuery.toLowerCase());

      // Apply subject filter
      bool matchesSubject =
          _selectedSubject == 'All' || subject == _selectedSubject;

      return matchesSearch && matchesSubject;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[900],
      drawer: _buildDrawer(context, auth),
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          CircleAvatar(backgroundColor: Colors.grey[700], radius: 18),
          const SizedBox(width: 15),
        ],
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/SABER-Logo.png', height: 40, width: 40),
            const SizedBox(width: 8),
            const Text(
              "EXAM",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const Text(
              "SABER",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              "Hello, Student",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
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
                },
                decoration: InputDecoration(
                  hintText: "Search by quiz name or ID",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: _showFilter ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFilter = !_showFilter;
                      });
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),

            // Filter Options
            if (_showFilter) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Filter by Subject:",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _availableSubjects.map((subject) {
                            bool isSelected = _selectedSubject == subject;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedSubject = subject;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Colors.blue
                                          : Colors.grey[700],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  subject,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Available Quizzes
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getAnswersStream(),
                builder: (context, answersSnapshot) {
                  Set<String> attemptedQuizIds = {};

                  if (answersSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !answersSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (answersSnapshot.hasData) {
                    for (var doc in answersSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['quizId'] != null) {
                        attemptedQuizIds.add(data['quizId'].toString());
                      }
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _getQuizzesStream(),
                    builder: (context, quizzesSnapshot) {
                      if (quizzesSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      if (quizzesSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${quizzesSnapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (!quizzesSnapshot.hasData ||
                          quizzesSnapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No quizzes available',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        );
                      }

                      final filteredQuizzes = _filterQuizzes(
                        quizzesSnapshot.data!.docs,
                        attemptedQuizIds,
                      );

                      if (filteredQuizzes.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedSubject != 'All'
                                    ? 'No quizzes match your search criteria'
                                    : 'No unattempted quizzes available',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Available Quizzes (${filteredQuizzes.length})",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredQuizzes.length,
                              itemBuilder: (context, index) {
                                final quiz = filteredQuizzes[index];
                                final quizData =
                                    quiz.data() as Map<String, dynamic>;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildQuizCard(
                                    title:
                                        quizData['title']?.toString() ??
                                        'Untitled Quiz',
                                    subject:
                                        quizData['subject']?.toString() ??
                                        'No Subject',
                                    questions:
                                        (quizData['questions'] as List?)
                                            ?.length ??
                                        0,
                                    duration:
                                        "${quizData['timeLimit'] ?? 0} min",
                                    quizId:
                                        quizData['quizId']?.toString() ?? '',
                                    onTap: () {
                                      _showQuizDetails(
                                        context,
                                        quizData,
                                        quiz.id,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Continue Quiz Section (placeholder for now)
            _buildContinueQuizSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard({
    required String title,
    required String subject,
    required int questions,
    required String duration,
    required String quizId,
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
            Row(
              children: [
                Expanded(
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
                      if (quizId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Quiz ID: $quizId",
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[500],
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.format_list_bulleted,
                  color: Colors.grey[400],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  "$questions Questions",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, color: Colors.grey[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueQuizSection() {
    // This is a placeholder for the continue quiz functionality
    // Will be implemented later when quiz attempt functionality is added
    return const SizedBox.shrink();
  }

  void _showQuizDetails(
    BuildContext context,
    Map<String, dynamic> quizData,
    String docId,
  ) {
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
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text(
                              "Quiz Details",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Quiz Title and Subject
                        Text(
                          quizData['title']?.toString() ?? 'Untitled Quiz',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Subject: ${quizData['subject']?.toString() ?? 'No Subject'}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),

                        if (quizData['quizId'] != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              "Quiz ID: ${quizData['quizId']}",
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 4,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 20),

                        // Quiz Information
                        const Text(
                          "Quiz Information",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildQuizInfoItem(
                          Icons.format_list_bulleted,
                          "${(quizData['questions'] as List?)?.length ?? 0} Questions",
                          "Total questions in this quiz",
                        ),
                        const SizedBox(height: 12),

                        _buildQuizInfoItem(
                          Icons.access_time,
                          "${quizData['timeLimit'] ?? 0} minutes",
                          "Time limit for completing the quiz",
                        ),
                        const SizedBox(height: 12),

                        _buildQuizInfoItem(
                          Icons.assignment,
                          "Open-ended format",
                          "Type all answers in a single text field",
                        ),

                        const SizedBox(height: 24),

                        // Quiz Rules
                        const Text(
                          "Instructions",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildQuizRule(
                                "Read all questions carefully before starting",
                              ),
                              const SizedBox(height: 8),
                              _buildQuizRule(
                                "Type all your answers in the provided text field",
                              ),
                              const SizedBox(height: 8),
                              _buildQuizRule(
                                "You can review and edit your answers during the time limit",
                              ),
                              const SizedBox(height: 8),
                              _buildQuizRule(
                                "The quiz will auto-submit when time runs out",
                              ),
                              const SizedBox(height: 8),
                              _buildQuizRule(
                                "Make sure you have a stable internet connection",
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Start Quiz Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _startQuiz(context, quizData, docId);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Start Quiz",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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

  void _startQuiz(
    BuildContext context,
    Map<String, dynamic> quizData,
    String docId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                StudentAnswerScreen(quizData: quizData, quizDocId: docId),
      ),
    );
  }

  Widget _buildQuizInfoItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.black),
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

  Widget _buildQuizRule(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("• ", style: TextStyle(fontSize: 14)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, AuthService auth) {
    return Drawer(
      child: Container(
        color: Colors.grey[900],
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              color: Colors.grey[850],
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/SABER-Logo.png',
                        height: 50,
                        width: 50,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "EXAM",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const Text(
                        "SABER",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.grey),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: "Past Quizzes",
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to Past Quizzes screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PastQuizzesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.lightbulb,
                    title: "AI Explanations",
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to AI Explanations screen
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: "Settings",
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to Settings screen
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: "Sign Out",
                      onPressed: () async {
                        await auth.signout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom > 0
                            ? MediaQuery.of(context).padding.bottom
                            : 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: onTap,
      hoverColor: Colors.grey[800],
      textColor: Colors.white,
      iconColor: Colors.white,
    );
  }
}
