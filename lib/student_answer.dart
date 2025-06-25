import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:firebase_ai/firebase_ai.dart';
import 'dart:convert';

class StudentAnswerScreen extends StatefulWidget {
  final Map<String, dynamic> quizData;
  final String quizDocId;

  const StudentAnswerScreen({
    super.key,
    required this.quizData,
    required this.quizDocId,
  });

  @override
  State<StudentAnswerScreen> createState() => _StudentAnswerScreenState();
}

class _StudentAnswerScreenState extends State<StudentAnswerScreen> {
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _timer;
  int _remainingTimeInSeconds = 0;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _initializeQuiz() {
    // Initialize the timer with the quiz time limit
    final timeLimit = widget.quizData['timeLimit'] ?? 30;
    _remainingTimeInSeconds = timeLimit * 60; // Convert minutes to seconds

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTimeInSeconds > 0) {
        setState(() {
          _remainingTimeInSeconds--;
        });
      } else {
        // Time's up! Auto-submit the quiz
        _submitQuiz(isAutoSubmit: true);
      }
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submitQuiz({bool isAutoSubmit = false}) async {
    if (_isSubmitting || _hasSubmitted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get student name from Firebase Auth or use email
      final studentName =
          currentUser.displayName ?? currentUser.email ?? 'Unknown Student';

      var quizId = widget.quizData['quizId'];
      var answer = _answerController.text.trim();

      // Variables to hold the AI-generated score and explanations
      Object scoreValue =
          'Not Graded'; // Can be an int (total score) or a String
      List<dynamic>? explanationsValue; // The list of explanations from the AI

      // Start AI grading by first fetching the markscheme
      CollectionReference quizzes = FirebaseFirestore.instance.collection(
        'quizzes',
      );
      QuerySnapshot snapshot =
          await quizzes.where('quizId', isEqualTo: quizId).limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        var markScheme = snapshot.docs.first.get('markscheme');

        // Making the jsonSchema for the AI response
        final jsonSchema = Schema.object(
          properties: {
            'explanations': Schema.array(
              items: Schema.object(
                properties: {
                  'question_number': Schema.integer(),
                  'score': Schema.integer(),
                  'explanation_with_suggestion': Schema.string(),
                },
              ),
            ),
          },
        );

        final model = FirebaseAI.googleAI().generativeModel(
          model: 'gemini-2.5-flash',
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: jsonSchema,
          ),
        );

        final prompt =
            '''Score the student answer based on the markscheme (both are given to you). For each answer scoring, provide an explanation on why the student received that score, and give a suggestion on how the student can improve. 
          Answer: $answer, Markscheme: $markScheme''';

        final response = await model.generateContent([Content.text(prompt)]);
        // START : LOGIC FOR PROCESSING AI RESPONSE

        if (response.text != null && response.text!.isNotEmpty) {
          // 1. Decode the JSON string from the AI response.
          final decodedResponse = jsonDecode(response.text!);

          // 2. Extract the list of explanations.
          final List<dynamic> explanationsList =
              decodedResponse['explanations'];

          // 3. Calculate the total score by summing up the 'score' from each item.
          // We use fold for a safe and concise summation.
          int totalScore = explanationsList.fold<int>(0, (sum, item) {
            // Safely access 'score', defaulting to 0 if it's null or not an int.
            final score = (item as Map<String, dynamic>)['score'];
            return sum + (score as int? ?? 0);
          });

          // 4. Assign the calculated values to our variables.
          scoreValue = totalScore;
          explanationsValue = explanationsList;
        } else {
          // Handle cases where the AI might return an empty response
          scoreValue = 'AI Error: No response';
        }
        // END: AI LOGIC
      } else {
        // If quiz or markscheme is not found, it cannot be graded.
        print('Quiz with ID $quizId not found.');
      }

      // Create the answer document using the processed data
      final Map<String, dynamic> answerData = {
        'studentId': currentUser.uid,
        'studentName': studentName,
        'quizId': quizId,
        'teacherId': widget.quizData['userId'], // Teacher who created the quiz
        'quizTitle': widget.quizData['title'],
        'subject': widget.quizData['subject'],
        'answer': answer,
        'score': scoreValue, // Assign the calculated total_score here
        'submittedAt': FieldValue.serverTimestamp(),
        'isAutoSubmitted': isAutoSubmit,
        'timeSpent':
            (widget.quizData['timeLimit'] * 60) -
            _remainingTimeInSeconds, // Time spent in seconds
      };

      // Conditionally add the 'explanations' field only if it exists
      if (explanationsValue != null) {
        answerData['explanations'] = explanationsValue;
      }

      // Submit to Firestore
      await FirebaseFirestore.instance.collection('answers').add(answerData);

      setState(() {
        _hasSubmitted = true;
        _isSubmitting = false;
      });

      _timer?.cancel(); // Stop the timer

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAutoSubmit
                  ? 'Quiz submitted automatically and scored.'
                  : 'Quiz submitted successfully and scored.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to student screen after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting quiz: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Quiz'),
          content: const Text(
            'Are you sure you want to exit? Your progress will be saved and you can continue later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit quiz screen
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quizData['questions'] as List<dynamic>? ?? [];

    return WillPopScope(
      onWillPop: () async {
        if (!_hasSubmitted) {
          _showExitConfirmation();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          backgroundColor: Colors.grey[850],
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _hasSubmitted ? null : _showExitConfirmation,
          ),
          title: Column(
            children: [
              Text(
                widget.quizData['title'] ?? 'Quiz',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.quizData['subject'] ?? '',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Timer Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _remainingTimeInSeconds <=
                              300 // 5 minutes
                          ? Colors.red[800]
                          : Colors.grey[850],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time,
                      color:
                          _remainingTimeInSeconds <= 300
                              ? Colors.white
                              : Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Time Remaining: ${_formatTime(_remainingTimeInSeconds)}',
                      style: TextStyle(
                        color:
                            _remainingTimeInSeconds <= 300
                                ? Colors.white
                                : Colors.grey[300],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Questions Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.quiz, color: Colors.blue[400], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Questions (${questions.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 16),

                    questions.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No questions available',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: questions.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[600]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Q${index + 1}.',
                                    style: TextStyle(
                                      color: Colors.blue[400],
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    questions[index].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),

              // Answer Section
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit, color: Colors.green[400], size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Answers',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type all your answers for the questions above in the text field below:',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _answerController,
                        enabled: !_hasSubmitted,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.black,
                        ),
                        decoration: const InputDecoration(
                          hintText:
                              'Start typing your answers here...\n\nExample:\nQ1: Answer for question 1\nQ2: Answer for question 2\n...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _hasSubmitted || _isSubmitting
                                ? null
                                : () => _submitQuiz(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _hasSubmitted ? Colors.green : Colors.blue,
                          disabledBackgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            _isSubmitting
                                ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Submitting...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                                : Text(
                                  _hasSubmitted ? 'Submitted ✓' : 'Submit Quiz',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
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
