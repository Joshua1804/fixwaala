/// A single follow-up question asked during AI ticket assist and the
/// customer's answer to it.
class ClarifyingQa {
  final String question;
  final String answer;

  const ClarifyingQa({required this.question, required this.answer});

  Map<String, String> toMap() => {'question': question, 'answer': answer};

  factory ClarifyingQa.fromMap(Map<String, dynamic> map) => ClarifyingQa(
    question: map['question'] as String? ?? '',
    answer: map['answer'] as String? ?? '',
  );
}
