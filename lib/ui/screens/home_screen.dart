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