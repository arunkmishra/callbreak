import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/game_bloc.dart';
import 'bloc/settings_cubit.dart';
import 'core/constants.dart';
import 'core/session_storage.dart';
import 'core/theme.dart';
import 'data/repositories/api_repository.dart';
import 'data/repositories/socket_repository.dart';
import 'ui/screens/home_screen.dart';

import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const CallbreakApp());
  });
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
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
