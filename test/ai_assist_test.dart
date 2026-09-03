import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/ai_assist/models/clarifying_question.dart';
import 'package:fixwaala/features/ai_assist/models/clarifying_qa.dart';
import 'package:fixwaala/features/ai_assist/services/ai_classifier_service.dart';

void main() {
  group('ClarifyingQuestion Model', () {
    test('serializes to map and back correctly', () {
      const q = ClarifyingQuestion(
        question: 'Is water actively leaking now?',
        options: ['Yes, continuous leak', 'No, only when in use'],
      );

      final map = q.toMap();
      expect(map['question'], 'Is water actively leaking now?');
      expect(map['options'], ['Yes, continuous leak', 'No, only when in use']);

      final restored = ClarifyingQuestion.fromMap(map);
      expect(restored.question, q.question);
      expect(restored.options, q.options);
    });

    test('handles empty options gracefully', () {
      const q = ClarifyingQuestion(question: 'Any issue?');
      expect(q.options, isEmpty);

      final restored = ClarifyingQuestion.fromMap({'question': 'Any issue?'});
      expect(restored.question, 'Any issue?');
      expect(restored.options, isEmpty);
    });
  });

  group('Rule Classifier Guided Questions Options', () {
    test('returns Plumbing questions with suggested options', () {
      final questions = AiClassifierService.instance.guidedQuestions(ServiceCategory.plumber);
      expect(questions, isNotEmpty);
      expect(questions.first.question, contains('leaking'));
      expect(questions.first.options, isNotEmpty);
      expect(questions.first.options, contains('Yes, continuous leak'));
    });

    test('returns Electrician questions with suggested options', () {
      final questions = AiClassifierService.instance.guidedQuestions(ServiceCategory.electrician);
      expect(questions, isNotEmpty);
      expect(questions.first.options, isNotEmpty);
      expect(questions.first.options, contains('Yes, immediately on switch ON'));
    });

    test('returns Carpenter questions with suggested options', () {
      final questions = AiClassifierService.instance.guidedQuestions(ServiceCategory.carpenter);
      expect(questions, isNotEmpty);
      expect(questions[1].options, isNotEmpty);
      expect(questions[1].options, contains('Solid wood'));
    });

    test('classifyByRules attaches questions with options to FaultClassification', () {
      final result = AiClassifierService.instance.classifyByRules('Tap is leaking water everywhere');
      expect(result.category, ServiceCategory.plumber);
      expect(result.clarifyingQuestions, isNotEmpty);
      expect(result.clarifyingQuestions.first.options, isNotEmpty);
    });
  });

  group('ClarifyingQa map compatibility', () {
    test('ClarifyingQa retains exact map contract for submission', () {
      const qa = ClarifyingQa(
        question: 'Is water actively leaking now?',
        answer: 'Yes, continuous leak',
      );
      final map = qa.toMap();
      expect(map['question'], 'Is water actively leaking now?');
      expect(map['answer'], 'Yes, continuous leak');
    });
  });
}
