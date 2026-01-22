import 'package:hive/hive.dart';

part 'sync_operation_model.g.dart';

@HiveType(typeId: 200) // Using a high ID to avoid conflicts
class SyncOperation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String table;

  @HiveField(2)
  final String action; // 'insert', 'update', 'delete', 'rpc'

  @HiveField(3)
  final Map<String, dynamic> payload;

  @HiveField(4)
  final DateTime timestamp;

  SyncOperation({
    required this.id,
    required this.table,
    required this.action,
    required this.payload,
    required this.timestamp,
  });
}
