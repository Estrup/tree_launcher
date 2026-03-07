import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/kanban/data/comment_repository.dart';
import 'package:tree_launcher/features/kanban/data/issue_copilot_repository.dart';
import 'package:tree_launcher/features/kanban/data/issue_repository.dart';
import 'package:tree_launcher/features/kanban/data/project_repository.dart';
import 'package:tree_launcher/features/kanban/domain/comment.dart';
import 'package:tree_launcher/features/kanban/domain/issue.dart';
import 'package:tree_launcher/features/kanban/domain/issue_copilot_link.dart';
import 'package:tree_launcher/features/kanban/domain/issue_status.dart';
import 'package:tree_launcher/features/kanban/domain/project.dart';

class ProjectBoardController extends ChangeNotifier {
  ProjectBoardController({
    ProjectRepository? projectRepo,
    IssueRepository? issueRepo,
    IssueCopilotRepository? copilotRepo,
    CommentRepository? commentRepo,
  }) : _projectRepo = projectRepo ?? ProjectRepository(),
       _issueRepo = issueRepo ?? IssueRepository(),
       _copilotRepo = copilotRepo ?? IssueCopilotRepository(),
       _commentRepo = commentRepo ?? CommentRepository();

  final ProjectRepository _projectRepo;
  final IssueRepository _issueRepo;
  final IssueCopilotRepository _copilotRepo;
  final CommentRepository _commentRepo;

  List<Project> _projects = [];
  final Map<String, List<Issue>> _issuesByProject = {};
  String? _loadedRepoPath;

  List<Project> get projects => _projects;
  String? get loadedRepoPath => _loadedRepoPath;

  List<Issue> issuesForProject(String projectId) {
    return _issuesByProject[projectId] ?? [];
  }

  Map<IssueStatus, List<Issue>> issuesByStatus(String projectId) {
    final issues = issuesForProject(projectId);
    return {
      for (final status in IssueStatus.values)
        status: issues.where((issue) => issue.status == status).toList(),
    };
  }

  void loadProjectsForRepo(String repoPath) {
    _loadedRepoPath = repoPath;
    _projects = _projectRepo.getProjectsForRepo(repoPath);
    for (final project in _projects) {
      _issuesByProject[project.id] = _issueRepo.getIssuesForProject(project.id);
    }
    notifyListeners();
  }

  Project createProject(String repoPath, String name, String key) {
    final project = _projectRepo.createProject(repoPath, name, key);
    _projects.add(project);
    _issuesByProject[project.id] = [];
    notifyListeners();
    return project;
  }

  void archiveProject(String projectId) {
    _projectRepo.archiveProject(projectId);
    _projects.removeWhere((project) => project.id == projectId);
    _issuesByProject.remove(projectId);
    notifyListeners();
  }

  Issue createIssue(String projectId, String title, {String? description}) {
    final project = _projects.firstWhere((item) => item.id == projectId);
    final issue = _issueRepo.createIssue(
      projectId,
      project.key,
      title,
      description: description,
    );
    _issuesByProject.putIfAbsent(projectId, () => []);
    _issuesByProject[projectId]!.add(issue);
    notifyListeners();
    return issue;
  }

  void updateIssue(Issue issue) {
    _issueRepo.updateIssue(issue);
    final refreshed = _issueRepo.getIssueById(issue.id);
    if (refreshed != null) {
      final list = _issuesByProject[issue.projectId];
      if (list != null) {
        final index = list.indexWhere((item) => item.id == issue.id);
        if (index != -1) {
          list[index] = refreshed;
        }
      }
    }
    notifyListeners();
  }

  void moveIssue(String issueId, String projectId, IssueStatus newStatus) {
    _issueRepo.moveIssue(issueId, newStatus);
    final list = _issuesByProject[projectId];
    if (list != null) {
      final index = list.indexWhere((item) => item.id == issueId);
      if (index != -1) {
        list[index] = list[index].copyWith(status: newStatus);
      }
    }
    notifyListeners();
  }

  void archiveIssue(String issueId, String projectId) {
    _issueRepo.archiveIssue(issueId);
    _issuesByProject[projectId]?.removeWhere((issue) => issue.id == issueId);
    notifyListeners();
  }

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

  void refreshLoadedRepoIfMatches(String repoPath) {
    if (_loadedRepoPath != repoPath) return;
    loadProjectsForRepo(repoPath);
  }
}
