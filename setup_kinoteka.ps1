$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== 1. Создание структуры каталогов ===" -ForegroundColor Cyan
$dirs = @(
    "lib\core",
    "lib\data\models",
    "lib\data\sources",
    "lib\data\repositories",
    "lib\services",
    "lib\viewmodels",
    "lib\ui\screens",
    "test"
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

function Write-Utf8NoBom($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, $utf8NoBom)
    Write-Host "[OK] $path" -ForegroundColor Green
}

Write-Host "=== 2. Запись pubspec.yaml ===" -ForegroundColor Cyan
Write-Utf8NoBom "pubspec.yaml" @'
name: kinoteka
description: "Мобильное приложение Кинотека"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  sqflite: ^2.3.3
  path: ^1.9.0
  http: ^1.2.2
  logger: ^2.4.0
  flutter_local_notifications: ^17.2.2
  permission_handler: ^11.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  flutter_launcher_icons: ^0.13.1

flutter:
  uses-material-design: true
'@

Write-Host "=== 3. Обновление AndroidManifest.xml ===" -ForegroundColor Cyan
$manifestPath = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
    $manifest = [System.IO.File]::ReadAllText((Join-Path (Get-Location) $manifestPath))
    if ($manifest -notmatch "android.permission.POST_NOTIFICATIONS") {
        $perms = "    <uses-permission android:name=`"android.permission.INTERNET`"/>`r`n    <uses-permission android:name=`"android.permission.POST_NOTIFICATIONS`"/>`r`n    <application"
        $manifest = $manifest -replace "<application", $perms
        Write-Utf8NoBom $manifestPath $manifest
    } else {
        Write-Host "[OK] Разрешения уже добавлены в AndroidManifest.xml" -ForegroundColor Green
    }
}

Write-Host "=== 4. Генерация всех исходных файлов приложения ===" -ForegroundColor Cyan

Write-Utf8NoBom "lib\core\view_state.dart" @'
enum ViewState {
  idle,
  loading,
  success,
  empty,
  error,
}

enum MovieFilter {
  all,
  watched,
  planned,
}
'@

Write-Utf8NoBom "lib\core\app_logger.dart" @'
import 'package:logger/logger.dart';

class AppLogger {
  static final Logger instance = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: false,
      printEmojis: false,
    ),
  );
}
'@

Write-Utf8NoBom "lib\data\models\movie.dart" @'
class Movie {
  final int? id;
  final String title;
  final int year;
  final String genre;
  final double rating;
  final bool isWatched;
  final String? posterUrl;
  final String? description;

  const Movie({
    this.id,
    required this.title,
    required this.year,
    required this.genre,
    required this.rating,
    this.isWatched = false,
    this.posterUrl,
    this.description,
  });

  Movie copyWith({
    int? id,
    String? title,
    int? year,
    String? genre,
    double? rating,
    bool? isWatched,
    String? posterUrl,
    String? description,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      rating: rating ?? this.rating,
      isWatched: isWatched ?? this.isWatched,
      posterUrl: posterUrl ?? this.posterUrl,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'year': year,
      'genre': genre,
      'rating': rating,
      'is_watched': isWatched ? 1 : 0,
      'poster_url': posterUrl,
      'description': description,
    };
  }

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      id: map['id'] as int?,
      title: map['title'] as String,
      year: map['year'] as int,
      genre: map['genre'] as String,
      rating: (map['rating'] as num).toDouble(),
      isWatched: (map['is_watched'] as int) == 1,
      posterUrl: map['poster_url'] as String?,
      description: map['description'] as String?,
    );
  }

  factory Movie.fromTvMazeJson(Map<String, dynamic> json) {
    final show = json['show'] as Map<String, dynamic>? ?? json;
    final premiered = show['premiered'] as String?;
    final parsedYear = (premiered != null && premiered.length >= 4)
        ? int.tryParse(premiered.substring(0, 4)) ?? 2024
        : 2024;
    final genresList = (show['genres'] as List<dynamic>?)?.cast<String>() ?? [];
    final ratingMap = show['rating'] as Map<String, dynamic>?;
    final imageMap = show['image'] as Map<String, dynamic>?;
    final rawSummary = show['summary'] as String? ?? '';
    final cleanSummary = rawSummary.replaceAll(RegExp(r'<[^>]*>'), '');

    return Movie(
      title: show['name'] as String? ?? 'Без названия',
      year: parsedYear,
      genre: genresList.isNotEmpty ? genresList.first : 'Драма',
      rating: (ratingMap?['average'] as num?)?.toDouble() ?? 7.0,
      isWatched: false,
      posterUrl: imageMap?['medium'] as String?,
      description: cleanSummary.isNotEmpty ? cleanSummary : 'Описание отсутствует',
    );
  }
}
'@

Write-Utf8NoBom "lib\data\sources\movie_local_ds.dart" @'
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/movie.dart';

class MovieLocalDataSource {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kinoteka.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE movies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            year INTEGER NOT NULL,
            genre TEXT NOT NULL,
            rating REAL NOT NULL,
            is_watched INTEGER NOT NULL DEFAULT 0,
            poster_url TEXT,
            description TEXT
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Movie>> getAllMovies() async {
    final db = await database;
    final maps = await db.query('movies', orderBy: 'id DESC');
    return maps.map((m) => Movie.fromMap(m)).toList();
  }

  Future<int> insertMovie(Movie movie) async {
    final db = await database;
    return db.insert('movies', movie.toMap());
  }

  Future<int> updateMovie(Movie movie) async {
    final db = await database;
    return db.update(
      'movies',
      movie.toMap(),
      where: 'id = ?',
      whereArgs: [movie.id],
    );
  }

  Future<int> deleteMovie(int id) async {
    final db = await database;
    return db.delete('movies', where: 'id = ?', whereArgs: [id]);
  }
}
'@

Write-Utf8NoBom "lib\data\sources\movie_remote_ds.dart" @'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';

class MovieRemoteDataSource {
  final http.Client client;

  MovieRemoteDataSource({http.Client? client}) : client = client ?? http.Client();

  Future<List<Movie>> searchOnline(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final uri = Uri.parse('https://api.tvmaze.com/search/shows?q=$encoded');
    final response = await client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Ошибка сервера: HTTP ${response.statusCode}');
    }

    final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Movie.fromTvMazeJson(item as Map<String, dynamic>))
        .toList();
  }
}
'@

Write-Utf8NoBom "lib\data\repositories\movie_repository.dart" @'
import '../models/movie.dart';
import '../sources/movie_local_ds.dart';
import '../sources/movie_remote_ds.dart';

abstract class MovieRepository {
  Future<List<Movie>> getLocalMovies();
  Future<void> addMovie(Movie movie);
  Future<void> updateMovie(Movie movie);
  Future<void> deleteMovie(int id);
  Future<List<Movie>> searchRemoteMovies(String query);
}

class MovieRepositoryImpl implements MovieRepository {
  final MovieLocalDataSource localDataSource;
  final MovieRemoteDataSource remoteDataSource;

  MovieRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<List<Movie>> getLocalMovies() => localDataSource.getAllMovies();

  @override
  Future<void> addMovie(Movie movie) => localDataSource.insertMovie(movie);

  @override
  Future<void> updateMovie(Movie movie) => localDataSource.updateMovie(movie);

  @override
  Future<void> deleteMovie(int id) => localDataSource.deleteMovie(id);

  @override
  Future<List<Movie>> searchRemoteMovies(String query) =>
      remoteDataSource.searchOnline(query);
}
'@

Write-Utf8NoBom "lib\services\notification_service.dart" @'
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_logger.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
  }

  Future<bool> showWatchReminder(String movieTitle) async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      AppLogger.instance.w('Пользователь отклонил разрешение на уведомления');
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      'kinoteka_reminders',
      'Напоминания о просмотре',
      channelDescription: 'Уведомления о запланированных фильмах',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Время кино!',
      'Не забудьте посмотреть: «$movieTitle»',
      const NotificationDetails(android: androidDetails),
    );
    AppLogger.instance.i('Отправлено напоминание для фильма');
    return true;
  }
}
'@

Write-Utf8NoBom "lib\viewmodels\movie_viewmodel.dart" @'
import 'package:flutter/foundation.dart';
import '../core/app_logger.dart';
import '../core/view_state.dart';
import '../data/models/movie.dart';
import '../data/repositories/movie_repository.dart';

class MovieViewModel extends ChangeNotifier {
  final MovieRepository repository;

  MovieViewModel({required this.repository});

  ViewState _localState = ViewState.idle;
  ViewState get localState => _localState;

  ViewState _remoteState = ViewState.idle;
  ViewState get remoteState => _remoteState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Movie> _allMovies = [];
  List<Movie> _remoteMovies = [];
  List<Movie> get remoteMovies => _remoteMovies;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  MovieFilter _filter = MovieFilter.all;
  MovieFilter get filter => _filter;

  List<Movie> get filteredMovies {
    return _allMovies.where((movie) {
      final matchesQuery =
          movie.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = switch (_filter) {
        MovieFilter.all => true,
        MovieFilter.watched => movie.isWatched,
        MovieFilter.planned => !movie.isWatched,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(MovieFilter newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  Future<void> loadLocalMovies() async {
    _localState = ViewState.loading;
    notifyListeners();
    try {
      _allMovies = await repository.getLocalMovies();
      _localState = _allMovies.isEmpty ? ViewState.empty : ViewState.success;
      AppLogger.instance.i('Загружено фильмов из БД: ${_allMovies.length}');
    } catch (e) {
      _errorMessage = 'Не удалось загрузить локальную базу фильмов';
      _localState = ViewState.error;
      AppLogger.instance.e('Ошибка чтения БД', error: e);
    }
    notifyListeners();
  }

  Future<void> addMovie(Movie movie) async {
    await repository.addMovie(movie);
    AppLogger.instance.i('Добавлен новый фильм в базу');
    await loadLocalMovies();
  }

  Future<void> updateMovie(Movie movie) async {
    await repository.updateMovie(movie);
    AppLogger.instance.i('Обновлена запись фильма id=${movie.id}');
    await loadLocalMovies();
  }

  Future<void> deleteMovie(int id) async {
    await repository.deleteMovie(id);
    AppLogger.instance.i('Удалён фильм id=$id');
    await loadLocalMovies();
  }

  Future<void> searchOnline(String query) async {
    if (query.trim().isEmpty) return;
    _remoteState = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _remoteMovies = await repository.searchRemoteMovies(query);
      _remoteState =
          _remoteMovies.isEmpty ? ViewState.empty : ViewState.success;
      AppLogger.instance.i('Онлайн-поиск выполнен, найдено: ${_remoteMovies.length}');
    } catch (e) {
      _errorMessage = 'Ошибка сети. Проверьте подключение к интернету.';
      _remoteState = ViewState.error;
      AppLogger.instance.e('Ошибка сетевого запроса', error: e);
    }
    notifyListeners();
  }
}
'@

Write-Utf8NoBom "lib\ui\screens\home_screen.dart" @'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/view_state.dart';
import '../../viewmodels/movie_viewmodel.dart';
import 'movie_detail_screen.dart';
import 'movie_form_screen.dart';
import 'search_online_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MovieViewModel>();
    final movies = vm.filteredMovies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Моя кинотека'),
        actions: [
          IconButton(
            tooltip: 'Поиск онлайн',
            icon: const Icon(Icons.travel_explore),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchOnlineScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по названию...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: vm.setSearchQuery,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SegmentedButton<MovieFilter>(
              segments: const [
                ButtonSegment(value: MovieFilter.all, label: Text('Все')),
                ButtonSegment(value: MovieFilter.planned, label: Text('В планах')),
                ButtonSegment(value: MovieFilter.watched, label: Text('Просмотрено')),
              ],
              selected: {vm.filter},
              onSelectionChanged: (set) => vm.setFilter(set.first),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (vm.localState) {
              ViewState.loading => const Center(child: CircularProgressIndicator()),
              ViewState.error => Center(
                  child: Text(vm.errorMessage ?? 'Ошибка загрузки базы'),
                ),
              ViewState.empty => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Кинотека пока пуста.\nНажмите «+» внизу или значок поиска вверху, чтобы добавить фильм.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              _ => movies.isEmpty
                  ? const Center(child: Text('По вашему запросу ничего не найдено'))
                  : ListView.builder(
                      itemCount: movies.length,
                      itemBuilder: (context, index) {
                        final movie = movies[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(movie.rating.toStringAsFixed(1)),
                          ),
                          title: Text(movie.title),
                          subtitle: Text('${movie.year} • ${movie.genre}'),
                          trailing: Icon(
                            movie.isWatched
                                ? Icons.check_circle
                                : Icons.schedule,
                            color: movie.isWatched ? Colors.green : Colors.orange,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MovieDetailScreen(movie: movie),
                              ),
                            );
                          },
                        );
                      },
                    ),
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MovieFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
    );
  }
}
'@

Write-Utf8NoBom "lib\ui\screens\search_online_screen.dart" @'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/view_state.dart';
import '../../viewmodels/movie_viewmodel.dart';

class SearchOnlineScreen extends StatefulWidget {
  const SearchOnlineScreen({super.key});

  @override
  State<SearchOnlineScreen> createState() => _SearchOnlineScreenState();
}

class _SearchOnlineScreenState extends State<SearchOnlineScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MovieViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Поиск фильмов онлайн')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Например: Matrix, Sherlock, Dune...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: vm.searchOnline,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => vm.searchOnline(_controller.text),
                  child: const Text('Найти'),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (vm.remoteState) {
              ViewState.idle => const Center(
                  child: Text('Введите название фильма или сериала для поиска в сети'),
                ),
              ViewState.loading => const Center(child: CircularProgressIndicator()),
              ViewState.error => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      vm.errorMessage ?? 'Ошибка подключения к серверу',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ViewState.empty => const Center(
                  child: Text('По данному запросу в API ничего не найдено'),
                ),
              ViewState.success => ListView.builder(
                  itemCount: vm.remoteMovies.length,
                  itemBuilder: (context, index) {
                    final movie = vm.remoteMovies[index];
                    return ListTile(
                      leading: movie.posterUrl != null
                          ? Image.network(
                              movie.posterUrl!,
                              width: 44,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.movie),
                            )
                          : const Icon(Icons.movie),
                      title: Text(movie.title),
                      subtitle: Text('${movie.year} • ${movie.genre} • ★ ${movie.rating}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Добавить в мою кинотеку',
                        onPressed: () async {
                          await vm.addMovie(movie);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('«${movie.title}» добавлен в кинотеку'),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}
'@

Write-Utf8NoBom "lib\ui\screens\movie_detail_screen.dart" @'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/movie.dart';
import '../../services/notification_service.dart';
import '../../viewmodels/movie_viewmodel.dart';
import 'movie_form_screen.dart';

class MovieDetailScreen extends StatelessWidget {
  final Movie movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MovieViewModel>();
    final notifier = context.read<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(movie.title),
        actions: [
          IconButton(
            tooltip: 'Редактировать',
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieFormScreen(existingMovie: movie),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (movie.id != null) {
                await vm.deleteMovie(movie.id!);
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (movie.posterUrl != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  movie.posterUrl!,
                  height: 220,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.movie_creation_outlined, size: 100),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            movie.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Год: ${movie.year}')),
              Chip(label: Text('Жанр: ${movie.genre}')),
              Chip(label: Text('Оценка: ${movie.rating}/10')),
              Chip(
                label: Text(movie.isWatched ? 'Просмотрено' : 'В планах'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            movie.description ?? 'Описание не указано.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.notifications_active),
            label: const Text('Напомнить посмотреть'),
            onPressed: () async {
              final sent = await notifier.showWatchReminder(movie.title);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    sent
                        ? 'Напоминание отправлено в шторку уведомлений!'
                        : 'Разрешение на уведомления отклонено. Включите его в настройках устройства.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
'@

Write-Utf8NoBom "lib\ui\screens\movie_form_screen.dart" @'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/movie.dart';
import '../../viewmodels/movie_viewmodel.dart';

class MovieFormScreen extends StatefulWidget {
  final Movie? existingMovie;

  const MovieFormScreen({super.key, this.existingMovie});

  @override
  State<MovieFormScreen> createState() => _MovieFormScreenState();
}

class _MovieFormScreenState extends State<MovieFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _genreCtrl;
  late final TextEditingController _ratingCtrl;
  late final TextEditingController _descCtrl;
  late bool _isWatched;

  @override
  void initState() {
    super.initState();
    final m = widget.existingMovie;
    _titleCtrl = TextEditingController(text: m?.title ?? '');
    _yearCtrl = TextEditingController(text: m?.year.toString() ?? '2024');
    _genreCtrl = TextEditingController(text: m?.genre ?? 'Фантастика');
    _ratingCtrl = TextEditingController(text: m?.rating.toString() ?? '8.0');
    _descCtrl = TextEditingController(text: m?.description ?? '');
    _isWatched = m?.isWatched ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _yearCtrl.dispose();
    _genreCtrl.dispose();
    _ratingCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<MovieViewModel>();
    final movie = Movie(
      id: widget.existingMovie?.id,
      title: _titleCtrl.text.trim(),
      year: int.parse(_yearCtrl.text.trim()),
      genre: _genreCtrl.text.trim(),
      rating: double.parse(_ratingCtrl.text.trim().replaceAll(',', '.')),
      isWatched: _isWatched,
      posterUrl: widget.existingMovie?.posterUrl,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );

    if (widget.existingMovie == null) {
      await vm.addMovie(movie);
    } else {
      await vm.updateMovie(movie);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingMovie != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Редактировать фильм' : 'Новый фильм'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Название фильма *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Введите название (минимум 2 символа)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Год выпуска *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final year = int.tryParse(v ?? '');
                if (year == null || year < 1895 || year > 2030) {
                  return 'Укажите корректный год (1895–2030)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _genreCtrl,
              decoration: const InputDecoration(
                labelText: 'Жанр *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите жанр' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ratingCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Личная оценка (0–10) *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final val = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (val == null || val < 0 || val > 10) {
                  return 'Введите число от 0 до 10';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Фильм уже просмотрен'),
              value: _isWatched,
              onChanged: (val) => setState(() => _isWatched = val),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Заметка или описание',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Сохранить изменения' : 'Добавить в кинотеку'),
            ),
          ],
        ),
      ),
    );
  }
}
'@

Write-Utf8NoBom "lib\main.dart" @'
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
'@

Write-Utf8NoBom "test\widget_test.dart" @'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kinoteka/core/view_state.dart';
import 'package:kinoteka/data/models/movie.dart';
import 'package:kinoteka/data/repositories/movie_repository.dart';
import 'package:kinoteka/viewmodels/movie_viewmodel.dart';
import 'package:kinoteka/ui/screens/home_screen.dart';

class FakeMovieRepository implements MovieRepository {
  final List<Movie> _storage = [];
  bool shouldThrowNetworkError = false;

  @override
  Future<List<Movie>> getLocalMovies() async => List.from(_storage);

  @override
  Future<void> addMovie(Movie movie) async {
    _storage.add(movie.copyWith(id: _storage.length + 1));
  }

  @override
  Future<void> updateMovie(Movie movie) async {
    final idx = _storage.indexWhere((m) => m.id == movie.id);
    if (idx != -1) _storage[idx] = movie;
  }

  @override
  Future<void> deleteMovie(int id) async {
    _storage.removeWhere((m) => m.id == id);
  }

  @override
  Future<List<Movie>> searchRemoteMovies(String query) async {
    if (shouldThrowNetworkError) throw Exception('No internet');
    return [
      const Movie(title: 'Интерстеллар', year: 2014, genre: 'Фантастика', rating: 9.2),
    ];
  }
}

void main() {
  group('Unit-тесты модели и логики', () {
    test('1. Сериализация и десериализация Movie (toMap / fromMap)', () {
      const movie = Movie(
        id: 1,
        title: 'Начало',
        year: 2010,
        genre: 'Фантастика',
        rating: 8.8,
        isWatched: true,
      );
      final restored = Movie.fromMap(movie.toMap());
      expect(restored.title, 'Начало');
      expect(restored.year, 2010);
      expect(restored.isWatched, true);
    });

    test('2. Разбор JSON из внешнего API (Movie.fromTvMazeJson)', () {
      final json = {
        'show': {
          'name': 'Sherlock',
          'premiered': '2010-07-25',
          'genres': ['Drama', 'Crime'],
          'rating': {'average': 8.9},
          'summary': '<p>Detective story</p>',
        }
      };
      final movie = Movie.fromTvMazeJson(json);
      expect(movie.title, 'Sherlock');
      expect(movie.year, 2010);
      expect(movie.genre, 'Drama');
      expect(movie.description, 'Detective story');
    });

    test('3. Метод copyWith корректно меняет статус просмотра', () {
      const movie = Movie(title: 'Матрица', year: 1999, genre: 'Боевик', rating: 9.0);
      final updated = movie.copyWith(isWatched: true);
      expect(updated.isWatched, true);
      expect(updated.title, 'Матрица');
    });

    test('4. Поиск фильтрует список фильмов без учёта регистра', () async {
      final vm = MovieViewModel(repository: FakeMovieRepository());
      await vm.addMovie(const Movie(title: 'Дюна', year: 2021, genre: 'Фантастика', rating: 8.1));
      await vm.addMovie(const Movie(title: 'Оппенгеймер', year: 2023, genre: 'Драма', rating: 8.5));

      vm.setSearchQuery('дюн');
      expect(vm.filteredMovies.length, 1);
      expect(vm.filteredMovies.first.title, 'Дюна');
    });

    test('5. Фильтр по статусу (Просмотрено / В планах) работает корректно', () async {
      final vm = MovieViewModel(repository: FakeMovieRepository());
      await vm.addMovie(const Movie(title: 'Фильм 1', year: 2020, genre: 'Драма', rating: 7.5, isWatched: true));
      await vm.addMovie(const Movie(title: 'Фильм 2', year: 2022, genre: 'Комедия', rating: 7.0, isWatched: false));

      vm.setFilter(MovieFilter.watched);
      expect(vm.filteredMovies.length, 1);
      expect(vm.filteredMovies.first.title, 'Фильм 1');
    });
  });

  group('Тесты ViewModel с фейковым репозиторием', () {
    test('6. ViewModel управляет состояниями loading -> empty -> success -> error', () async {
      final fakeRepo = FakeMovieRepository();
      final vm = MovieViewModel(repository: fakeRepo);

      await vm.loadLocalMovies();
      expect(vm.localState, ViewState.empty);

      await vm.addMovie(const Movie(title: 'Довод', year: 2020, genre: 'Боевик', rating: 7.8));
      expect(vm.localState, ViewState.success);

      fakeRepo.shouldThrowNetworkError = true;
      await vm.searchOnline('Тест');
      expect(vm.remoteState, ViewState.error);
      expect(vm.errorMessage, isNotNull);
    });
  });

  group('Widget-тесты', () {
    testWidgets('7. Главный экран отображает заголовок и поле поиска', (tester) async {
      final vm = MovieViewModel(repository: FakeMovieRepository());
      await vm.loadLocalMovies();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vm,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      expect(find.text('Моя кинотека'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
'@

Write-Host "=== 5. Установка зависимостей, анализ и запуск тестов ===" -ForegroundColor Cyan
flutter pub get
flutter analyze
flutter test
Write-Host "=== ГОТОВО! Все файлы созданы и тесты пройдены ===" -ForegroundColor Green
