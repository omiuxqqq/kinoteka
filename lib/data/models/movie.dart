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