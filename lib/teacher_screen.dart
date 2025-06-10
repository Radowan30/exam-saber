import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exam_saber/auth/auth_service.dart';
import 'package:exam_saber/auth/login_screen.dart';
import 'package:exam_saber/widgets/button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showWelcome = true;
  late AnimationController _fabController;
  late AnimationController _backgroundController;
  late AnimationController _profileController;
  late Animation<double> _fabPulseAnimation;
  late Animation<double> _fabRotateAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _profileBounceAnimation;

  @override
  void initState() {
    super.initState();

    // FAB animations
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fabPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeInOut));

    _fabRotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    // Background animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _backgroundAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_backgroundController);

    // Profile animation
    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _profileBounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.elasticOut),
    );

    // Start animations
    _fabController.repeat(reverse: true);
    _profileController.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showWelcome = false);
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _backgroundController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  void _showQuizDialog({DocumentSnapshot? quiz}) {
    showDialog(context: context, builder: (context) => QuizDialog(quiz: quiz));
  }

  Future<void> _deleteQuiz(String quizId) async {
    try {
      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(quizId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Quiz deleted successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error deleting quiz: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(String quizId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete Quiz'),
              ],
            ),
            content: const Text(
              'Are you sure you want to delete this quiz? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteQuiz(quizId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showProfileDialog(int quizCount) {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey[850]!, Colors.grey[900]!],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Avatar with animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.red, Colors.orange],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // User Email
                  Text(
                    user?.email ?? 'No email',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quiz Count with animated counter
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Quizzes Created',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: quizCount),
                          duration: const Duration(milliseconds: 1500),
                          builder: (context, value, child) {
                            return Text(
                              '$value',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Close button
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = FirebaseAuth.instance.currentUser;

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
          // Enhanced Profile Button
          StreamBuilder<QuerySnapshot>(
            stream:
                user != null
                    ? FirebaseFirestore.instance
                        .collection('quizzes')
                        .where('userId', isEqualTo: user.uid)
                        .snapshots()
                    : null,
            builder: (context, snapshot) {
              final quizCount =
                  snapshot.hasData ? snapshot.data!.docs.length : 0;

              return ScaleTransition(
                scale: _profileBounceAnimation,
                child: GestureDetector(
                  onTap: () => _showProfileDialog(quizCount),
                  child: Container(
                    margin: const EdgeInsets.only(right: 15),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated ring
                        AnimatedBuilder(
                          animation: _backgroundAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.red.withOpacity(
                                    0.3 +
                                        0.3 *
                                            math.sin(
                                              _backgroundAnimation.value,
                                            ),
                                  ),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                        // Profile avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.red, Colors.orange],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        // Quiz count badge
                        if (quizCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$quizCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
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
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[900]!,
                      Color.lerp(
                        Colors.grey[850]!,
                        Colors.grey[800]!,
                        (math.sin(_backgroundAnimation.value * 3) + 1) / 2,
                      )!,
                      Color.lerp(
                        Colors.grey[900]!,
                        Colors.grey[850]!,
                        (math.cos(_backgroundAnimation.value * 2) + 1) / 2,
                      )!,
                      Colors.grey[900]!,
                    ],
                    stops: [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    // Floating particles
                    for (int i = 0; i < 5; i++)
                      Positioned(
                        left:
                            50.0 +
                            i * 80 +
                            30 * math.sin(_backgroundAnimation.value + i),
                        top:
                            100.0 +
                            i * 120 +
                            20 * math.cos(_backgroundAnimation.value + i),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Main Content
          user == null
              ? const Center(
                child: Text(
                  'Not logged in',
                  style: TextStyle(color: Colors.white),
                ),
              )
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('quizzes')
                        .where('userId', isEqualTo: user.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading quizzes: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1000),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Icon(
                                  Icons.quiz,
                                  size: 80,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No quizzes found.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the + button to create your first quiz!',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final quizzes = snapshot.data!.docs;
                  quizzes.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = aData['createdAt'] as Timestamp?;
                    final bTime = bData['createdAt'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: quizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = quizzes[index];
                      final quizData = quiz.data() as Map<String, dynamic>;

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 600 + index * 100),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(
                                50 * (1 - value),
                                30 * (1 - value),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            elevation: 12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            color: Colors.grey[850],
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey[850]!,
                                    Colors.grey[800]!,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quizData['title'] ?? 'Untitled Quiz',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                    if (quizData['subject'] != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.blue, Colors.cyan],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blue.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          quizData['subject'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (quizData['timeLimit'] != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.timer,
                                              color: Colors.orange,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${quizData['timeLimit']} min',
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    ...List<String>.from(
                                          quizData['questions'] ?? [],
                                        )
                                        .take(3)
                                        .map(
                                          (q) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    q,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.white70,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    if ((quizData['questions'] as List?)
                                                ?.length !=
                                            null &&
                                        (quizData['questions'] as List).length >
                                            3)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '... and ${(quizData['questions'] as List).length - 3} more questions',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed:
                                            () => _showQuizDialog(quiz: quiz),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () => _showDeleteConfirmation(
                                              quiz.id,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

          // Welcome Animation Overlay
          AnimatedOpacity(
            opacity: _showWelcome ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 3000),
            child:
                _showWelcome
                    ? Container(
                      color: Colors.black,
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1500),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Image.asset(
                                'assets/SABER-Logo.png',
                                width: 300,
                                height: 300,
                              ),
                            );
                          },
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),

      // Enhanced Floating Action Button
      floatingActionButton: AnimatedBuilder(
        animation: Listenable.merge([_fabPulseAnimation, _fabRotateAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _fabPulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  // Add a small rotation animation on press
                  _fabController.forward().then(
                    (_) => _fabController.reverse(),
                  );
                  _showQuizDialog();
                },
                backgroundColor: Colors.red,
                elevation: 8,
                icon: Transform.rotate(
                  angle: _fabRotateAnimation.value * 0.1,
                  child: const Icon(Icons.add, size: 24),
                ),
                label: const Text(
                  'Create Quiz',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                tooltip: 'Create a new quiz',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthService auth) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[850]!],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.8),
                    Colors.orange.withOpacity(0.8),
                  ],
                ),
              ),
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white30),
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
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.lightbulb,
                    title: "AI Explanations",
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: "Settings",
                    onTap: () {
                      Navigator.pop(context);
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
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        onTap: onTap,
        hoverColor: Colors.grey[800],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Enhanced QuizDialog with animations
class QuizDialog extends StatefulWidget {
  final DocumentSnapshot? quiz;

  const QuizDialog({super.key, this.quiz});

  @override
  State<QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<QuizDialog> with TickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _markschemeController;
  late List<TextEditingController> _questionControllers;
  late String? _editingQuizId;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late TextEditingController _timeController;
  int _selectedTimeMinutes = 30;
  // Predefined subjects list
  final List<String> _predefinedSubjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'History',
    'Geography',
    'Computer Science',
    'Economics',
    'Psychology',
    'Art',
    'Music',
    'Physical Education',
    'Foreign Language',
    'Philosophy',
  ];
  Widget _buildTimeButton(String label, int minutes) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeMinutes = minutes;
          _timeController.text = minutes.toString();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              _selectedTimeMinutes == minutes ? Colors.blue : Colors.grey[700],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                _selectedTimeMinutes == minutes
                    ? Colors.blue
                    : Colors.grey[600]!,
          ),
        ),
        child: Text(
          '${label}m',
          style: TextStyle(
            color:
                _selectedTimeMinutes == minutes
                    ? Colors.white
                    : Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _timeController = TextEditingController();

    // If editing existing quiz, load the time
    if (widget.quiz != null) {
      final quizData = widget.quiz!.data() as Map<String, dynamic>;
      _selectedTimeMinutes = quizData['timeLimit'] ?? 30;
      _timeController.text = _selectedTimeMinutes.toString();
    } else {
      _timeController.text = '30';
    }
    // Initialize animation controller
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _titleController = TextEditingController();
    _subjectController = TextEditingController();
    _markschemeController = TextEditingController();
    _questionControllers = [];

    if (widget.quiz != null) {
      _editingQuizId = widget.quiz!.id;
      final quizData = widget.quiz!.data() as Map<String, dynamic>;

      _titleController.text = quizData['title'] ?? '';
      _subjectController.text = quizData['subject'] ?? '';
      _markschemeController.text = quizData['markscheme'] ?? '';

      final questions = List<String>.from(quizData['questions'] ?? []);

      for (int i = 0; i < questions.length; i++) {
        _questionControllers.add(TextEditingController(text: questions[i]));
      }
    } else {
      _editingQuizId = null;
    }

    if (_questionControllers.isEmpty) {
      _questionControllers.add(TextEditingController());
    }

    // Start animation
    _slideController.forward();
  }

  @override
  void dispose() {
    _timeController.dispose();
    _slideController.dispose();
    _titleController.dispose();
    _subjectController.dispose();
    _markschemeController.dispose();
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveQuiz() async {
    final user = FirebaseAuth.instance.currentUser;
    final questions =
        _questionControllers
            .map((c) => c.text.trim())
            .where((q) => q.isNotEmpty)
            .toList();

    if (user != null &&
        _titleController.text.trim().isNotEmpty &&
        _subjectController.text.trim().isNotEmpty &&
        questions.isNotEmpty) {
      final quizData = {
        'title': _titleController.text.trim(),
        'subject': _subjectController.text.trim(),
        'questions': questions,
        'markscheme': _markschemeController.text.trim(),
        'timeLimit': _selectedTimeMinutes, // Add this line
        'userId': user.uid,
        'createdAt':
            _editingQuizId == null
                ? FieldValue.serverTimestamp()
                : FieldValue.serverTimestamp(),
      };

      try {
        if (_editingQuizId == null) {
          final docRef = await FirebaseFirestore.instance
              .collection('quizzes')
              .add(quizData);
          print('Quiz created with ID: ${docRef.id}');
        } else {
          await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(_editingQuizId)
              .update({
                'title': _titleController.text.trim(),
                'subject': _subjectController.text.trim(),
                'questions': questions,
                'markscheme': _markschemeController.text.trim(),
                'timeLimit': _selectedTimeMinutes, // Add this line
                'updatedAt': FieldValue.serverTimestamp(),
              });
          print('Quiz updated with ID: $_editingQuizId');
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _editingQuizId == null
                        ? 'Quiz created successfully!'
                        : 'Quiz updated successfully!',
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        print('Error saving quiz: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Error saving quiz: $e'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Please fill in the title, subject, and at least one question',
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _addQuestion() {
    setState(() {
      _questionControllers.add(TextEditingController());
    });
  }

  void _removeQuestion(int index) {
    if (_questionControllers.length > 1) {
      setState(() {
        _questionControllers[index].dispose();
        _questionControllers.removeAt(index);
      });
    }
  }

  void _showSubjectPicker() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey[850]!, Colors.grey[900]!],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        colors: [Colors.red, Colors.orange],
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.school, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Select Subject',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    height: 400,
                    child: ListView.builder(
                      itemCount: _predefinedSubjects.length,
                      itemBuilder: (context, index) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 100 + index * 50),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(20 * (1 - value), 0),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              title: Text(
                                _predefinedSubjects[index],
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                _subjectController.text =
                                    _predefinedSubjects[index];
                                Navigator.of(context).pop();
                              },
                              hoverColor: Colors.grey[800],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey[850]!, Colors.grey[900]!],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(colors: [Colors.red, Colors.orange]),
                ),
                child: Row(
                  children: [
                    Icon(
                      _editingQuizId == null ? Icons.add_circle : Icons.edit,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _editingQuizId == null ? 'Create Quiz' : 'Edit Quiz',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: 500,
                    height: 600,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Quiz Title
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 400),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: TextField(
                              controller: _titleController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Quiz Title *',
                                labelStyle: const TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey[600]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey[800],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Subject Selection
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 600),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _subjectController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Subject *',
                                      labelStyle: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.grey[600]!,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[800],
                                      hintText:
                                          'Enter subject or select from list',
                                      hintStyle: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue, Colors.cyan],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _showSubjectPicker,
                                    icon: const Icon(
                                      Icons.list,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Select',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Time Limit Selection
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 700),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _timeController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    onChanged: (value) {
                                      final minutes = int.tryParse(value);
                                      if (minutes != null && minutes > 0) {
                                        _selectedTimeMinutes = minutes;
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Time Limit (minutes) *',
                                      labelStyle: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.grey[600]!,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[800],
                                      suffixText: 'min',
                                      suffixStyle: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Quick time selection buttons
                                Column(
                                  children: [
                                    _buildTimeButton('15', 15),
                                    const SizedBox(height: 4),
                                    _buildTimeButton('30', 30),
                                    const SizedBox(height: 4),
                                    _buildTimeButton('60', 60),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Questions
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Questions:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _questionControllers.length,
                            itemBuilder:
                                (
                                  context,
                                  index,
                                ) => TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Duration(
                                    milliseconds: 800 + index * 100,
                                  ),
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 30 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.grey[700]!,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  'Question ${index + 1}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (_questionControllers.length >
                                                  1)
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed:
                                                        () => _removeQuestion(
                                                          index,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller:
                                                _questionControllers[index],
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Question',
                                              labelStyle: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.grey[600]!,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Colors.red,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey[700],
                                            ),
                                            maxLines: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ),

                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: TextButton.icon(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.blue,
                              ),
                              label: const Text(
                                'Add Question',
                                style: TextStyle(color: Colors.blue),
                              ),
                              onPressed: _addQuestion,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.blue.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.blue.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Mark Scheme
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Mark Scheme / Answer Key:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1000),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: TextField(
                              controller: _markschemeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Mark Scheme / Answer Key',
                                labelStyle: const TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey[600]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey[800],
                                hintText:
                                    'Enter the marking criteria or expected answers for all questions',
                                hintStyle: const TextStyle(color: Colors.grey),
                              ),
                              maxLines: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.orange],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _saveQuiz,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _editingQuizId == null
                              ? 'Create Quiz'
                              : 'Update Quiz',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
