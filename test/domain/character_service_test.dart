import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/character_service.dart';
import 'package:moonloom/domain/models/cast_changes.dart';
import 'package:moonloom/domain/models/world.dart';

import '../support/in_memory_storage_repo.dart';

void main() {
  late InMemoryStorageRepo repo;
  late CharacterService characters;

  const world = World(id: 'w1', childId: 'c1', name: 'Splat the Cat');

  setUp(() async {
    repo = InMemoryStorageRepo();
    await repo.saveWorld(world);
    characters = CharacterService(repo);
  });

  Future<World> reload() async => (await repo.loadWorldById(world.id))!;

  test('adding a character queues an introduction', () async {
    await characters.create(
      worldId: world.id,
      name: 'Pip',
      description: 'a small brave mouse',
    );
    final changes = (await reload()).pendingCastChanges;
    expect(changes.joined, ['Pip — a small brave mouse']);
    expect(changes.left, isEmpty);
  });

  test('removing a character queues a send-off', () async {
    final splat = await characters.create(
      worldId: world.id,
      name: 'Splat',
      description: 'a big black cat',
    );
    // Pretend a story has already introduced them.
    await repo.saveWorld(world);

    await characters.delete(splat);
    final changes = (await reload()).pendingCastChanges;
    expect(changes.left, ['Splat — a big black cat']);
    expect(await repo.loadCharacters(world.id), isEmpty);
  });

  test('a character added and removed before any story just goes', () async {
    final pip = await characters.create(worldId: world.id, name: 'Pip');
    await characters.delete(pip);
    // Nobody ever met Pip, so there is nobody to say goodbye to.
    expect((await reload()).pendingCastChanges.isEmpty, isTrue);
  });

  test('cast changes survive an encode/decode round-trip', () async {
    await characters.create(worldId: world.id, name: 'Pip');
    final encoded = (await reload()).pendingCastChanges.encode();
    expect(CastChanges.decode(encoded).joined, ['Pip']);
    expect(CastChanges.decode('not json').isEmpty, isTrue);
  });
}
