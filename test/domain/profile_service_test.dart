import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/profile_service.dart';

import '../support/in_memory_storage_repo.dart';

void main() {
  late InMemoryStorageRepo repo;
  late ProfileService service;

  setUp(() {
    repo = InMemoryStorageRepo();
    service = ProfileService(repo);
  });

  test('create persists a profile with a generated id', () async {
    final child = await service.create(displayName: 'Aiden', age: 5);
    expect(child.id, isNotEmpty);
    expect(await service.all(), hasLength(1));
    expect((await service.byId(child.id))?.displayName, 'Aiden');
  });

  test('create maps age to the right band and keeps the brief', () async {
    final child = await service.create(
      displayName: 'Mira',
      age: 9,
      parentBrief: 'kindness wins',
    );
    expect(child.ageBand, AgeBand.big);
    expect(child.parentBrief, 'kindness wins');
  });

  test('update and delete work', () async {
    final child = await service.create(displayName: 'Sam', age: 6);
    await service.update(child.copyWith(detailLevel: DetailLevel.long));
    expect((await service.byId(child.id))?.detailLevel, DetailLevel.long);

    await service.delete(child.id);
    expect(await service.all(), isEmpty);
  });
}
