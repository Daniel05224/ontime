import 'package:flutter_test/flutter_test.dart';

import 'package:ontime/data/repositories/routine_repository.dart';
import 'package:ontime/data/services/routine_local_service.dart';

void main() {
  test('friends mock data is loaded', () {
    final repository = RoutineRepository(localService: RoutineLocalService());
    expect(repository.friends.length, 5);
  });
}
