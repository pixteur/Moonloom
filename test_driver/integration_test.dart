/// Runs `integration_test/` through `flutter drive`, which — unlike
/// `flutter test` — can build the app in profile or release mode. That is the
/// point: a bug only the shortcut's release build shows cannot be caught by a
/// test that only ever runs debug.
///
///     flutter drive -d windows --release \
///       --driver=test_driver/integration_test.dart \
///       --target=integration_test/new_episode_real_test.dart
library;

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
