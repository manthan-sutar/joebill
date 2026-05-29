import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncState {
  final int pending;
  final String? lastError;

  const SyncState({this.pending = 0, this.lastError});

  bool get isSyncing => pending > 0;

  SyncState copyWith({int? pending, String? lastError, bool clearError = false}) =>
      SyncState(
        pending: pending ?? this.pending,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(const SyncState());

  void start() => state = state.copyWith(pending: state.pending + 1, clearError: true);

  void finish({String? error}) {
    final next = (state.pending - 1).clamp(0, 999);
    state = SyncState(pending: next, lastError: error);
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((_) => SyncNotifier());
