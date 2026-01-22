import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../auth/presentation/auth_state_provider.dart';
import '../data/household_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'household_controller.g.dart';

final householdMembersProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final householdState = ref.watch(householdControllerProvider);

  return householdState.when(
    data: (household) {
      if (household == null) return const Stream.empty();
      final id = household['id'] as String;
      return ref.read(householdRepositoryProvider).getMembersStream(id);
    },
    error: (err, st) => const Stream.empty(),
    loading: () => const Stream.empty(),
  );
});

@Riverpod(keepAlive: true)
class HouseholdController extends _$HouseholdController {
  @override
  Stream<Map<String, dynamic>?> build() async* {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      yield null;
      return;
    }

    // We need to merge two sources of truth:
    // 1. Profile changes (my household_id changed)
    // 2. Household changes (the household itself was deleted)

    final profileStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .map((event) {
          print("DEBUG: Profile Stream Event: $event");
          return event.firstOrNull;
        });

    // We can't easily merge dynamic streams in a simple async generator without rxdart.
    // Instead, we will rely on the Profile stream as the driver,
    // BUT we will also periodically check or setup a separate listener if possible.
    // simpler approach: The repository method 'getHousehold' checks existence.

    // We can't easily merge dynamic streams in a simple async generator without rxdart.
    // Instead, we will rely on the Profile stream as the driver,
    // BUT we will also periodically check or setup a separate listener if possible.
    // simpler approach: The repository method 'getHousehold' checks existence.

    // Cached Data Fallback (Offline First)
    final box = Hive.box('app_prefs');
    final cachedData = box.get('household_data');
    if (cachedData != null) {
      try {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(cachedData as Map);
        yield data;
      } catch (e) {
        print("Error reading cached household data: $e");
      }
    }

    try {
      await for (final profile in profileStream) {
        print("DEBUG: Profile Update: $profile");
        if (profile == null) {
          // If profile is null (logged out?), clear cache
          if (cachedData != null) {
            await box.delete('household_data');
          }
          yield null;
          continue;
        }

        final householdId = profile['household_id'] as String?;

        if (householdId == null) {
          if (cachedData != null) {
            await box.delete('household_data');
          }
          yield null;
        } else {
          try {
            final household = await ref
                .read(householdRepositoryProvider)
                .getHousehold(householdId);

            if (household == null) {
              // Zombie state
              await box.delete('household_data');
              yield null;
            } else {
              // Update Cache
              await box.put('household_data', household);
              yield household;
            }
          } catch (e) {
            // Network error likely.
            print("Error fetching household details (likely offline): $e");
          }
        }
      }
    } catch (e) {
      // Catch RealtimeSubscribeException or others when offline
      print("Stream Error (likely offline): $e");
      // If we are offline and stream fails, we effectively just stop listening.
      // The cached value (yielded above) remains the state.
      // We could set up a periodic retry or listen to connectivity,
      // but usually the build() method rebuilds on provider invalidation if managed externally,
      // OR we just rely on the fact that when online, the controller might need refreshing.
      // ACTUALLY: The OfflineManager listens to connectivity.
      // But this controller is a Stream.
      // If we exit the stream loop, the stream closes.
      // We should probably just hang/await indefinitely if we have cache,
      // or return. Ensuring we don't throw is key.
    }
  }

  // Note: True realtime deletion detection (without profile update)
  // would require a separate stream listening to 'household_unit'.
  // However, checking existence on every profile update + the 'invalidate' pattern
  // is usually enough. If the user wants INSTANT kick-out on deletion:
  // We can subscribe to the household channel in the UI or here.
  // Given the complexity, the above "check existence" covers the "Zombie" case
  // where you restart the app or profile updates weirdly.

  // To truly fix the "Event Lost" issue:
  // We can't easily do it inside this single-stream generator.
  // We will stick to the Profile driver for now, as the Replica Identity fix
  // should have resolved the root cause. If it didn't, it might be a network race.

  // Create
  Future<void> createHousehold(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final id =
          await ref.read(householdRepositoryProvider).createHousehold(name);
      return {'id': id, 'name': name}; // Optimistic / Result
    });
  }

  // Join
  Future<void> joinHousehold(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(householdRepositoryProvider).joinHousehold(code);
      // Invalidate self to force a fresh fetch from DB (getMyHousehold)
      // This ensures we get the EXACT same data shape as build() expects,
      // and triggers any watchers looking at the future.
      ref.invalidateSelf();

      // We return the future so the UI waits for the reload
      return await future;
    });
  }

  // Leave
  Future<void> leaveHousehold() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(householdRepositoryProvider).leaveHousehold();
      return null;
    });
  }

  // Delete
  Future<void> deleteHousehold(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(householdRepositoryProvider).deleteHousehold(id);
      return null;
    });
  }
}
