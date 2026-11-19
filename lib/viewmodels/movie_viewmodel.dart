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