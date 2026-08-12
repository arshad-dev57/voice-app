import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const SpeechDiagnosticApp());
}

class SpeechDiagnosticApp extends StatelessWidget {
  const SpeechDiagnosticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SpeechDiagnosticScreen(),
    );
  }
}

class SpeechDiagnosticScreen extends StatefulWidget {
  @override
  State<SpeechDiagnosticScreen> createState() => _SpeechDiagnosticScreenState();
}

class _SpeechDiagnosticScreenState extends State<SpeechDiagnosticScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isAvailable = false;
  String _status = 'Not initialized';
  String _recognizedText = '';
  List<String> _log = [];

  void _addLog(String message) {
    setState(() {
      _log.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    print(message);
  }

  void _onSpeechError(dynamic error) {
    // speech_to_text passes the error directly, we'll just log it
    _addLog('Speech Error: $error');
  }

  void _onSpeechStatus(String status) {
    _addLog('Speech Status: $status');
  }

  Future<void> _initialize() async {
    _addLog('Checking speech recognition availability...');
    _isAvailable = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    _isInitialized = true;
    
    _addLog('Available: $_isAvailable');
    _addLog('Has permission: ${await _speech.hasPermission}');
    
    if (_isAvailable) {
      final locales = await _speech.locales();
      _addLog('Available locales: ${locales.length}');
      for (var locale in locales.take(5)) {
        _addLog('  - ${locale.localeId}: ${locale.name}');
      }
    }
    
    setState(() {
      _status = _isAvailable ? 'Available' : 'Not Available';
    });
  }

  Future<void> _startListening() async {
    if (!_isAvailable) {
      _addLog('Speech recognition not available');
      return;
    }

    _addLog('Starting listening...');
    setState(() {
      _recognizedText = '';
    });

    await _speech.listen(
      onResult: (result) {
        _addLog('Result: "${result.recognizedWords}" (final: ${result.finalResult})');
        setState(() {
          _recognizedText = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 10),
      localeId: 'en-US',
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    _addLog('Stopped listening');
  }

  Future<void> _cancelListening() async {
    await _speech.cancel();
    _addLog('Cancelled listening');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speech Recognition Diagnostic')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isInitialized ? null : _initialize,
                  child: const Text('Initialize'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isAvailable ? _startListening : null,
                  child: const Text('Start Listening'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _speech.isListening ? _stopListening : null,
                  child: const Text('Stop'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _speech.isListening ? _cancelListening : null,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Recognized Text:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_recognizedText.isEmpty ? 'No speech detected' : _recognizedText),
            const SizedBox(height: 16),
            const Text('Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, index) {
                  return Text(_log[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
