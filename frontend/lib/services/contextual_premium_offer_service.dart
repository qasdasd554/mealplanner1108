import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/premium_offer.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/premium_screen.dart';
import 'api_client.dart';

class ContextualPremiumOfferService {
  static bool _claimInProgress = false;
  static ({String userId, int generation})? _shownSession;
  static bool get isPresenting => _claimInProgress;

  // Carry only the successful result into its own screen, never an old plan
  // or a list from another account. No network request before navigation.
  static final _recentResults =
      <
        PremiumOfferContext,
        ({Object id, String userId, int generation, DateTime expiresAt})
      >{};

  static void rememberResult(
    BuildContext context,
    PremiumOfferContext offer,
    Object id,
  ) {
    final user = context.read<AuthProvider?>()?.currentUser;
    if (user == null || user.hasPremiumAccess) return;
    _recentResults[offer] = (
      id: id,
      userId: user.id,
      generation: ApiClient().sessionGeneration,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  static bool isRecentResult(
    BuildContext context,
    PremiumOfferContext offer,
    Object id,
  ) {
    final result = _recentResults[offer];
    if (result == null) return false;
    if (!DateTime.now().isBefore(result.expiresAt)) {
      _recentResults.remove(offer);
      return false;
    }
    final user = context.read<AuthProvider?>()?.currentUser;
    return user != null &&
        !user.hasPremiumAccess &&
        result.userId == user.id &&
        result.id == id &&
        result.generation == ApiClient().sessionGeneration;
  }

  static Future<bool> maybeShow(
    BuildContext context,
    PremiumOfferContext offerContext, {
    ApiClient? client,
    Future<void> Function(BuildContext, PremiumOfferContext)? present,
    bool Function()? stillRelevant,
  }) async {
    if (!context.mounted) return false;
    final api = client ?? ApiClient();
    final user = context.read<AuthProvider?>()?.currentUser;
    if (user == null || user.hasPremiumAccess || _claimInProgress) return false;
    final session = (userId: user.id, generation: api.sessionGeneration);
    bool safeToPresent() {
      if (!context.mounted ||
          _shownSession == session ||
          !(stillRelevant?.call() ?? true)) {
        return false;
      }
      final current = context.read<AuthProvider?>()?.currentUser;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      return current?.id == session.userId &&
          current?.hasPremiumAccess == false &&
          api.sessionGeneration == session.generation &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          MediaQuery.viewInsetsOf(context).bottom == 0 &&
          FocusManager.instance.primaryFocus?.context
                  ?.findAncestorStateOfType<EditableTextState>() ==
              null;
    }

    if (!safeToPresent()) return false;

    _claimInProgress = true;
    try {
      final response = await api.post(
        ApiConfig.usersPremiumOfferClaim,
        body: {'context': offerContext.apiValue},
        timeout: const Duration(seconds: 8),
      );
      final allowed =
          response is Map<String, dynamic> && response['allowed'] == true;
      if (!context.mounted || !allowed || !safeToPresent()) {
        return false;
      }

      _shownSession = session;
      if (present != null) {
        await present(context, offerContext);
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => PremiumScreen(offerContext: offerContext),
          ),
        );
      }
      return true;
    } catch (_) {
      // Oferta nie jest funkcją krytyczną. Awaria sieci nie może przerwać
      // czytania przepisu ani powodować serii lokalnych komunikatów.
      return false;
    } finally {
      _claimInProgress = false;
    }
  }
}

/// The result remains usable before an optional offer. Waiting alone, restored
/// scroll positions and hidden tabs never open a paywall. Each ready result gets
/// at most one attempt, owned by its original account and login session.
class PremiumOfferAfterResult extends StatefulWidget {
  final Object resultId;
  final PremiumOfferContext offerContext;
  final bool enabled;
  final Widget child;
  final ApiClient? client;
  final Future<void> Function(BuildContext, PremiumOfferContext)? present;

  const PremiumOfferAfterResult({
    super.key,
    required this.resultId,
    required this.offerContext,
    required this.child,
    this.enabled = true,
    this.client,
    this.present,
  });

  @override
  State<PremiumOfferAfterResult> createState() =>
      _PremiumOfferAfterResultState();
}

class _PremiumOfferAfterResultState extends State<PremiumOfferAfterResult> {
  Timer? _readingTimer;
  ({String? userId, int generation})? _owner;
  bool _visible = false;
  bool _sessionChanged = false;
  bool _readLongEnough = false;
  bool _scrolledEnough = false;
  bool _dragging = false;
  bool _attempted = false;
  double _dragDistance = 0;
  int _revision = 0;

  ApiClient get _api => widget.client ?? ApiClient();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<AuthProvider?>()?.currentUser?.id;
    final owner = (userId: userId, generation: _api.sessionGeneration);
    final visible = TickerMode.of(context);
    if (_owner == null) {
      _owner = owner;
      _visible = visible;
      _resetReading();
    } else if (_owner != owner || _visible != visible) {
      // Never transfer an old result's pending opportunity to another login.
      if (_owner != owner) _sessionChanged = true;
      _visible = visible;
      _resetReading();
    }
  }

  @override
  void didUpdateWidget(covariant PremiumOfferAfterResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resultId != widget.resultId ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.offerContext != widget.offerContext) {
      _resetReading();
    }
  }

  void _resetReading() {
    _readingTimer?.cancel();
    _revision++;
    _readLongEnough = false;
    _scrolledEnough = false;
    _dragging = false;
    _dragDistance = 0;
    _attempted = false;
    if (widget.enabled && _visible && !_sessionChanged) {
      // Expiration merely arms the offer; another completed user gesture is
      // required. It must not interrupt somebody's first look at the result.
      _readingTimer = Timer(const Duration(seconds: 10), () {
        _readLongEnough = true;
      });
    }
  }

  bool _stillRelevant(int revision) =>
      mounted &&
      revision == _revision &&
      widget.enabled &&
      !_sessionChanged &&
      !_dragging &&
      _readLongEnough &&
      TickerMode.of(context) &&
      context.read<AuthProvider?>()?.currentUser?.id == _owner?.userId &&
      _api.sessionGeneration == _owner?.generation;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragging = true;
      _dragDistance = 0;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _dragDistance += (notification.scrollDelta ?? 0).abs();
      if (_dragDistance >= 180) _scrolledEnough = true;
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
      final revision = _revision;
      if (!_attempted && _scrolledEnough && _stillRelevant(revision)) {
        _attempted = true;
        // Navigation must never be started during a scroll/layout callback.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_stillRelevant(revision)) return;
          unawaited(
            ContextualPremiumOfferService.maybeShow(
              context,
              widget.offerContext,
              client: _api,
              present: widget.present,
              stillRelevant: () => _stillRelevant(revision),
            ),
          );
        });
      }
    }
    return false;
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}
