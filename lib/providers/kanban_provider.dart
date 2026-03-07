import 'package:flutter/foundation.dart';
import '../models/issue.dart';
import '../models/issue_copilot_link.dart';
import '../models/project.dart';
import '../services/issue_copilot_repository.dart';
import '../services/issue_repository.dart';
import '../services/project_repository.dart';
import '../widgets/kanban_board.dart';

class KanbanProvider extends ChangeNotifier {
  final ProjectRepository _projectRepo;
  final IssueRepository _issueRepo;
  final IssueCopilotRepository _copilotRepo;

  List<Project> _projects = [];
  // projectId -> list of issues
  final Map<String, List<Issue>> _issuesByProject = {};

  KanbanProvider({
    ProjectRepository? projectRepo,
    IssueRepository? issueRepo,
    IssueCopilotRepository? copilotRepo,
  }) : _projectRepo = projectRepo ?? ProjectRepository(),
       _issueRepo = issueRepo ?? IssueRepository(),
       _copilotRepo = copilotRepo ?? IssueCopilotRepository();

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<Project> get projects => _projects;

  List<Issue> issuesForProject(String projectId) {
    return _issuesByProject[projectId] ?? [];
  }

  Map<KanbanColumnStatus, List<Issue>> issuesByStatus(String projectId) {
    final issues = issuesForProject(projectId);
    return {
      for (var status in KanbanColumnStatus.values)
        status: issues.where((i) => i.status == status).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Project operations
  // ---------------------------------------------------------------------------

  /// Loads all non-archived projects for a repo. Call when repo is selected.
  void loadProjectsForRepo(String repoPath) {
    _projects = _projectRepo.getProjectsForRepo(repoPath);
    // Pre-load issues for each project
    for (final project in _projects) {
      _issuesByProject[project.id] = _issueRepo.getIssuesForProject(project.id);
    }
    notifyListeners();
  }

  /// Creates a new project and refreshes the list.
  Project createProject(String repoPath, String name) {
    final project = _projectRepo.createProject(repoPath, name);
    _projects.add(project);
    _issuesByProject[project.id] = [];
    notifyListeners();
    return project;
  }

  /// Archives a project and removes it from the active list.
  void archiveProject(String projectId) {
    _projectRepo.archiveProject(projectId);
    _projects.removeWhere((p) => p.id == projectId);
    _issuesByProject.remove(projectId);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Issue operations
  // ---------------------------------------------------------------------------

  /// Creates a new issue in the given project.
  Issue createIssue(String projectId, String title, {String? description}) {
    final issue = _issueRepo.createIssue(
      projectId,
      title,
      description: description,
    );
    _issuesByProject.putIfAbsent(projectId, () => []);
    _issuesByProject[projectId]!.add(issue);
    notifyListeners();
    return issue;
  }

  /// Updates an existing issue (title, description, tags, branch, worktree).
  void updateIssue(Issue issue) {
    _issueRepo.updateIssue(issue);
    // Refresh from DB to get updated_at
    final refreshed = _issueRepo.getIssueById(issue.id);
    if (refreshed != null) {
      final list = _issuesByProject[issue.projectId];
      if (list != null) {
        final idx = list.indexWhere((i) => i.id == issue.id);
        if (idx != -1) {
          list[idx] = refreshed;
        }
      }
    }
    notifyListeners();
  }

  /// Moves an issue to a new status column.
  void moveIssue(
    String issueId,
    String projectId,
    KanbanColumnStatus newStatus,
  ) {
    _issueRepo.moveIssue(issueId, newStatus);
    final list = _issuesByProject[projectId];
    if (list != null) {
      final idx = list.indexWhere((i) => i.id == issueId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(status: newStatus);
      }
    }
    notifyListeners();
  }

  /// Archives an issue.
  void archiveIssue(String issueId, String projectId) {
    _issueRepo.archiveIssue(issueId);
    _issuesByProject[projectId]?.removeWhere((i) => i.id == issueId);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Copilot session linking
  // ---------------------------------------------------------------------------

  /// Links a copilot session to an issue.
  IssueCopilotLink linkCopilotSession(String issueId, String copilotSessionId) {
    final link = _copilotRepo.linkSession(issueId, copilotSessionId);
    notifyListeners();
    return link;
  }

  /// Unlinks a copilot session from an issue.
  void unlinkCopilotSession(String issueId, String copilotSessionId) {
    _copilotRepo.unlinkSession(issueId, copilotSessionId);
    notifyListeners();
  }

  /// Gets all copilot session links for an issue.
  List<IssueCopilotLink> getLinkedSessions(String issueId) {
    return _copilotRepo.getLinksForIssue(issueId);
  }
}
