import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/ui_state_store.dart';

/// An unsent Jira comment.
class JiraCommentDraft {
  const JiraCommentDraft({
    required this.body,
    this.consultantsOnly = false,
    this.savedAt,
  });

  /// The comment's wiki markup.
  final String body;

  /// Whether it is for the Consultants role only.
  final bool consultantsOnly;
  final DateTime? savedAt;

  factory JiraCommentDraft.fromJson(Map<String, dynamic> json) =>
      JiraCommentDraft(
        body: json['body'] as String? ?? '',
        consultantsOnly: json['consultantsOnly'] as bool? ?? false,
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
    'body': body,
    'consultantsOnly': consultantsOnly,
    if (savedAt != null) 'savedAt': savedAt!.toIso8601String(),
  };
}

/// Unsent Jira comments, one per issue key, kept in the `ui_state` table so
/// they survive closing the dialog and the app. Also remembers whether the
/// last comment sent was for consultants only. Never throws: a failure is
/// logged and reads as no draft.
class JiraCommentDraftStore {
  JiraCommentDraftStore(this._uiState);

  final UiStateStore _uiState;

  static const _scope = 'jira-comment-drafts';
  static const _consultantsOnlyKey = 'jiraCommentConsultantsOnly';

  Future<JiraCommentDraft?> read(String issueKey) async {
    try {
      final json = (await _uiState.read(_scope))[issueKey];
      return json is Map<String, dynamic>
          ? JiraCommentDraft.fromJson(json)
          : null;
    } catch (e) {
      debugPrint('Jira comment draft read failed for $issueKey: $e');
      return null;
    }
  }

  /// Saves [draft] for [issueKey]; null, or an empty body, removes it.
  Future<void> write(String issueKey, JiraCommentDraft? draft) async {
    try {
      await _uiState.write(_scope, {
        issueKey: draft == null || draft.body.trim().isEmpty
            ? null
            : draft.toJson(),
      });
    } catch (e) {
      debugPrint('Jira comment draft save failed for $issueKey: $e');
    }
  }

  /// Whether the last comment sent was for consultants only.
  Future<bool> lastConsultantsOnly() async {
    try {
      return (await _uiState.read(
            UiStateStore.appScope,
          ))[_consultantsOnlyKey] ==
          true;
    } catch (_) {
      return false;
    }
  }

  Future<void> rememberConsultantsOnly(bool value) async {
    try {
      await _uiState.write(UiStateStore.appScope, {_consultantsOnlyKey: value});
    } catch (e) {
      debugPrint('Jira comment visibility save failed: $e');
    }
  }
}
