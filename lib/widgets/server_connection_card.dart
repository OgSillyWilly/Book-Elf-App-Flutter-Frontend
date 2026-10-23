import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_config.dart';
import '../services/implementations/api_data_service.dart';

class ServerConnectionCard extends StatefulWidget {
  final TextEditingController urlController;
  final VoidCallback onSave;

  const ServerConnectionCard({
    super.key,
    required this.urlController,
    required this.onSave,
  });

  @override
  State<ServerConnectionCard> createState() => _ServerConnectionCardState();
}

class _ServerConnectionCardState extends State<ServerConnectionCard> {
  final _apiService = ApiDataService();
  bool _isTestingConnection = false;
  String? _connectionResult;

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionResult = null;
    });

    try {
      final success = await _apiService.testConnection();
      setState(() {
        _connectionResult = success 
            ? '✅ Verbinding succesvol!'
            : '❌ Kan API niet bereiken';
        _isTestingConnection = false;
      });
    } catch (e) {
      setState(() {
        _connectionResult = '❌ Fout: $e';
        _isTestingConnection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Server Verbinding',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Huidige configuratie:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platform: ${kIsWeb ? 'Web (Chrome)' : 'Mobiel (iPhone)'}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'API URL: ${AppConfig.apiBaseUrl}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.urlController,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'http://127.0.0.1:8000/api',
                helperText: 'Zonder trailing slash',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTestingConnection ? null : _testConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_isTestingConnection ? 'Testen...' : 'Test Verbinding'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onSave,
                    icon: const Icon(Icons.save),
                    label: const Text('Opslaan'),
                  ),
                ),
              ],
            ),
            if (_connectionResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _connectionResult!.startsWith('✅')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _connectionResult!.startsWith('✅')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Text(_connectionResult!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
