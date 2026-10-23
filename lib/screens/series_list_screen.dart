import 'package:flutter/material.dart';
import '../models/series.dart';
import '../services/interfaces/i_data_service.dart';
import '../services/api_exceptions.dart';
import '../service_locator.dart';
import '../utils/error_dialog.dart';

class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key});

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  late final IDataService _dataService;
  List<Series> _series = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
    _loadSeries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSeries() async {
    setState(() => _isLoading = true);
    try {
      final series = await _dataService.getSeries(search: _searchQuery.isEmpty ? null : _searchQuery);
      setState(() {
        _series = series;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(context, 'Fout bij laden series', e.toString());
      }
    }
  }

  Future<void> _deleteSeries(Series series) async {
    if (series.id == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Serie verwijderen'),
        content: Text('Weet je zeker dat je "${series.name}" wilt verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dataService.deleteSeries(series.id!);
        _loadSeries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Serie verwijderd')),
          );
        }
      } catch (e) {
        if (mounted) {
          showErrorDialog(context, 'Fout bij verwijderen', e.toString());
        }
      }
    }
  }

  void _showSeriesForm({Series? series}) {
    showDialog(
      context: context,
      builder: (context) => SeriesFormDialog(
        series: series,
        onSaved: () {
          Navigator.pop(context);
          _loadSeries();
        },
      ),
    );
  }

  void _showSeriesDetails(Series series) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeriesDetailScreen(seriesId: series.id!),
      ),
    ).then((_) => _loadSeries());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Series'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSeriesForm(),
            tooltip: 'Nieuwe serie',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Zoek series...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadSeries();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              onSubmitted: (_) => _loadSeries(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _series.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_books, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Geen series gevonden'
                                  : 'Geen resultaten voor "$_searchQuery"',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showSeriesForm(),
                              icon: const Icon(Icons.add),
                              label: const Text('Nieuwe serie toevoegen'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSeries,
                        child: ListView.builder(
                          itemCount: _series.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final series = _series[index];
                            return _SeriesCard(
                              series: series,
                              onTap: () => _showSeriesDetails(series),
                              onEdit: () => _showSeriesForm(series: series),
                              onDelete: () => _deleteSeries(series),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  final Series series;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SeriesCard({
    required this.series,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = series.progressPercentage;
    final booksRead = series.booksCount ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (series.author != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            series.author!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Bewerken'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Verwijderen', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                  ),
                ],
              ),
              if (series.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  series.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$booksRead / ${series.totalBooks} boeken',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              series.isCompleted ? Colors.green : Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: series.isCompleted ? Colors.green : Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Series Form Dialog
class SeriesFormDialog extends StatefulWidget {
  final Series? series;
  final VoidCallback onSaved;

  const SeriesFormDialog({
    super.key,
    this.series,
    required this.onSaved,
  });

  @override
  State<SeriesFormDialog> createState() => _SeriesFormDialogState();
}

class _SeriesFormDialogState extends State<SeriesFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _authorController;
  late TextEditingController _totalBooksController;
  bool _isSaving = false;
  late final IDataService _dataService;

  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
    _nameController = TextEditingController(text: widget.series?.name);
    _descriptionController = TextEditingController(text: widget.series?.description);
    _authorController = TextEditingController(text: widget.series?.author);
    _totalBooksController = TextEditingController(
      text: widget.series?.totalBooks.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _authorController.dispose();
    _totalBooksController.dispose();
    super.dispose();
  }

  Future<void> _saveSeries() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      'author': _authorController.text.isEmpty ? null : _authorController.text,
      'total_books': int.parse(_totalBooksController.text),
    };

    try {
      if (widget.series?.id != null) {
        await _dataService.updateSeries(widget.series!.id!, data);
      } else {
        await _dataService.createSeries(data);
      }

      if (mounted) {
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.series != null ? 'Serie bijgewerkt' : 'Serie toegevoegd'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        showErrorDialog(context, 'Fout bij opslaan', e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.series != null ? 'Serie bewerken' : 'Nieuwe serie'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Naam *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Naam is verplicht';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Auteur',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalBooksController,
                decoration: const InputDecoration(
                  labelText: 'Totaal aantal boeken *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Aantal boeken is verplicht';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 1) {
                    return 'Voer een geldig getal in (minimaal 1)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschrijving',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveSeries,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Opslaan'),
        ),
      ],
    );
  }
}

// Series Detail Screen
class SeriesDetailScreen extends StatefulWidget {
  final int seriesId;

  const SeriesDetailScreen({super.key, required this.seriesId});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late final IDataService _dataService;
  bool _isLoading = true;
  Series? _series;
  double _progress = 0.0;
  List<dynamic> _books = [];

  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
    _loadSeriesDetails();
  }

  Future<void> _loadSeriesDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dataService.getSeriesWithProgress(widget.seriesId);
      setState(() {
        _series = Series.fromJson(data['series']);
        _progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
        _books = data['series']['books'] ?? [];
        _isLoading = false;
      });
    } on NotFoundException {
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(context, 'Fout bij laden', e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_series?.name ?? 'Serie details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _series == null
              ? const Center(child: Text('Serie niet gevonden'))
              : RefreshIndicator(
                  onRefresh: _loadSeriesDetails,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _series!.name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_series!.author != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Door ${_series!.author}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                                if (_series!.description != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _series!.description!,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_books.length} / ${_series!.totalBooks} boeken',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: _progress / 100,
                                              minHeight: 12,
                                              backgroundColor: Colors.grey[300],
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                _progress >= 100 ? Colors.green : Theme.of(context).primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '${_progress.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: _progress >= 100 ? Colors.green : Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_books.isNotEmpty) ...[
                          Text(
                            'Boeken in deze serie',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _books.length,
                            itemBuilder: (context, index) {
                              final book = _books[index];
                              final isRead = book['is_read'] == true || book['is_read'] == 1;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    isRead ? Icons.check_circle : Icons.circle_outlined,
                                    color: isRead ? Colors.green : Colors.grey,
                                  ),
                                  title: Text(book['title'] ?? ''),
                                  subtitle: book['series_order'] != null
                                      ? Text('Deel ${book['series_order']}')
                                      : null,
                                  trailing: book['rating'] != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, size: 16, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text('${book['rating']}'),
                                          ],
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ] else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'Geen boeken gevonden in deze serie',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
