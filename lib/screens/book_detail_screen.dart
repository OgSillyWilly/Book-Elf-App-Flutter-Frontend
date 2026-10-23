import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/interfaces/i_data_service.dart';
import '../services/api_exceptions.dart';
import '../service_locator.dart';
import '../widgets/rating_stars.dart';
import '../widgets/cover_image.dart';
import 'book_form_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;
  final VoidCallback? onBookUpdated;
  final VoidCallback? onBookDeleted;

  const BookDetailScreen({
    super.key,
    required this.book,
    this.onBookUpdated,
    this.onBookDeleted,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late Book _currentBook;
  late final IDataService _dataService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
    _currentBook = widget.book;
  }

  Future<void> _refreshBook() async {
    if (_currentBook.id == null) return;
    
    setState(() => _isLoading = true);
    try {
      final updatedBook = await _dataService.getBook(_currentBook.id!);
      setState(() {
        _currentBook = updatedBook;
        _isLoading = false;
      });
    } on NotFoundException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onBookUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dit boek bestaat niet meer.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij herladen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boek Details'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Bewerk',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookFormScreen(book: _currentBook),
                ),
              );
              if (result == true && context.mounted) {
                await _refreshBook();
                widget.onBookUpdated?.call();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover and basic info
            _buildHeaderSection(context),
            
            const Divider(height: 1),
            
            // Detailed information
            _buildDetailsSection(context),
            
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          Hero(
            tag: 'book-cover-${_currentBook.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _currentBook.normalizedCoverUrl != null
                  ? CoverImage(
                      imageUrl: _currentBook.normalizedCoverUrl!,
                      width: 120,
                      height: 180,
                      fit: BoxFit.cover,
                    )
                  : _buildPlaceholderCover(),
            ),
          ),
          const SizedBox(width: 20),
          
          // Title, Author, Rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentBook.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentBook.author,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                
                // Rating
                if (_currentBook.isRead && _currentBook.rating != null && _currentBook.rating! > 0) ...[
                  RatingStars(
                    rating: _currentBook.rating!,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Read status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _currentBook.isRead
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _currentBook.isRead ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentBook.isRead ? Icons.check_circle : Icons.schedule,
                        size: 16,
                        color: _currentBook.isRead ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentBook.isRead ? 'Gelezen' : 'Ongelezen',
                        style: TextStyle(
                          color: _currentBook.isRead ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 120,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.book, size: 48, color: Colors.grey),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informatie',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          // Type
          _buildInfoRow(
            context,
            Icons.category,
            'Type',
            _currentBook.type ?? 'Onbekend',
          ),
          
          // ISBN
          if (_currentBook.isbn != null && _currentBook.isbn!.isNotEmpty)
            _buildInfoRow(
              context,
              Icons.qr_code,
              'ISBN',
              _currentBook.isbn!,
            ),
          
          // Publisher
          if (_currentBook.publisher != null && _currentBook.publisher!.isNotEmpty)
            _buildInfoRow(
              context,
              Icons.business,
              'Uitgever',
              _currentBook.publisher!,
            ),
          
          // Publication date
          if (_currentBook.publicationDate != null && _currentBook.publicationDate!.isNotEmpty)
            _buildInfoRow(
              context,
              Icons.calendar_month,
              'Publicatiedatum',
              _formatDate(_currentBook.publicationDate!),
            ),
          
          const Divider(height: 32),
          
          // Reading dates section
          if (_currentBook.isRead) ...[
            Text(
              'Leesgeschiedenis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            if (_currentBook.startDate != null && _currentBook.startDate!.isNotEmpty)
              _buildInfoRow(
                context,
                Icons.play_circle_outline,
                'Startdatum',
                _formatDate(_currentBook.startDate!),
              ),
            
            if (_currentBook.endDate != null && _currentBook.endDate!.isNotEmpty)
              _buildInfoRow(
                context,
                Icons.check_circle_outline,
                'Einddatum',
                _formatDate(_currentBook.endDate!),
              ),
            
            const Divider(height: 32),
          ],
          
          // Physical details section
          Text(
            'Fysieke Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow(
            context,
            Icons.storage,
            'Dustjacket',
            _currentBook.hasDustjacket ? 'Ja' : 'Nee',
          ),
          
          _buildInfoRow(
            context,
            Icons.layers,
            'Slipcase',
            _currentBook.hasSlipcase ? 'Ja' : 'Nee',
          ),
          
          // Location section
          if (_currentBook.cabinet != null || _currentBook.shelf != null || _currentBook.position != null) ...[
            const Divider(height: 32),
            Text(
              'Locatie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            if (_currentBook.cabinet != null)
              _buildInfoRow(
                context,
                Icons.shelves,
                'Kast',
                _currentBook.cabinet!,
              ),
            
            if (_currentBook.shelf != null)
              _buildInfoRow(
                context,
                Icons.horizontal_rule,
                'Plank',
                _currentBook.shelf!,
              ),
            
            if (_currentBook.position != null)
              _buildInfoRow(
                context,
                Icons.pin_drop,
                'Positie',
                _currentBook.position.toString(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'januari', 'februari', 'maart', 'april', 'mei', 'juni',
        'juli', 'augustus', 'september', 'oktober', 'november', 'december'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
