import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/config/config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/groups/create_group_screen.dart';
import 'screens/groups/create_tournament_screen.dart';
import 'screens/groups/custom_group_screen.dart';
import 'screens/groups/league_detail_screen.dart';
import 'screens/groups/tournament_detail_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/main_screen.dart';
import 'screens/match/match_detail_screen.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // EnvConfig + Supabase muszą być przed AuthBloc (szybkie — lokalny config)
  await EnvConfig.initialize();
  await SupabaseConfig.initialize();

  // MobileAds inicjalizuje się w tle w SplashScreen — nie blokuje runApp()

  runApp(const TyperlyApp());
}

class TyperlyApp extends StatelessWidget {
  const TyperlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(AuthRepository())..add(AuthCheckRequested()),
        ),
      ],
      child: MaterialApp(
        title: EnvConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/main': (context) => const MainScreen(),
          '/create-group': (context) => const CreateGroupScreen(),
          '/custom-group': (context) => const CustomGroupScreen(),
          '/league-detail': (context) => const LeagueDetailScreen(),
          '/create-tournament': (context) => const CreateTournamentScreen(),
          '/tournament-detail': (context) => const TournamentDetailScreen(),
          '/leaderboard': (context) => const LeaderboardScreen(),
          '/match-detail': (context) => const MatchDetailScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle dynamic routes with arguments
          if (settings.name == '/match-detail') {
            final match = settings.arguments;
            return MaterialPageRoute(
              builder: (context) => MatchDetailScreen(),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }
}
