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