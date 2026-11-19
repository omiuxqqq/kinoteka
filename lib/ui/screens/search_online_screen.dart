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