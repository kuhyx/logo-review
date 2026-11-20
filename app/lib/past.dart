/// What came before the round on show: history and the designer's words.
library;

import 'package:logo_review/models.dart';

/// One earlier round of a design.
typedef Step = ({int round, String id, String text});

/// The designs' earlier rounds and what was said in each archived review.
class History {
  /// No history.
  new() : steps = {}, said = {}, tools = {};

  /// Reads `/api/history`.
  new fromJson(Json j)
    : steps = asObject(j['steps']).map(
        (k, v) => MapEntry(k, [
          for (final s in asList<Map<dynamic, dynamic>>(v))
            (
              round: s['round'] is int ? s['round'] as int : 0,
              id: '${s['id'] ?? ''}',
              text: '${s['text'] ?? ''}',
            ),
        ]),
      ),
      said = asObject(j['said']).map(
        (round, logos) => MapEntry(
          round,
          asObject(logos)
              .map((k, v) => MapEntry(k, Entry.fromJson(asObject(v)))),
        ),
      ),
      tools = asLists(j['tools']);

  /// Design id to its steps, oldest first.
  final Map<String, List<Step>> steps;

  /// Round to logo key to what the reviewer said then.
  final Map<String, Map<String, Entry>> said;

  /// Round to the tools it was reviewed in.
  final Map<String, List<String>> tools;
}

/// The designer's side: why each design is the way it is, and the answers.
class Designer {
  /// Nothing said yet.
  new() : designs = {}, tools = {}, answers = {};

  /// Reads `/api/claude`.
  new fromJson(Json j)
    : designs = asObject(asObject(j['rationale'])['designs'])
          .map((k, v) => MapEntry(k, '$v')),
      tools = asObject(asObject(j['rationale'])['tools'])
          .map((k, v) => MapEntry(k, '$v')),
      answers = asObject(j['answers'])
          .map((k, v) => MapEntry(k, asMessages(v)));

  /// Rationale per design id.
  final Map<String, String> designs;

  /// Rationale per tool.
  final Map<String, String> tools;

  /// Answers per logo key.
  final Map<String, List<Message>> answers;
}
