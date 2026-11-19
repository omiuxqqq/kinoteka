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