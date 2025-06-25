// lib/ai_explanations.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// A simple data model for type safety and cleaner code
class Explanation {
  final int questionNumber;
  final int score;
  final String explanationWithSuggestion;

  Explanation({
    required this.questionNumber,
    required this.score,
    required this.explanationWithSuggestion,
  });

  // Factory constructor to create an Explanation from a Firestore map
  factory Explanation.fromMap(Map<String, dynamic> map) {
    return Explanation(
      questionNumber: map['question_number'] ?? 0,
      score: map['score'] ?? 0,
      explanationWithSuggestion:
          map['explanation_with_suggestion'] ?? 'No explanation provided.',
    );
  }
}

class AIExplanationsScreen extends StatefulWidget {
  final String quizId;
  final String studentId;

  const AIExplanationsScreen({
    Key? key,
    required this.quizId,
    required this.studentId,
  }) : super(key: key);

  @override
  _AIExplanationsScreenState createState() => _AIExplanationsScreenState();
}

class _AIExplanationsScreenState extends State<AIExplanationsScreen> {
  bool _isLoading = true;
  String? _quizTitle;
  String? _errorMessage;
  List<Explanation> _explanations = [];
  late List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    _loadExplanations();
  }

  Future<void> _loadExplanations() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('answers')
              .where('quizId', isEqualTo: widget.quizId)
              .where('studentId', isEqualTo: widget.studentId)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Could not find your answer for this quiz.');
      }

      final answerData = snapshot.docs.first.data();
      _quizTitle = answerData['quizTitle'] ?? 'Quiz Explanations';

      if (answerData.containsKey('explanations') &&
          answerData['explanations'] != null) {
        final List<dynamic> explanationsList = answerData['explanations'];
        if (explanationsList.isNotEmpty) {
          _explanations =
              explanationsList
                  .map((e) => Explanation.fromMap(e as Map<String, dynamic>))
                  .toList();
          // Sort by question number to ensure correct order
          _explanations.sort(
            (a, b) => a.questionNumber.compareTo(b.questionNumber),
          );

          // --- MODIFIED LINE ---
          // Initialize the expansion list, expanding ALL items by default
          _isExpanded = List<bool>.filled(_explanations.length, true);
        } else {
          throw Exception('AI explanations are not available for this quiz.');
        }
      } else {
        throw Exception('AI explanations are not available for this quiz.');
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _generateAndSavePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) {
          return pw.Header(
            level: 0,
            child: pw.Text(
              _quizTitle ?? 'Quiz Explanations',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          );
        },
        build: (pw.Context context) {
          return _explanations.map((exp) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(10),
              margin: const pw.EdgeInsets.only(bottom: 15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Question ${exp.questionNumber}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Score: ${exp.score}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(height: 15),
                  pw.Text(
                    'AI Explanation and Suggestion:',
                    style: pw.TextStyle(
                      fontSize: 14,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    exp.explanationWithSuggestion,
                    textAlign: pw.TextAlign.justify,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList();
        },
      ),
    );

    // This opens the native save/share dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'AI Explanations',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Download as PDF',
            onPressed:
                (_isLoading || _explanations.isEmpty)
                    ? null
                    : _generateAndSavePdf,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _quizTitle!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Here are the detailed explanations for each question based on your answers.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                _isExpanded[index] = !isExpanded;
              });
            },
            animationDuration: const Duration(milliseconds: 300),
            elevation: 1,
            dividerColor: Colors.grey[800],
            children:
                _explanations.asMap().entries.map<ExpansionPanel>((entry) {
                  int index = entry.key;
                  Explanation exp = entry.value;

                  return ExpansionPanel(
                    backgroundColor: Colors.grey[850],
                    isExpanded: _isExpanded[index],
                    canTapOnHeader: true,
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text(
                          'Question ${exp.questionNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          'Your Score: ${exp.score}',
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      );
                    },
                    body: Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text(
                            'AI Explanation & Suggestion',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            exp.explanationWithSuggestion,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
