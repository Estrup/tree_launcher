import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/kanban/domain/comment.dart';
import 'package:tree_launcher/features/kanban/domain/issue.dart';
import 'package:tree_launcher/features/kanban/domain/issue_copilot_link.dart';
import 'package:tree_launcher/features/kanban/domain/issue_status.dart';
import 'package:tree_launcher/features/kanban/domain/project.dart';
import 'package:tree_launcher/features/kanban/presentation/controllers/issue_detail_controller.dart';
import 'package:tree_launcher/features/kanban/presentation/controllers/project_board_controller.dart';

class KanbanController extends ChangeNotifier {
  KanbanController({
    ProjectBoardController? boardController,
    IssueDetailController? issueDetailController,
  }) : board = boardController ?? ProjectBoardController(),
       detail = issueDetailController ?? IssueDetailController() {
    board.addListener(_relay);
    detail.addListener(_relay);
  }

  final ProjectBoardController board;
  final IssueDetailController detail;

  List<Project> get projects => board.projects;

  void _relay() => notifyListeners();

  List<Issue> issuesForProject(String projectId) =>
      board.issuesForProject(projectId);

  Map<IssueStatus, List<Issue>> issuesByStatus(String projectId) {
    return board.issuesByStatus(projectId);
  }

  void loadProjectsForRepo(String repoPath) =>
      board.loadProjectsForRepo(repoPath);

  Project createProject(String repoPath, String name, String key) {
    return board.createProject(repoPath, name, key);
  }

  void archiveProject(String projectId) => board.archiveProject(projectId);

  Issue createIssue(String projectId, String title, {String? description}) {
    return board.createIssue(projectId, title, description: description);
  }

  void updateIssue(Issue issue) => board.updateIssue(issue);

  void moveIssue(String issueId, String projectId, IssueStatus newStatus) {
    board.moveIssue(issueId, projectId, newStatus);
  }

  void archiveIssue(String issueId, String projectId) {
    board.archiveIssue(issueId, projectId);
  }

  IssueCopilotLink linkCopilotSession(
    String issueId,
    String copilotSessionId, {
    String? worktreePath,
    String? branch,
  }) {
    return detail.linkCopilotSession(
      issueId,
      copilotSessionId,
      worktreePath: worktreePath,
      branch: branch,
    );
  }

  void updateCopilotLink(IssueCopilotLink link) =>
      detail.updateCopilotLink(link);

  void unlinkCopilotSession(String issueId, String copilotSessionId) {
    detail.unlinkCopilotSession(issueId, copilotSessionId);
  }

  List<IssueCopilotLink> getLinkedSessions(String issueId) {
    return detail.getLinkedSessions(issueId);
  }

  Comment addComment({
    required String issueId,
    required String content,
    required CommentAuthorType authorType,
    required String authorName,
  }) {
    return detail.addComment(
      issueId: issueId,
      content: content,
      authorType: authorType,
      authorName: authorName,
    );
  }

  void updateComment(String commentId, String newContent) {
    detail.updateComment(commentId, newContent);
  }

  void deleteComment(String commentId) => detail.deleteComment(commentId);

  List<Comment> getComments(String issueId) => detail.getComments(issueId);

  void refreshLoadedRepoIfMatches(String repoPath) {
    board.refreshLoadedRepoIfMatches(repoPath);
  }

  @override
  void dispose() {
    board.removeListener(_relay);
    detail.removeListener(_relay);
    board.dispose();
    detail.dispose();
    super.dispose();
  }
}
