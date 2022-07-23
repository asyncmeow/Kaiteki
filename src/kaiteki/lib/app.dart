import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:kaiteki/constants.dart' as consts;
import 'package:kaiteki/di.dart';
import 'package:kaiteki/fediverse/adapter.dart';
import 'package:kaiteki/fediverse/model/post.dart';
import 'package:kaiteki/fediverse/model/user.dart';
import 'package:kaiteki/theming/default/themes.dart';
import 'package:kaiteki/ui/account_required_screen.dart';
import 'package:kaiteki/ui/auth/discover_instances/discover_instances_screen.dart';
import 'package:kaiteki/ui/auth/login/login_screen.dart';
import 'package:kaiteki/ui/main/main_screen.dart';
import 'package:kaiteki/ui/settings/about/about_screen.dart';
import 'package:kaiteki/ui/settings/credits_screen.dart';
import 'package:kaiteki/ui/settings/customization/customization_settings_screen.dart';
import 'package:kaiteki/ui/settings/debug/theme_screen.dart';
import 'package:kaiteki/ui/settings/debug_screen.dart';
import 'package:kaiteki/ui/settings/filtering/filtering_screen.dart';
import 'package:kaiteki/ui/settings/filtering/sensitive_post_filtering_screen.dart';
import 'package:kaiteki/ui/settings/settings_screen.dart';
import 'package:kaiteki/ui/shared/conversation_screen.dart';
import 'package:kaiteki/ui/shortcuts/activators.dart';
import 'package:kaiteki/ui/shortcuts/intents.dart';
import 'package:kaiteki/ui/user/user_screen.dart';

class KaitekiApp extends ConsumerWidget {
  late final GoRouter _router = GoRouter(
    navigatorBuilder: _buildNavigator,
    routes: [
      GoRoute(path: "/", builder: _buildMainRoute),
      GoRoute(path: "/about", builder: (_, __) => const AboutScreen()),
      GoRoute(
        path: "/settings",
        builder: (_, __) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: "customization",
            builder: (_, __) => const CustomizationSettingsScreen(),
          ),
          GoRoute(
            path: "filtering",
            builder: (_, __) => const FilteringScreen(),
            routes: [
              GoRoute(
                path: "sensitivePosts",
                builder: (_, __) => const SensitivePostFilteringScreen(),
              ),
            ],
          ),
          GoRoute(
            path: "debug",
            builder: (_, __) => const DebugScreen(),
            routes: [
              GoRoute(
                path: "theme",
                builder: (_, __) => const ThemeScreen(),
              )
            ],
          ),
        ],
      ),
      GoRoute(path: "/login", builder: (_, __) => const LoginScreen()),
      GoRoute(path: "/credits", builder: (_, __) => const CreditsScreen()),
      GoRoute(
        path: "/discover-instances",
        builder: (_, __) => const DiscoverInstancesScreen(),
      ),
      GoRoute(
        name: "authenticated",
        path: "/@:accountUsername@:accountHost",
        builder: (_, __) => const MainScreen(),
        routes: [
          GoRoute(path: "home", builder: (_, __) => const MainScreen()),
          GoRoute(
            path: "users/:id",
            builder: (context, state) {
              if (state.extra == null) {
                return UserScreen.fromId(state.params["id"]!);
              } else {
                return UserScreen.fromUser(state.extra! as User);
              }
            },
          ),
          GoRoute(
            path: "posts/:id",
            builder: (context, state) {
              return ConversationScreen(state.extra! as Post);
            },
          ),
        ],
      ),
    ],
  );

  Widget _buildNavigator(context, state, child) {
    return Consumer(
      child: child,
      builder: (context, ref, child) {
        final FediverseAdapter? adapter;

        final user = state.params["accountUsername"];
        final host = state.params["accountHost"];

        if (user != null && host != null) {
          adapter = ref.watch(
            accountProvider.select(
              (manager) => manager.accounts
                  .firstWhere(
                    (account) =>
                        account.key.username == user &&
                        account.key.host == host,
                  )
                  .adapter,
            ),
          );
        } else {
          final accountManager = ref.watch(accountProvider);
          adapter = accountManager.loggedIn ? accountManager.adapter : null;
        }
        if (adapter != null) {
          return ProviderScope(
            overrides: [adapterProvider.overrideWithValue(adapter)],
            child: child!,
          );
        } else {
          return child!;
        }
      },
    );
  }

  KaitekiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreferences = ref.watch(themeProvider);
    final m3 =
        themePreferences.useMaterial3 ?? themePreferences.material3Default;
    return MaterialApp.router(
      darkTheme: getTheme(Brightness.dark, m3),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routeInformationParser: _router.routeInformationParser,
      routerDelegate: _router.routerDelegate,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: getTheme(Brightness.light, m3),
      themeMode: themePreferences.mode,
      title: consts.appName,
      shortcuts: <ShortcutActivator, Intent>{
        ...WidgetsApp.defaultShortcuts,
        refresh: const RefreshIntent(),
        refresh2: const RefreshIntent(),
        refresh3: const RefreshIntent(),
        shortcutsHelp: const ShortcutsHelpIntent(),
        gotoHome: const GoToAppLocationIntent(AppLocation.home),
        gotoSettings: const GoToAppLocationIntent(AppLocation.settings),
        gotoBookmarks: const GoToAppLocationIntent(AppLocation.bookmarks),
        gotoNotifications:
            const GoToAppLocationIntent(AppLocation.notifications),
        newPost: const NewPostIntent(),
      },
    );
  }

  Widget _buildMainRoute(BuildContext context, state) {
    return Consumer(
      builder: (context, ref, child) {
        return ref.watch(accountProvider).loggedIn
            ? const MainScreen()
            : const AccountRequiredScreen();
      },
    );
  }
}
