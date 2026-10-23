import 'package:flutter/material.dart';
import '../models/book.dart';
import '../widgets/cover_image.dart';

class StatisticsScreen extends StatelessWidget {
  final List<Book> books;

  const StatisticsScreen({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStatistics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistieken'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview cards
            _buildOverviewCards(context, stats),
            const SizedBox(height: 24),

            // Reading per month
            _buildMonthlyReadingSection(context, stats),
            const SizedBox(height: 24),

            // Top rated books
            _buildTopRatedSection(context, stats),
            const SizedBox(height: 24),

            // Genre distribution
            _buildGenreDistributionSection(context, stats),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateStatistics() {
    final now = DateTime.now();
    final currentYear = now.year;
    
    final readBooks = books.where((b) => b.isRead).toList();
    final booksThisYear = readBooks.where((b) {
      if (b.endDate == null || b.endDate!.isEmpty) return false;
      try {
        final date = DateTime.parse(b.endDate!);
        return date.year == currentYear;
      } catch (e) {
        return false;
      }
    }).toList();

    // Calculate average rating (only for rated books)
    final ratedBooks = readBooks.where((b) => b.rating != null && b.rating! > 0).toList();
    final avgRating = ratedBooks.isEmpty 
        ? 0.0 
        : ratedBooks.map((b) => b.rating!).reduce((a, b) => a + b) / ratedBooks.length;

    // Monthly reading data
    final monthlyData = <int, int>{};
    for (var i = 1; i <= 12; i++) {
      monthlyData[i] = 0;
    }
    for (var book in booksThisYear) {
      if (book.endDate != null && book.endDate!.isNotEmpty) {
        try {
          final date = DateTime.parse(book.endDate!);
          monthlyData[date.month] = (monthlyData[date.month] ?? 0) + 1;
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    // Top rated books (5 stars)
    final topRated = readBooks
        .where((b) => b.rating != null && b.rating! >= 4)
        .toList()
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

    // Genre distribution
    final genreCount = <String, int>{};
    for (var book in books) {
      // Normalize genre to title case (first letter uppercase)
      var bookType = book.type ?? 'onbekend';
      if (bookType.isNotEmpty) {
        bookType = bookType[0].toUpperCase() + bookType.substring(1).toLowerCase();
      }
      genreCount[bookType] = (genreCount[bookType] ?? 0) + 1;
    }
    final sortedGenres = genreCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalBooks': books.length,
      'readBooks': readBooks.length,
      'unreadBooks': books.length - readBooks.length,
      'booksThisYear': booksThisYear.length,
      'averageRating': avgRating,
      'ratedBooksCount': ratedBooks.length,
      'monthlyData': monthlyData,
      'topRated': topRated.take(5).toList(),
      'genreDistribution': sortedGenres,
    };
  }

  Widget _buildOverviewCards(BuildContext context, Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Totaal Boeken',
                stats['totalBooks'].toString(),
                Icons.menu_book,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'Gelezen',
                stats['readBooks'].toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Dit Jaar',
                stats['booksThisYear'].toString(),
                Icons.calendar_today,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'Gem. Rating',
                stats['averageRating'] > 0 
                    ? stats['averageRating'].toStringAsFixed(1) 
                    : '-',
                Icons.star,
                Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyReadingSection(BuildContext context, Map<String, dynamic> stats) {
    final monthlyData = stats['monthlyData'] as Map<int, int>;
    final maxBooks = monthlyData.values.isEmpty 
        ? 1 
        : monthlyData.values.reduce((a, b) => a > b ? a : b);
    final currentYear = DateTime.now().year;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gelezen per Maand ($currentYear)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  final month = index + 1;
                  final count = monthlyData[month] ?? 0;
                  final height = maxBooks > 0 ? (count / maxBooks) * 160 : 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (count > 0)
                            Text(
                              count.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            height: height.clamp(0, 160),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getMonthAbbr(month),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRatedSection(BuildContext context, Map<String, dynamic> stats) {
    final topRated = stats['topRated'] as List<Book>;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Beoordeelde Boeken',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (topRated.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Nog geen beoordeelde boeken'),
                ),
              )
            else
              ...topRated.map((book) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: book.normalizedCoverUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CoverImage(
                              imageUrl: book.normalizedCoverUrl!,
                              width: 40,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.book, size: 20),
                          ),
                    title: Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          book.rating.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreDistributionSection(BuildContext context, Map<String, dynamic> stats) {
    final genres = stats['genreDistribution'] as List<MapEntry<String, int>>;
    final total = stats['totalBooks'] as int;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verdeling per Genre',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...genres.take(10).map((entry) {
              final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return months[month - 1];
  }
}
