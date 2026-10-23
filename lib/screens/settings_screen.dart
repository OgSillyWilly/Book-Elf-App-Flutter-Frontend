import 'package:flutter/material.dart';
import '../utils/settings_helper.dart';
import '../widgets/account_card.dart';
import '../widgets/server_connection_card.dart';
import '../widgets/google_books_api_key_card.dart';
import '../widgets/help_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final url = await SettingsHelper.loadApiUrl();
    final apiKey = await SettingsHelper.loadGoogleBooksApiKey();
    
    if (mounted) {
      _urlController.text = url;
      if (apiKey != null) {
        _apiKeyController.text = apiKey;
      }
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voer een URL in')),
      );
      return;
    }

    await SettingsHelper.saveApiUrl(url);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API URL opgeslagen! Herstart de app.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await SettingsHelper.saveGoogleBooksApiKey(key);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            key.isEmpty
                ? 'API key verwijderd - gebruikt de standaard (gedeelde quota)'
                : 'Google Books API key opgeslagen!',
          ),
          backgroundColor: key.isEmpty ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instellingen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AccountCard(),
          const SizedBox(height: 16),
          ServerConnectionCard(
            urlController: _urlController,
            onSave: _saveUrl,
          ),
          const SizedBox(height: 16),
          GoogleBooksApiKeyCard(
            apiKeyController: _apiKeyController,
            onSave: _saveApiKey,
          ),
          const SizedBox(height: 16),
          const HelpCard(),
        ],
      ),
    );
  }
}
