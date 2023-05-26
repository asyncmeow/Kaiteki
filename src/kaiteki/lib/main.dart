import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:kaiteki/account_manager.dart";
import "package:kaiteki/app.dart";
import "package:kaiteki/common.dart";
import "package:kaiteki/di.dart";
import "package:kaiteki/model/auth/account_key.dart";
import "package:kaiteki/model/auth/secret.dart";
import "package:kaiteki/repositories/hive_repository.dart";
import "package:kaiteki/theming/default/themes.dart";
import "package:kaiteki/ui/shared/crash_screen.dart";
import "package:logging/logging.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Main entrypoint.
Future<void> main() async {
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;

  final Widget app;

  try {
    WidgetsFlutterBinding.ensureInitialized();

    // initialize hive & account manager
    await initializeHive();
    final accountManager = await getAccountManager();

    // Initialize shared preferences
    final sharedPrefs = await SharedPreferences.getInstance();

    // construct app & run
    app = ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        accountManagerProvider.overrideWith((_) => accountManager),
      ],
      child: const KaitekiApp(),
    );
  } catch (e, s) {
    handleFatalError((e, s));
    return;
  }

  runApp(app);
}

void handleFatalError(TraceableError error) {
  final crashScreen = MaterialApp(
    theme: getDefaultTheme(Brightness.light, true),
    darkTheme: getDefaultTheme(Brightness.dark, true),
    home: CrashScreen(error),
  );
  runApp(crashScreen);
}

Future<void> initializeHive() async {
  if (Platform.isLinux && Platform.environment["FLATPAK_ID"] != null) {
    final directory = await getApplicationSupportDirectory();
    final path = p.join(directory.path, "kaiteki");

    Hive.init(path);
  } else {
    await Hive.initFlutter();
  }

  Hive
    ..registerAdapter(AccountKeyAdapter())
    ..registerAdapter(ClientSecretAdapter())
    ..registerAdapter(AccountSecretAdapter());
}

/// Initializes the account manager.
Future<AccountManager> getAccountManager() async {
  AccountKey fromHive(dynamic k) => AccountKey.fromUri(k as String);
  String toHive(AccountKey k) => k.toUri().toString();

  final accountBox = await Hive.openBox<AccountSecret>("accountSecrets");
  final accountRepository = HiveRepository<AccountSecret, AccountKey>(
    accountBox,
    fromHive,
    toHive,
    true,
  );

  final clientBox = await Hive.openBox<ClientSecret>("clientSecrets");
  final clientRepository = HiveRepository<ClientSecret, AccountKey>(
    clientBox,
    fromHive,
    toHive,
    true,
  );

  final manager = AccountManager(accountRepository, clientRepository);
  await manager.restoreSessions();
  return manager;
}
