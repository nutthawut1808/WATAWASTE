import 'package:intl/intl.dart';

/// A store's pickup window. The API sends instants as ISO-8601 UTC strings.
class PickupWindowModel {
  final DateTime start;
  final DateTime end;

  const PickupWindowModel({required this.start, required this.end});

  factory PickupWindowModel.fromJson(Map<String, dynamic> json) {
    final startStr = json['start'] as String? ?? '';
    final endStr = json['end'] as String? ?? '';

    return PickupWindowModel(
      // 1. เติม .toLocal() ทันทีที่ parse ข้อมูลจาก API เพื่อแปลง UTC -> Local Time
      start: startStr.isNotEmpty
          ? DateTime.parse(startStr).toLocal()
          : DateTime.now(),
      end: endStr.isNotEmpty
          ? DateTime.parse(endStr).toLocal()
          : DateTime.now(),
    );
  }

  /// Human readable label, e.g. "06:00 – 09:30".
  String get label =>
      '${DateFormat('HH:mm').format(start.toLocal())} – ${DateFormat('HH:mm').format(end.toLocal())}';

  /// Whether pickup starts today (เปรียบเทียบทั้ง Year, Month, และ Day ใน Local Time).
  bool get isToday {
    final now = DateTime.now();
    final localStart = start.toLocal();
    return localStart.year == now.year &&
        localStart.month == now.month &&
        localStart.day == now.day;
  }

  /// Whether the store is currently accepting pickups.
  bool get isOpenNow {
    final now = DateTime.now();
    return now.isAfter(start.toLocal()) && now.isBefore(end.toLocal());
  }

  Duration get untilStart => start.toLocal().difference(DateTime.now());
}