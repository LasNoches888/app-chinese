import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/repositories/dialogue_repository.dart';

/// "Следующий диалог" used to be able to hand back the dialogue that was
/// just finished, which reads as the button not working at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DialogueRepository repo;

  setUpAll(() async {
    repo = await DialogueRepository.load();
  });

  test('random() never returns the dialogue it was told to exclude', () {
    final current = repo.all.first;
    // Random, so one draw proves nothing — over many draws the excluded
    // one must never come up.
    for (var i = 0; i < 200; i++) {
      expect(repo.random(excludingId: current.id).id, isNot(current.id));
    }
  });

  test('random() still returns something when everything is excluded', () {
    final single = DialogueRepository.forTest([repo.all.first]);
    expect(single.random(excludingId: repo.all.first.id).id, repo.all.first.id);
  });

  test('random() without an exclusion can return any dialogue', () {
    final seen = <String>{};
    for (var i = 0; i < 500; i++) {
      seen.add(repo.random().id);
    }
    expect(seen.length, greaterThan(1));
  });
}
