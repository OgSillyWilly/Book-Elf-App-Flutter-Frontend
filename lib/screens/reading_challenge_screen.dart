import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading_challenge.dart';
import '../models/book.dart';
import '../services/interfaces/i_data_service.dart';
import '../services/api_exceptions.dart';
import '../service_locator.dart';
import '../utils/error_dialog.dart';
import '../widgets/cover_image.dart';

class ReadingChallengeScreen extends StatefulWidget {
  const ReadingChallengeScreen({super.key});

  @override
  State<ReadingChallengeScreen> createState() => _ReadingChallengeScreenState();
}

class _ReadingChallengeScreenState extends State<ReadingChallengeScreen> {
  late final IDataService _dataService;
  ReadingChallenge? _activeChallenge;
  List<ReadingChallenge> _allChallenges = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    try {
      final active = await _dataService.getActiveChallenge();
      final all = await _dataService.getReadingChallenges();
      setState(() {
        _activeChallenge = active;
        _allChallenges = all;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(context, 'Fout bij laden challenges', e.toString());
      }
    }
  }

  Future<void> _deleteChallenge(ReadingChallenge challenge) async {
    if (challenge.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Challenge verwijderen'),
        content: Text('Weet je zeker dat je "${challenge.name}" wilt verwijderen?'),
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
        await _dataService.deleteChallenge(challenge.id!);
        _loadChallenges();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Challenge verwijderd')),
          );
        }
      } catch (e) {
        if (mounted) {
          showErrorDialog(context, 'Fout bij verwijderen', e.toString());
        }
      }
    }
  }

  void _showChallengeForm({ReadingChallenge? challenge}) {
    showDialog(
      context: context,
      builder: (context) => ChallengeFormDialog(
        challenge: challenge,
        onSaved: () {
          Navigator.pop(context);
          _loadChallenges();
        },
      ),
    );
  }

  void _showChallengeDetails(ReadingChallenge challenge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeDetailScreen(challengeId: challenge.id!),
      ),
    ).then((_) => _loadChallenges());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lees Uitdagingen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showChallengeForm(),
            tooltip: 'Nieuwe challenge',
          ),
        ],
        bottom: TabBar(
          tabs: const [
            Tab(text: 'Actief'),
            Tab(text: 'Alle Challenges'),
          ],
          onTap: (index) => setState(() => _selectedTab = index),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedTab == 0
              ? _buildActiveTab()
              : _buildAllChallengesTab(),
    );
  }

  Widget _buildActiveTab() {
    if (_activeChallenge == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Geen actieve challenge',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showChallengeForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nieuwe challenge starten'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChallengeCard(
              challenge: _activeChallenge!,
              isDetailed: true,
              onTap: () => _showChallengeDetails(_activeChallenge!),
              onEdit: () => _showChallengeForm(challenge: _activeChallenge),
              onDelete: () => _deleteChallenge(_activeChallenge!),
            ),
            const SizedBox(height: 24),
            if (_activeChallenge!.id != null) _ChallengeSuggestionsWidget(
              challengeId: _activeChallenge!.id!,
              apiService: _dataService,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllChallengesTab() {
    if (_allChallenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Geen challenges gevonden',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showChallengeForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nieuwe challenge toevoegen'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.builder(
        itemCount: _allChallenges.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final challenge = _allChallenges[index];
          return _ChallengeCard(
            challenge: challenge,
            onTap: () => _showChallengeDetails(challenge),
            onEdit: () => _showChallengeForm(challenge: challenge),
            onDelete: () => _deleteChallenge(challenge),
          );
        },
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ReadingChallenge challenge;
  final bool isDetailed;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChallengeCard({
    required this.challenge,
    this.isDetailed = false,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = challenge.localProgressPercentage;
    final remaining = challenge.localRemainingBooks;
    final daysRemaining = challenge.daysRemaining ?? 0;
    final isOnTrack = challenge.isOnTrack ?? true;

    return Card(
      margin: EdgeInsets.only(bottom: isDetailed ? 0 : 12),
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
                        Row(
                          children: [
                            if (challenge.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIEF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                challenge.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('d MMM yyyy').format(challenge.startDate)} - ${DateFormat('d MMM yyyy').format(challenge.endDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDetailed)
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
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                    ),
                ],
              ),
              if (challenge.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  challenge.description!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: isDetailed ? null : 2,
                  overflow: isDetailed ? null : TextOverflow.ellipsis,
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
                          '${challenge.booksRead} / ${challenge.goalBooks} boeken',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 10,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 100 ? Colors.green : Theme.of(context).primaryColor,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: progress >= 100 ? Colors.green : Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              if (isDetailed) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Icons.menu_book,
                        label: 'Nog te lezen',
                        value: '$remaining',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.calendar_today,
                        label: 'Dagen over',
                        value: '$daysRemaining',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOnTrack ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOnTrack ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOnTrack ? Icons.check_circle : Icons.warning,
                        color: isOnTrack ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isOnTrack
                              ? 'Je ligt op schema! 🎉'
                              : 'Je ligt achter op je doelstelling',
                          style: TextStyle(
                            color: isOnTrack ? Colors.green[900] : Colors.orange[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeSuggestionsWidget extends StatefulWidget {
  final int challengeId;
  final IDataService apiService;

  const _ChallengeSuggestionsWidget({
    required this.challengeId,
    required this.apiService,
  });

  @override
  State<_ChallengeSuggestionsWidget> createState() => _ChallengeSuggestionsWidgetState();
}

class _ChallengeSuggestionsWidgetState extends State<_ChallengeSuggestionsWidget> {
  List<Book> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.apiService.getChallengeSuggestions(widget.challengeId, limit: 5);
      setState(() {
        final suggestionsData = data['suggestions'] as List;
        _suggestions = suggestionsData.map((json) => Book.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggesties voor je challenge',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_suggestions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Geen suggesties beschikbaar',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final book = _suggestions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
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
                          color: Colors.grey[300],
                          child: const Icon(Icons.book),
                        ),
                  title: Text(book.title),
                  subtitle: Text(book.author),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              );
            },
          ),
      ],
    );
  }
}

// Challenge Form Dialog
class ChallengeFormDialog extends StatefulWidget {
  final ReadingChallenge? challenge;
  final VoidCallback onSaved;

  const ChallengeFormDialog({
    super.key,
    this.challenge,
    required this.onSaved,
  });

  @override
  State<ChallengeFormDialog> createState() => _ChallengeFormDialogState();
}

class _ChallengeFormDialogState extends State<ChallengeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _goalBooksController;
  late DateTime _startDate;
  late DateTime _endDate;
  String _periodType = 'yearly';
  bool _isActive = true;
  bool _isSaving = false;
  late final IDataService _dataService;

  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
    _nameController = TextEditingController(text: widget.challenge?.name);
    _descriptionController = TextEditingController(text: widget.challenge?.description);
    _goalBooksController = TextEditingController(
      text: widget.challenge?.goalBooks.toString() ?? '',
    );
    _startDate = widget.challenge?.startDate ?? DateTime.now();
    _endDate = widget.challenge?.endDate ?? DateTime(DateTime.now().year, 12, 31);
    _periodType = widget.challenge?.periodType ?? 'yearly';
    _isActive = widget.challenge?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalBooksController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text,
      'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      'goal_books': int.parse(_goalBooksController.text),
      'period_type': _periodType,
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      'is_active': _isActive,
    };

    try {
      if (widget.challenge?.id != null) {
        await _dataService.updateChallenge(widget.challenge!.id!, data);
      } else {
        await _dataService.createChallenge(data);
      }

      if (mounted) {
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.challenge != null ? 'Challenge bijgewerkt' : 'Challenge toegevoegd'),
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
      title: Text(widget.challenge != null ? 'Challenge bewerken' : 'Nieuwe challenge'),
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
                controller: _goalBooksController,
                decoration: const InputDecoration(
                  labelText: 'Aantal boeken *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Aantal boeken is verplicht';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 1) {
                    return 'Voer een geldig getal in';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _periodType,
                decoration: const InputDecoration(
                  labelText: 'Periode type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Maandelijks')),
                  DropdownMenuItem(value: 'yearly', child: Text('Jaarlijks')),
                  DropdownMenuItem(value: 'custom', child: Text('Aangepast')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _periodType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('d MMM yyyy').format(_startDate)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('-'),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, false),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('d MMM yyyy').format(_endDate)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschrijving',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Actief'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
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
          onPressed: _isSaving ? null : _saveChallenge,
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

// Challenge Detail Screen
class ChallengeDetailScreen extends StatefulWidget {
  final int challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  late final IDataService _dataService;
  bool _isLoading = true;
  ReadingChallenge? _challenge;
  List<Book> _booksRead = [];

  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
    _loadChallengeDetails();
  }

  Future<void> _loadChallengeDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dataService.getChallengeWithDetails(widget.challengeId);
      setState(() {
        _challenge = ReadingChallenge.fromJson(data['challenge']);
        final booksData = data['books_read'] as List;
        _booksRead = booksData.map((json) => Book.fromJson(json)).toList();
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
        title: Text(_challenge?.name ?? 'Challenge details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _challenge == null
              ? const Center(child: Text('Challenge niet gevonden'))
              : RefreshIndicator(
                  onRefresh: _loadChallengeDetails,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChallengeCard(
                          challenge: _challenge!,
                          isDetailed: true,
                          onTap: () {},
                          onEdit: () {},
                          onDelete: () {},
                        ),
                        const SizedBox(height: 24),
                        if (_booksRead.isNotEmpty) ...[
                          Text(
                            'Gelezen boeken (${_booksRead.length})',
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
                            itemCount: _booksRead.length,
                            itemBuilder: (context, index) {
                              final book = _booksRead[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
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
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.book),
                                        ),
                                  title: Text(book.title),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(book.author),
                                      if (book.endDate != null)
                                        Text(
                                          'Gelezen: ${DateFormat('d MMM yyyy').format(DateTime.parse(book.endDate!))}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                    ],
                                  ),
                                  trailing: book.rating != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, size: 16, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text('${book.rating}'),
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
                                'Nog geen boeken gelezen',
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
