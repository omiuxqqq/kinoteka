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