/// Data model for an interactive **Quiz** post.
///
/// A quiz contains 2–6 questions, each with 2–4 options and one correct answer.
/// After answering, the user sees their score and how they compare to others.
class QuizModel { // 0 = no limit

  QuizModel({
    required this.title,
    required this.questions,
    this.timeLimitSeconds = 0,
  });

  factory QuizModel.fromMap(Map<String, dynamic> map) => QuizModel(
    title: map['title'] ?? '',
    questions:
        (map['questions'] as List?)
            ?.map((q) => QuizQuestion.fromMap(q))
            .toList() ??
        [],
    timeLimitSeconds: map['timeLimitSeconds'] ?? 0,
  );
  final String title;
  final List<QuizQuestion> questions;
  final int timeLimitSeconds;

  Map<String, dynamic> toMap() => {
    'title': title,
    'questions': questions.map((q) => q.toMap()).toList(),
    'timeLimitSeconds': timeLimitSeconds,
    'totalQuestions': questions.length,
  };
}

class QuizQuestion { // 0-based index of correct option

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) => QuizQuestion(
    id: map['id'] ?? '',
    question: map['question'] ?? '',
    options: List<String>.from(map['options'] ?? []),
    correctIndex: map['correctIndex'] ?? 0,
  );
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;

  Map<String, dynamic> toMap() => {
    'id': id,
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
  };
}
