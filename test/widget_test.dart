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