import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/vibe.dart';

/// Persists one day-plan per weekday (1=Mon … 7=Sun) in SharedPreferences.
///
/// Only the most recent plan for each weekday is kept. When the user saves
/// a new plan on, say, Sunday, it replaces whatever was saved before.
/// The saved date is tracked but no data expires — it persists until overwritten.
class DayHistoryService {
  DayHistoryService._();
  static final instance = DayHistoryService._();

  static const _planPrefix = 'day_history_plan_';
  static const _datePrefix = 'day_history_date_';

  SharedPreferences? _prefs;

  void init(SharedPreferences prefs) => _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> save(int weekday, Map<RoutinePeriod, Vibe?> plan) async {
    final prefs = await _getPrefs();
    final filled = <String, dynamic>{};
    for (final entry in plan.entries) {
      if (entry.value != null) {
        filled[entry.key.name] = _vibeToJson(entry.value!);
      }
    }
    await prefs.setString('$_planPrefix$weekday', jsonEncode(filled));
    await prefs.setString(
        '$_datePrefix$weekday', DateTime.now().toIso8601String());
  }

  Future<Map<RoutinePeriod, Vibe>?> load(int weekday) async {
    final prefs = await _getPrefs();
    final planRaw = prefs.getString('$_planPrefix$weekday');
    if (planRaw == null) return null;

    final Map<String, dynamic> json = jsonDecode(planRaw);
    final result = <RoutinePeriod, Vibe>{};
    for (final entry in json.entries) {
      final period = RoutinePeriod.values.firstWhere((p) => p.name == entry.key,
          orElse: () => RoutinePeriod.morning);
      result[period] = _vibeFromJson(entry.value as Map<String, dynamic>);
    }
    return result.isEmpty ? null : result;
  }

  Map<String, dynamic> _vibeToJson(Vibe v) => {
        'emoji': v.emoji,
        'label': v.label,
        'color': v.color.toARGB32(),
      };

  Vibe _vibeFromJson(Map<String, dynamic> j) => Vibe(
        emoji: j['emoji'] as String,
        label: j['label'] as String,
        color: Color(j['color'] as int),
      );
}
