import 'package:flutter/material.dart';

enum RoutinePeriod { morning, afternoon, evening, night }

class Activity {
  final String id;
  final String title;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final RoutinePeriod? period;
  final String emoji;
  final Color color;
  final DateTime date;
  final String? photoUrl;
  final bool isLive;
  final DateTime? endsAt;

  const Activity({
    required this.id,
    required this.title,
    this.startTime,
    this.endTime,
    this.period,
    required this.emoji,
    required this.color,
    required this.date,
    this.photoUrl,
    this.isLive = false,
    this.endsAt,
  });

  bool get isExpired => endsAt != null && endsAt!.isBefore(DateTime.now());

  String get endsAtLabel {
    if (endsAt == null) return '';
    final remaining = endsAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'encerrado';
    if (remaining.inMinutes < 10) return 'acaba em ${remaining.inMinutes}min';
    return 'até ${endsAt!.hour.toString().padLeft(2, '0')}:${endsAt!.minute.toString().padLeft(2, '0')}';
  }

  bool get isActiveNow {
    final now = DateTime.now();

    if (startTime != null && endTime != null) {
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        startTime!.hour,
        startTime!.minute,
      );
      final end = DateTime(
        now.year,
        now.month,
        now.day,
        endTime!.hour,
        endTime!.minute,
      );
      return now.isAfter(start) && now.isBefore(end);
    }

    if (period != null) {
      final hour = now.hour;
      switch (period!) {
        case RoutinePeriod.morning:
          return hour >= 6 && hour < 12;
        case RoutinePeriod.afternoon:
          return hour >= 12 && hour < 18;
        case RoutinePeriod.evening:
          return hour >= 18 && hour < 22;
        case RoutinePeriod.night:
          return hour >= 22 || hour < 6;
      }
    }

    return false;
  }
}
