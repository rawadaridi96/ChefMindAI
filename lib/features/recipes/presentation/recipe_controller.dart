import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../subscription/presentation/subscription_controller.dart';
import '../../../core/exceptions/premium_limit_exception.dart';

part 'recipe_controller.g.dart';

@riverpod
class RecipeController extends _$RecipeController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() {
    return []; // Initially empty list of recipes
  }

  Future<void> generate({
    required String mode,
    String? query,
    List<String>? filters,
    String? mealType,
    String? allergies,
    bool includeGlobalDiet = false,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      final prefs = await SharedPreferences.getInstance();
      bool isGuest = user == null || user.isAnonymous;
      int guestGenCount = prefs.getInt('guest_gen_count') ?? 0;

      // Fetch tier early for feature gating
      SubscriptionTier currentTier = SubscriptionTier.homeCook;
      if (!isGuest) {
        currentTier = await ref.read(subscriptionControllerProvider.future);
      }

      // Handle Global Dietary Preferences
      String? finalAllergies = allergies;

      if (includeGlobalDiet && user != null && !isGuest) {
        // Enforce ADI Restriction
        if (currentTier == SubscriptionTier.homeCook) {
          throw PremiumLimitReachedException(
            "Advanced Dietary Intelligence requires a Sous Chef plan.",
            "Advanced Intelligence",
          );
        }

        final userMetadata = user.userMetadata;
        final dietaryPrefs = userMetadata?['dietary_preferences'];

        if (dietaryPrefs != null &&
            dietaryPrefs is List &&
            dietaryPrefs.isNotEmpty) {
          final globalPrefsString = dietaryPrefs.join(", ");
          if (finalAllergies != null && finalAllergies.isNotEmpty) {
            finalAllergies = "$finalAllergies, $globalPrefsString";
          } else {
            finalAllergies = globalPrefsString;
          }
        }
      }

      // Enforce Subscription Limits BEFORE generation
      int dailyCount = 0;
      if (!isGuest) {
        // Tier already fetched above

        final today = DateTime.now().toIso8601String().split('T')[0];
        final lastGenDate = prefs.getString('gen_date') ?? '';
        dailyCount = prefs.getInt('daily_gen_count') ?? 0;

        if (lastGenDate != today) {
          dailyCount = 0;
          await prefs.setString('gen_date', today);
          await prefs.setInt('daily_gen_count', 0);
        }

        final limit = (currentTier == SubscriptionTier.sousChef ||
                currentTier == SubscriptionTier.executiveChef)
            ? 2147483647
            : ref
                .read(subscriptionControllerProvider.notifier)
                .dailyRecipeGenerationLimit;

        if (dailyCount >= limit) {
          throw PremiumLimitReachedException(
            "You've reached your daily limit of $limit recipes.",
            "Daily Recipe Limit",
          );
        }
      }

      final recipes = await ref.read(recipeRepositoryProvider).generateRecipes(
            mode: mode,
            query: query,
            filters: filters,
            mealType: mealType,
            allergies: finalAllergies,
          );

      if (isGuest) {
        if (guestGenCount >= 1) {
          // Lock the recipes
          return recipes.map((r) => {...r, 'is_locked': true}).toList();
        }
        await prefs.setInt('guest_gen_count', guestGenCount + 1);
      } else {
        // Increment usage only after successful generation
        await prefs.setInt('daily_gen_count', dailyCount + 1);
      }

      return recipes;
    });
  }

  Future<Map<String, dynamic>> consultChef(
      String question, String contextRecipe) {
    return ref.read(recipeRepositoryProvider).consultChef(
          question: question,
          contextRecipe: contextRecipe,
        );
  }

  Future<void> updateRecipe(int id, Map<String, dynamic> updates) async {
    await ref.read(recipeRepositoryProvider).updateRecipe(id, updates);
    // Optionally refresh list
    // ref.refresh(recipeControllerProvider);
  }
}
