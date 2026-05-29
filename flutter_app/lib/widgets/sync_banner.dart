import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_provider.dart';
import '../utils/theme.dart';

class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    if (!sync.isSyncing && sync.lastError == null) return const SizedBox.shrink();

    final isError = sync.lastError != null && !sync.isSyncing;
    return Material(
      color: isError ? kAccent.withValues(alpha: 0.15) : kBlue.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpaceMD, vertical: kSpaceSM),
        child: Row(
          children: [
            Icon(
              isError ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded,
              size: 16,
              color: isError ? kAccent : kBlue,
            ),
            const SizedBox(width: kSpaceSM),
            Expanded(
              child: Text(
                isError ? 'Sync failed — ${sync.lastError}' : 'Syncing changes…',
                style: TextStyle(fontSize: 12, color: isError ? kAccent : kBlue),
              ),
            ),
            if (sync.isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
