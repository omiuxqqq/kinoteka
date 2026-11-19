import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_logger.dart';
import 'data/repositories/movie_repository.dart';
import 'data/sources/movie_local_ds.dart';
import 'data/sources/movie_remote_ds.dart';
import 'services/notification_service.dart';
import 'ui/screens/home_screen.dart';
import 'viewmodels/movie_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.instance.i('Запуск приложения Кинотека');

  final notificationService = NotificationService();
  await notificationService.init();

  final repository = MovieRepositoryImpl(
    localDataSource: MovieLocalDataSource(),
    remoteDataSource: MovieRemoteDataSource(),
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider(
          create: (_) =>
              MovieViewModel(repository: repository)..loadLocalMovies(),
        ),
      ],
      child: const KinotekaApp(),
    ),
  );
}

class KinotekaApp extends StatelessWidget {
  const KinotekaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Кинотека',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}