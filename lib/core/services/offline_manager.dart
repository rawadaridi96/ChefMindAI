import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/pantry/data/models/pantry_item_model.dart';
import '../../features/shopping/data/models/shopping_item_model.dart';
import '../../features/recipes/data/models/saved_recipe_model.dart';
import '../../features/meal_plan/data/models/meal_plan_model.dart';
import 'sync_queue_service.dart';

part 'offline_manager.g.dart';

@Riverpod(keepAlive: true)
OfflineManager offlineManager(OfflineManagerRef ref) {
  return OfflineManager(ref.read(syncQueueServiceProvider));
}

class OfflineManager {
  final SyncQueueService _syncQueueService;
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController =
      StreamController.broadcast();

  OfflineManager(this._syncQueueService);

  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;

  Stream<bool> get connectionStream => _connectionChangeController.stream;

  Future<void> init() async {
    // Initialize Hive
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(PantryItemModelAdapter());
    Hive.registerAdapter(ShoppingItemModelAdapter());
    Hive.registerAdapter(SavedRecipeModelAdapter());
    Hive.registerAdapter(MealPlanModelAdapter());

    // Initialize Sync Queue
    await _syncQueueService.init();

    // Open Boxes (Pre-load them)
    await Hive.openBox<PantryItemModel>('pantry_items');
    await Hive.openBox<ShoppingItemModel>('shopping_items');
    await Hive.openBox<SavedRecipeModel>('saved_recipes');
    await Hive.openBox<MealPlanModel>('meal_plan_box');
    await Hive.openBox('app_prefs');

    // Check initial connection
    _hasConnection = await _checkConnection();
    if (_hasConnection) {
      _syncQueueService.processQueue();
    }

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((results) async {
      print("DEBUG OfflineManager: Connectivity changed: $results");
      final wasConnected = _hasConnection;
      _hasConnection = await _checkConnection();
      print(
          "DEBUG OfflineManager: wasConnected=$wasConnected, nowConnected=$_hasConnection");
      _connectionChangeController.add(_hasConnection);

      // Always process queue when we detect we're online
      // (Fallback for unreliable wasConnected state tracking)
      if (_hasConnection) {
        print(
            "DEBUG OfflineManager: Online detected, processing queue silently...");
        await _syncQueueService.processQueue();
      }
    });
  }

  Future<bool> _checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      return false;
    }
    // We could add a more robust internet check here if needed
    // (e.g. pinging google.com) via internet_connection_checker
    return true;
  }
}
