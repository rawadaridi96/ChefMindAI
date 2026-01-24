import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generation_options_controller.g.dart';

@riverpod
class GenerationOptionsController extends _$GenerationOptionsController {
  @override
  GenerationOptionsState build() {
    return const GenerationOptionsState();
  }

  void setMealType(String? mealType) {
    state =
        state.copyWith(mealType: mealType, setMealTypeNull: mealType == null);
  }

  void setMood(String? mood) {
    state = state.copyWith(mood: mood, setMoodNull: mood == null);
  }

  void toggleFilter(String filter) {
    final currentFilters = List<String>.from(state.filters);
    if (currentFilters.contains(filter)) {
      currentFilters.remove(filter);
    } else {
      currentFilters.add(filter);
    }
    state = state.copyWith(filters: currentFilters);
  }

  void setFilters(List<String> filters) {
    state = state.copyWith(filters: filters);
  }

  void setAllergies(String? allergies) {
    state = state.copyWith(
        allergies: allergies, setAllergiesNull: allergies == null);
  }

  void setCuisine(String? cuisine) {
    state = state.copyWith(cuisine: cuisine, setCuisineNull: cuisine == null);
  }

  void setMaxTime(int? maxTime) {
    state = state.copyWith(maxTime: maxTime, setMaxTimeNull: maxTime == null);
  }

  void setSkillLevel(String? skillLevel) {
    state = state.copyWith(
        skillLevel: skillLevel, setSkillLevelNull: skillLevel == null);
  }

  void reset() {
    state = const GenerationOptionsState();
  }
}

class GenerationOptionsState {
  final String? mealType;
  final String? mood;
  final List<String> filters;
  final String? allergies;

  // New Fields
  final String? cuisine;
  final int? maxTime; // in minutes
  final String? skillLevel;

  const GenerationOptionsState({
    this.mealType,
    this.mood,
    this.filters = const [],
    this.allergies,
    this.cuisine,
    this.maxTime,
    this.skillLevel,
  });

  GenerationOptionsState copyWith({
    String? mealType,
    bool setMealTypeNull = false,
    String? mood,
    bool setMoodNull = false,
    List<String>? filters,
    String? allergies,
    bool setAllergiesNull = false,
    String? cuisine,
    bool setCuisineNull = false,
    int? maxTime,
    bool setMaxTimeNull = false,
    String? skillLevel,
    bool setSkillLevelNull = false,
  }) {
    return GenerationOptionsState(
      mealType: setMealTypeNull ? null : (mealType ?? this.mealType),
      mood: setMoodNull ? null : (mood ?? this.mood),
      filters: filters ?? this.filters,
      allergies: setAllergiesNull ? null : (allergies ?? this.allergies),
      cuisine: setCuisineNull ? null : (cuisine ?? this.cuisine),
      maxTime: setMaxTimeNull ? null : (maxTime ?? this.maxTime),
      skillLevel: setSkillLevelNull ? null : (skillLevel ?? this.skillLevel),
    );
  }
}
