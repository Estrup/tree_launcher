import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/kanban/data/comment_repository.dart';
import 'package:tree_launcher/features/kanban/data/issue_copilot_repository.dart';
import 'package:tree_launcher/features/kanban/domain/comment.dart';
import 'package:tree_launcher/features/kanban/domain/issue_copilot_link.dart';

class IssueDetailController extends ChangeNotifier {
  IssueDetailController({
    IssueCopilotRepository? copilotRepo,
    CommentRepository? commentRepo,
  }) : _copilotRepo = copilotRepo ?? IssueCopilotRepository(),
       _commentRepo = commentRepo ?? CommentRepository();

  final IssueCopilotRepository _copilotRepo;
  final CommentRepository _commentRepo;

  IssueCopilotLink linkCopilotSession(
    String issueId,
    String copilotSessionId, {
    String? worktreePath,
    String? branch,
  }) {
    final link = _copilotRepo.linkSession(
      issueId,
      copilotSessionId,
      worktreePath: worktreePath,
      branch: branch,
    );
    notifyListeners();
    return link;
  }

  void updateCopilotLink(IssueCopilotLink link) {
    _copilotRepo.updateLink(link);
    notifyListeners();
  }

  void unlinkCopilotSession(String issueId, String copilotSessionId) {
    _copilotRepo.unlinkSession(issueId, copilotSessionId);
    notifyListeners();
  }

  List<IssueCopilotLink> getLinkedSessions(String issueId) {
    return _copilotRepo.getLinksForIssue(issueId);
  }

  Comment addComment({
    required String issueId,
    required String content,
    required CommentAuthorType authorType,
    required String authorName,
  }) {
    final comment = _commentRepo.createComment(
      issueId: issueId,
      content: content,
      authorType: authorType,
      authorName: authorName,
    );
    notifyListeners();
    return comment;
  }

  void updateComment(String commentId, String newContent) {
    _commentRepo.updateComment(commentId, newContent);
    notifyListeners();
  }

  void deleteComment(String commentId) {
    _commentRepo.deleteComment(commentId);
    notifyListeners();
  }

  List<Comment> getComments(String issueId) {
    return _commentRepo.getCommentsForIssue(issueId);
  }
}
