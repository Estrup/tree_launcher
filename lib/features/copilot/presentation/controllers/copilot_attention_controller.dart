import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';

class CopilotAttentionController extends ChangeNotifier {
  final Map<String, CopilotActivityStatus> _sessionStatuses = {};

  CopilotActivityStatus statusForSession(String id) {
    return _sessionStatuses[id] ?? CopilotActivityStatus.idle;
  }

  bool get hasAnyActivity => _sessionStatuses.values.any(
    (status) =>
        status == CopilotActivityStatus.working ||
        status == CopilotActivityStatus.needsAction,
  );

  CopilotActivityStatus get aggregateStatus {
    if (_sessionStatuses.values.any(
      (status) => status == CopilotActivityStatus.needsAction,
    )) {
      return CopilotActivityStatus.needsAction;
    }
    if (_sessionStatuses.values.any(
      (status) => status == CopilotActivityStatus.working,
    )) {
      return CopilotActivityStatus.working;
    }
    return CopilotActivityStatus.idle;
  }

  List<CopilotSession> sessionsNeedingAction(List<CopilotSession> sessions) {
    return sessions
        .where(
          (session) =>
              _sessionStatuses[session.id] == CopilotActivityStatus.needsAction,
        )
        .toList();
  }

  void setStatus(String sessionId, CopilotActivityStatus status) {
    if (_sessionStatuses[sessionId] == status) return;
    _sessionStatuses[sessionId] = status;
    notifyListeners();
  }

  void removeStatus(String sessionId) {
    if (_sessionStatuses.remove(sessionId) != null) {
      notifyListeners();
    }
  }

  void clearAll() {
    if (_sessionStatuses.isEmpty) return;
    _sessionStatuses.clear();
    notifyListeners();
  }

  static CopilotActivityStatus parseStatus(String title) {
    if (title.contains('\u{1F916}')) {
      return CopilotActivityStatus.working;
    }
    return CopilotActivityStatus.idle;
  }
}
