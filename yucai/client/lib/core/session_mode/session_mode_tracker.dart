/// Session-mode source of truth for the dual-source seam (R6 ADR-2).
///
/// Repositories (data layer) must not import the presentation-layer
/// AuthBloc, so the guest/session flag lives here in core: AuthBloc drives
/// it from its `onChange`, data-layer consumers read it per call.
class SessionModeTracker {
  /// Optimistic default BEFORE AppStarted resolves: guest (local) is the
  /// safe side — it matches the no-credentials path and never blocks reads.
  bool isGuest = true;
}
