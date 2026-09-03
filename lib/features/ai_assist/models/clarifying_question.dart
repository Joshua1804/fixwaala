/// A clarifying question generated during AI ticket assist along with
/// dynamic suggested answers/options.
class ClarifyingQuestion {
  final String question;
  final List<String> options;

  const ClarifyingQuestion({
    required this.question,
    this.options = const [],
  });

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options,
      };

  factory ClarifyingQuestion.fromMap(Map<String, dynamic> map) =>
      ClarifyingQuestion(
        question: map['question'] as String? ?? '',
        options: (map['options'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
}
