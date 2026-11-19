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