import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bloc/game_bloc.dart';
import 'bloc/settings_cubit.dart';
import 'core/constants.dart';
import 'core/session_storage.dart';
import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'data/repositories/api_repository.dart';
import 'data/repositories/socket_repository.dart';
import 'data/repositories/supabase_repository.dart';
import 'data/services/heartbeat_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/username_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file before anything else
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const CallbreakApp());
}

class CallbreakApp extends StatelessWidget {
  const CallbreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiRepository>(
          create: (_) => ApiRepository(baseUrl: kHttpBaseUrl),
        ),
        RepositoryProvider<SocketRepository>(
          create: (_) => SocketRepository(wsBaseUrl: kWsBaseUrl),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>(
            create: (context) => SettingsCubit(),
          ),
          BlocProvider<GameBloc>(
            create: (context) => GameBloc(
              apiRepository: context.read<ApiRepository>(),
              socketRepository: context.read<SocketRepository>(),
              sessionStorage: SessionStorage(),
            ),
          ),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          title: 'Callbreak',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Routes users based on their authentication state.
///
/// - If the user is signed in with Supabase → show [HomeScreen] + start heartbeat.
/// - If not signed in → show [LoginScreen] + stop heartbeat.
///
/// The [StreamBuilder] reacts instantly to sign-in and sign-out events,
/// so navigating between the two screens is automatic.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _heartbeat = HeartbeatService();

  @override
  void dispose() {
    _heartbeat.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show a loading indicator while we wait for the initial auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF080B14),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }

        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          // Authenticated — start heartbeat and check profile
          if (!_heartbeat.isRunning) _heartbeat.start();
          return const _ProfileGate();
        } else {
          // Not authenticated — stop heartbeat and show login
          _heartbeat.stop();
          return const LoginScreen();
        }
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate();

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  final _repository = SupabaseRepository();
  bool _isLoading = true;
  bool _needsUsername = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    try {
      final profile = await _repository.getMyProfile();
      if (mounted) {
        setState(() {
          _needsUsername = profile == null || profile.username.startsWith('pending_');
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _needsUsername = true; // Fallback to asking username
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF080B14),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }
    if (_needsUsername) {
      return const UsernameScreen();
    }
    return const HomeScreen();
  }
}
