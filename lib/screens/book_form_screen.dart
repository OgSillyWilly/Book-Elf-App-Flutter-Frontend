import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/book_types.dart';
import '../models/book.dart';
import '../models/series.dart';
import '../services/api_exceptions.dart';
import '../services/interfaces/i_data_service.dart';
import '../service_locator.dart';
import '../services/google_books_service.dart';
import '../services/image_upload_service.dart';
import '../utils/error_dialog.dart';
import '../utils/date_formatter.dart';
import '../widgets/cover_image.dart';
import '../widgets/rating_stars.dart';

class BookFormScreen extends StatefulWidget {
  final Book? book;

  const BookFormScreen({super.key, this.book});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publicationDateController = TextEditingController();
  final _cabinetController = TextEditingController();
  final _shelfController = TextEditingController();
  final _positionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _coverUrlController = TextEditingController();
  late final IDataService _dataService;
  final GoogleBooksService _googleBooksService = GoogleBooksService();
  
  String _selectedType = 'boek';
  String? _coverUrl;
  XFile? _selectedImage; // Geselecteerde afbeelding voor nieuwe boeken
  bool _isRead = false;
  int _rating = 0;
  bool _hasSlipcase = false;
  bool _hasDustjacket = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  String _selectedLanguage = 'nl';
  String _searchType = 'title'; // title, author, isbn, all
  int? _seriesId;
  List<Series> _seriesOptions = [];
  String? _seriesError;

  Future<void> _loadSeriesOptions() async {
    try {
      final series = await _dataService.getSeries();
      if (mounted) setState(() => _seriesOptions = series);
    } catch (_) {
      // The selector stays empty; the book keeps its current series_id.
    }
  }
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? initialDate;
    final DateTime minDate = DateTime(1900);
    final DateTime maxDate = DateTime(2100);
    
    try {
      if (controller.text.isNotEmpty) {
        final parsed = DateFormat('dd-MM-yyyy').parse(controller.text);
        // Only use parsed date if it's within valid range
        if (parsed.isAfter(minDate.subtract(const Duration(days: 1))) && 
            parsed.isBefore(maxDate.add(const Duration(days: 1)))) {
          initialDate = parsed;
        }
      }
    } catch (e) {
      initialDate = null;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: minDate,
      lastDate: maxDate,
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
    _loadSeriesOptions();
    if (widget.book != null) {
      _seriesId = widget.book!.seriesId;
      _titleController.text = widget.book!.title;
      _authorController.text = widget.book!.author;
      _isbnController.text = widget.book!.isbn ?? '';
      // Ensure selected type is in the list, otherwise use default
      if (BookTypes.all.contains(widget.book!.type)) {
        _selectedType = widget.book!.type ?? 'boek';
      } else {
        _selectedType = 'boek'; // fallback to default
      }
      _publisherController.text = widget.book!.publisher ?? '';
      _publicationDateController.text = DateFormatter.formatForDisplay(widget.book!.publicationDate);
      _coverUrl = widget.book!.coverUrl;
      _coverUrlController.text = widget.book!.coverUrl ?? '';
      _cabinetController.text = widget.book!.cabinet ?? '';
      _shelfController.text = widget.book!.shelf ?? '';
      _positionController.text = widget.book!.position?.toString() ?? '';
      _isRead = widget.book!.isRead;
      _rating = widget.book!.rating ?? 0;
      _hasSlipcase = widget.book!.hasSlipcase;
      _hasDustjacket = widget.book!.hasDustjacket;
      _startDateController.text = DateFormatter.formatForDisplay(widget.book!.startDate);
      _endDateController.text = DateFormatter.formatForDisplay(widget.book!.endDate);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _publicationDateController.dispose();
    _cabinetController.dispose();
    _shelfController.dispose();
    _coverUrlController.dispose();
    _positionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _searchGoogleBooks() async {
    final query = _titleController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voer een zoekterm in')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      final result = await _googleBooksService.searchBooks(
        query: query,
        searchType: _searchType,
        language: _selectedLanguage,
        authorForCombo: _authorController.text.trim(),
      );

      setState(() {
        _searchResults = result.books;
        _showSearchResults = result.books.isNotEmpty;
        _isLoading = false;
      });

      if (result.books.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geen boeken gevonden')),
          );
        }
      } else if (mounted) {
        // Toon aantal gevonden resultaten
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.books.length} resultaten gevonden${result.books.length < result.totalAvailable ? ' (van ${result.totalAvailable} totaal)' : ''}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on GoogleBooksQuotaException {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(
          context,
          'Google Books dagelijks quota bereikt',
          'Het dagelijkse zoeklimiet van Google Books is bereikt.\n\n'
          'Dit reset automatisch om middernacht (UTC). '
          'Je kunt nu het boek handmatig toevoegen door de velden hieronder in te vullen.',
        );
      }
    } on GoogleBooksServiceException {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(
          context,
          'Google Books tijdelijk niet beschikbaar',
          'De Google Books service is momenteel overbelast of in onderhoud.\n\n'
          'Probeer het over een paar minuten opnieuw, of voeg het boek handmatig toe.',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String title = 'Fout bij zoeken';
        String message;
        
        if (e.toString().contains('TimeoutException') || e.toString().contains('timed out')) {
          title = 'Verbinding verlopen';
          message = 'De verbinding met Google Books duurde te lang.\n\n'
                   'Controleer je internetverbinding en probeer opnieuw.';
        } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
          title = 'Geen internetverbinding';
          message = 'Kan geen verbinding maken met Google Books.\n\n'
                   'Controleer je internetverbinding.';
        } else {
          message = 'Er is een fout opgetreden bij het zoeken naar boeken.\n\n'
                   'Je kunt het boek ook handmatig toevoegen door de velden hieronder in te vullen.\n\n'
                   'Technische details: $e';
        }
        
        showErrorDialog(context, title, message);
      }
    }
  }

  void _selectBook(Map<String, dynamic> book) {
    final bookData = _googleBooksService.extractBookData(book);
    
    _titleController.text = bookData['title'];
    _authorController.text = bookData['author'];
    _isbnController.text = bookData['isbn'] ?? '';
    _publisherController.text = bookData['publisher'] ?? '';
    _publicationDateController.text = DateFormatter.formatForDisplay(bookData['publishedDate']);
    _coverUrl = bookData['coverUrl'];
    _coverUrlController.text = bookData['coverUrl'] ?? '';

    setState(() {
      _showSearchResults = false;
      _searchResults = [];
    });
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 1200,
        imageQuality: 70,
      );

      if (image != null) {
        if (widget.book == null) {
          // Voor nieuwe boeken: bewaar de afbeelding tijdelijk
          setState(() {
            _selectedImage = image;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Afbeelding geselecteerd - zal worden geüpload na opslaan'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Voor bestaande boeken: upload direct
          await _uploadCoverImage(image);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'Fout bij camera',
          'Kon geen foto maken: $e',
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 1200,
        imageQuality: 70,
      );

      if (image != null) {
        if (widget.book == null) {
          // Voor nieuwe boeken: bewaar de afbeelding tijdelijk
          setState(() {
            _selectedImage = image;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Afbeelding geselecteerd - zal worden geüpload na opslaan'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Voor bestaande boeken: upload direct
          await _uploadCoverImage(image);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'Fout bij galerij',
          'Kon geen afbeelding kiezen: $e',
        );
      }
    }
  }

  Future<void> _uploadCoverImage(XFile imageFile) async {
    setState(() => _isLoading = true);

    try {
      // Read bytes
      final bytes = await imageFile.readAsBytes();
      
      // Get filename - prefer name, fallback to path basename
      String filename = imageFile.name;
      if (!filename.contains('.')) {
        // If name has no extension, try to get it from path
        filename = imageFile.path.split('/').last;
      }
      
      // Clear old image from cache if it exists
      if (_coverUrl != null && !kIsWeb) {
        await CachedNetworkImage.evictFromCache(_coverUrl!);
        print('DEBUG: Cleared cache for old URL: $_coverUrl');
      }
      
      // Upload using bytes for both web and mobile for consistency
      final coverUrl = await ImageUploadService.uploadBookCoverFromBytes(
        widget.book!.id!,
        bytes,
        filename,
      );

      print('DEBUG: Received cover URL: $coverUrl'); // Debug
      
      setState(() {
        _coverUrl = coverUrl;
        _coverUrlController.text = coverUrl ?? '';
        _isLoading = false;
      });

      print('DEBUG: Set _coverUrl to: $_coverUrl'); // Debug

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cover succesvol geüpload: ${coverUrl?.substring(0, 50)}...')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(
          context,
          'Upload mislukt',
          'Kon cover niet uploaden: $e',
        );
      }
    }
  }

  Future<void> _deleteCover() async {
    if (widget.book == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cover verwijderen?'),
        content: const Text('Weet je zeker dat je de cover wilt verwijderen?'),
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await ImageUploadService.deleteBookCover(widget.book!.id!);

      setState(() {
        _coverUrl = null;
        _coverUrlController.clear();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover verwijderd')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(
          context,
          'Verwijderen mislukt',
          'Kon cover niet verwijderen: $e',
        );
      }
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse position - only validate if not empty
      int? position;
      if (_positionController.text.isNotEmpty) {
        position = int.tryParse(_positionController.text);
        if (position == null) {
          throw Exception('Positie moet een getal zijn');
        }
      }

      // Automatisch jaar extraheren uit einddatum
      int? yearRead;
      if (_endDateController.text.isNotEmpty) {
        yearRead = DateFormatter.extractYearFromDisplayDate(_endDateController.text);
      }

      final bookData = {
        'title': _titleController.text,
        'author': _authorController.text,
        'isbn': _isbnController.text.isEmpty ? null : _isbnController.text,
        'type': _selectedType,
        'publisher': _publisherController.text.isEmpty ? null : _publisherController.text,
        'publication_date': DateFormatter.formatForApiOrNull(_publicationDateController.text),
        'cover_url': _coverUrl,
        'has_slipcase': _hasSlipcase ? 1 : 0,
        'has_dustjacket': _hasDustjacket ? 1 : 0,
        'cabinet': _cabinetController.text.isEmpty ? null : _cabinetController.text,
        'shelf': _shelfController.text.isEmpty ? null : _shelfController.text,
        'position': position,
        'is_read': _isRead ? 1 : 0,
        'rating': _rating > 0 ? _rating : null,
        'start_date': DateFormatter.formatForApiOrNull(_startDateController.text),
        'end_date': DateFormatter.formatForApiOrNull(_endDateController.text),
        'year_read': yearRead,
        'series_id': _seriesId,
      };

      if (widget.book == null) {
        final newBook = await _dataService.createBook(bookData);
        
        // Als er een afbeelding geselecteerd is, upload deze nu
        if (_selectedImage != null && newBook.id != null) {
          try {
            setState(() => _isLoading = true);
            
            if (kIsWeb) {
              final bytes = await _selectedImage!.readAsBytes();
              await ImageUploadService.uploadBookCoverFromBytes(
                newBook.id!,
                bytes,
                _selectedImage!.name,
              );
            } else {
              await ImageUploadService.uploadBookCover(
                newBook.id!,
                File(_selectedImage!.path),
              );
            }
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Boek en afbeelding opgeslagen')),
              );
            }
          } catch (e) {
            // Afbeelding upload gefaald, maar boek is wel opgeslagen
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Boek opgeslagen, maar afbeelding upload mislukt: $e'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      } else {
        await _dataService.updateBook(widget.book!.id!, bookData);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ValidationException catch (e) {
      final seriesError = e.firstError('series_id');
      setState(() {
        _isLoading = false;
        _seriesError = seriesError;
      });
      if (mounted && seriesError == null) {
        showErrorDialog(context, 'Controleer de invoer', e.message);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(
          context,
          'Fout bij opslaan',
          'Het boek kon niet worden opgeslagen:\n\n$e',
        );
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book == null ? 'Boek Toevoegen' : 'Boek Bewerken'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zoek boek via Google Books',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Taal: '),
                              DropdownButton<String>(
                                value: _selectedLanguage,
                                items: const [
                                  DropdownMenuItem(value: 'nl', child: Text('Nederlands')),
                                  DropdownMenuItem(value: 'en', child: Text('Engels')),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedLanguage = value!);
                                },
                              ),
                              const SizedBox(width: 16),
                              const Text('Zoek op: '),
                              DropdownButton<String>(
                                value: _searchType,
                                items: const [
                                  DropdownMenuItem(value: 'title', child: Text('Titel')),
                                  DropdownMenuItem(value: 'author', child: Text('Auteur')),
                                  DropdownMenuItem(value: 'isbn', child: Text('ISBN')),
                                  DropdownMenuItem(value: 'all', child: Text('Alles')),
                                ],
                                onChanged: (value) {
                                  setState(() => _searchType = value!);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _searchGoogleBooks,
                            icon: const Icon(Icons.search),
                            label: const Text('Zoeken'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_coverUrl != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CoverImage(
                        key: ValueKey(_coverUrl), // Force rebuild when URL changes
                        imageUrl: _coverUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  _sectionTitle('Boekgegevens'),

                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Titel *',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Titel is verplicht';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _authorController,
                    decoration: InputDecoration(
                      labelText: 'Auteur *',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Auteur is verplicht';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int?>(
                    key: ValueKey('series-${_seriesOptions.length}-$_seriesError'),
                    initialValue: _seriesOptions.any((s) => s.id == _seriesId)
                        ? _seriesId
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Serie',
                      filled: true,
                      border: const OutlineInputBorder(),
                      errorText: _seriesError,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Geen serie'),
                      ),
                      ..._seriesOptions.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _seriesId = value;
                        _seriesError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _isbnController,
                    decoration: InputDecoration(
                      labelText: 'ISBN',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _coverUrlController,
                    decoration: InputDecoration(
                      labelText: 'Cover afbeelding URL',
                      filled: true,
                      border: OutlineInputBorder(),
                      hintText: 'https://example.com/cover.jpg',
                      suffixIcon: _coverUrlController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _coverUrlController.clear();
                                  _coverUrl = null;
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _coverUrl = value.isEmpty ? null : value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Toon preview van geselecteerde afbeelding (voor nieuwe boeken)
                  if (_selectedImage != null && widget.book == null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Afbeelding geselecteerd: ${_selectedImage!.name}',
                              style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() => _selectedImage = null);
                            },
                            color: Colors.green.shade700,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Photo upload buttons
                  // Warning for web users
                  if (kIsWeb) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Let op: Foto uploaden werkt het beste op mobiele apparaten. '
                                'In de browser kun je wel de Cover URL gebruiken.',
                                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                  ],
                  Row(
                      children: [
                        if (!kIsWeb)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _pickImageFromCamera,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Foto maken'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        if (!kIsWeb) const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _pickImageFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: Text(kIsWeb ? 'Bestand kiezen' : 'Uit galerij'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (widget.book != null && _coverUrl != null && _coverUrl!.contains('/storage/covers/')) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _deleteCover,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Geüploade cover verwijderen'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Type *',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    items: BookTypes.all.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _publisherController,
                    decoration: InputDecoration(
                      labelText: 'Uitgever',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _publicationDateController,
                    readOnly: true,
                    onTap: () => _selectDate(_publicationDateController),
                    decoration: InputDecoration(
                      labelText: 'Publicatiedatum (DD-MM-JJJJ)',
                      filled: true,
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle('Eigenschappen'),

                  CheckboxListTile(
                    title: const Text('Heeft slipcase (hoesje/doos)'),
                    value: _hasSlipcase,
                    onChanged: (value) {
                      setState(() => _hasSlipcase = value ?? false);
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  CheckboxListTile(
                    title: const Text('Heeft dustjacket (stofomslag)'),
                    value: _hasDustjacket,
                    onChanged: (value) {
                      setState(() => _hasDustjacket = value ?? false);
                    },
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle('Locatie'),

                  TextFormField(
                    controller: _cabinetController,
                    decoration: InputDecoration(
                      labelText: ' Kast (1,2,3,..)',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _shelfController,
                    decoration: InputDecoration(
                      labelText: 'Plank (a,b,c,..)',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _positionController,
                    decoration: InputDecoration(
                      labelText: 'Positie (1,2,3,..)',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle('Leesstatus'),

                  CheckboxListTile(
                    title: const Text('Gelezen'),
                    value: _isRead,
                    onChanged: (value) {
                      setState(() => _isRead = value ?? false);
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // Rating (alleen zichtbaar bij gelezen boeken)
                  if (_isRead) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text('Beoordeling:', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 16),
                          RatingStars(
                            rating: _rating,
                            editable: true,
                            size: 32,
                            onRatingChanged: (newRating) {
                              setState(() => _rating = newRating);
                            },
                          ),
                          if (_rating > 0) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              tooltip: 'Verwijder beoordeling',
                              onPressed: () {
                                setState(() => _rating = 0);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: () => _selectDate(_startDateController),
                    decoration: InputDecoration(
                      labelText: 'Startdatum lezen (DD-MM-JJJJ)',
                      filled: true,
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _endDateController,
                    readOnly: true,
                    onTap: () => _selectDate(_endDateController),
                    decoration: InputDecoration(
                      labelText: 'Einddatum lezen (DD-MM-JJJJ)',
                      filled: true,
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                      helperText: 'Jaar gelezen wordt automatisch bepaald vanuit deze datum',
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      widget.book == null ? 'Boek Toevoegen' : 'Opslaan',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_showSearchResults)
            GestureDetector(
              onTap: () => setState(() => _showSearchResults = false),
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.7,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_searchResults.length} resultaten gevonden',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() => _showSearchResults = false),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final book = _searchResults[index];
                                final volumeInfo = book['volumeInfo'] as Map<String, dynamic>;
                                final title = volumeInfo['title'] ?? 'Geen titel';
                                final authors = volumeInfo['authors'] as List<dynamic>?;
                                final author = authors?.join(', ') ?? 'Onbekende auteur';
                                final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
                                final isbn = identifiers?.isNotEmpty == true 
                                    ? identifiers!.first['identifier'] 
                                    : 'Geen ISBN';
                                final publisher = volumeInfo['publisher'] ?? '';
                                final publishedDate = volumeInfo['publishedDate'] ?? '';
                                final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
                                final thumbnailUrl = imageLinks?['thumbnail'] ?? imageLinks?['smallThumbnail'];
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  child: InkWell(
                                    onTap: () => _selectBook(book),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Cover thumbnail
                                          if (thumbnailUrl != null)
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: CoverImage(
                                                imageUrl: thumbnailUrl.toString().replaceFirst('http://', 'https://'),
                                                width: 50,
                                                height: 70,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 50,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.book,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          const SizedBox(width: 12),
                                          // Book info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  author,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (publisher.isNotEmpty || publishedDate.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    [
                                                      if (publisher.isNotEmpty) publisher,
                                                      if (publishedDate.isNotEmpty) publishedDate,
                                                    ].join(' • '),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                                if (isbn != 'Geen ISBN') ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'ISBN: $isbn',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // Arrow icon to indicate clickability
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
