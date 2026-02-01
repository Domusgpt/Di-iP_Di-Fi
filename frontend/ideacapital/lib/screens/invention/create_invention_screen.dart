import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

/// The "Agent Composer" screen.
/// Users upload rough ideas (voice, sketch, text) and the AI structures them.
class CreateInventionScreen extends ConsumerStatefulWidget {
  const CreateInventionScreen({super.key});

  @override
  ConsumerState<CreateInventionScreen> createState() =>
      _CreateInventionScreenState();
}

class _CreateInventionScreenState extends ConsumerState<CreateInventionScreen> {
  final _ideaController = TextEditingController();
  final _uuid = const Uuid();
  final _dio = Dio();

  bool _isProcessing = false;
  int _currentStep = 0;
  String? _selectedInputMethod; // 'text', 'voice', 'sketch'

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _voiceFilePath;
  Timer? _recordingTimer;
  int _recordingDurationSeconds = 0;

  // Sketch upload state
  String? _sketchUrl;
  File? _sketchLocalFile;

  @override
  void dispose() {
    _ideaController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Your Idea'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _currentStep > 0
            ? () => setState(() => _currentStep--)
            : null,
        steps: [
          // Step 1: Choose input method
          Step(
            title: const Text('Share Your Idea'),
            subtitle: const Text('Text, voice note, or sketch'),
            isActive: _currentStep >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'How would you like to describe your invention?',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                _InputMethodCard(
                  icon: Icons.edit_note,
                  title: 'Write it out',
                  subtitle: 'Type or paste your idea',
                  selected: _selectedInputMethod == 'text',
                  onTap: () =>
                      setState(() => _selectedInputMethod = 'text'),
                ),
                const SizedBox(height: 8),
                _InputMethodCard(
                  icon: Icons.mic,
                  title: 'Voice note',
                  subtitle: 'Record yourself explaining it',
                  selected: _selectedInputMethod == 'voice',
                  onTap: () =>
                      setState(() => _selectedInputMethod = 'voice'),
                ),
                const SizedBox(height: 8),
                _InputMethodCard(
                  icon: Icons.draw,
                  title: 'Upload a sketch',
                  subtitle: 'Photo of a napkin drawing, diagram, etc.',
                  selected: _selectedInputMethod == 'sketch',
                  onTap: () =>
                      setState(() => _selectedInputMethod = 'sketch'),
                ),
              ],
            ),
          ),

          // Step 2: Provide the idea
          Step(
            title: const Text('Describe It'),
            isActive: _currentStep >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedInputMethod == 'text') ...[
                  TextField(
                    controller: _ideaController,
                    decoration: const InputDecoration(
                      hintText:
                          'Describe your invention... What problem does it solve? How does it work?',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 8,
                    maxLength: 2000,
                  ),
                ] else if (_selectedInputMethod == 'voice') ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            _isRecording ? Icons.graphic_eq : Icons.mic,
                            size: 48,
                            color: _isRecording
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          if (_isRecording) ...[
                            Text(
                              'Recording... ${_formatDuration(_recordingDurationSeconds)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: null,
                              color: Colors.red.shade300,
                            ),
                          ] else if (_voiceFilePath != null) ...[
                            const Icon(Icons.check_circle,
                                size: 32, color: Colors.green),
                            const SizedBox(height: 8),
                            Text(
                              'Voice note recorded (${_formatDuration(_recordingDurationSeconds)})',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ] else ...[
                            const Text('Tap to start recording'),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed:
                                _isRecording ? _stopRecording : _startRecording,
                            icon: Icon(_isRecording
                                ? Icons.stop
                                : Icons.fiber_manual_record),
                            label: Text(_isRecording ? 'Stop' : 'Record'),
                            style: _isRecording
                                ? FilledButton.styleFrom(
                                    backgroundColor: Colors.red)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_selectedInputMethod == 'sketch') ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          if (_sketchLocalFile != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _sketchLocalFile!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_sketchUrl != null)
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 16, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text('Uploaded',
                                      style: TextStyle(color: Colors.green)),
                                ],
                              ),
                          ] else ...[
                            Icon(Icons.add_photo_alternate,
                                size: 48,
                                color: theme.colorScheme.primary),
                            const SizedBox(height: 12),
                            const Text('Upload your sketch or diagram'),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Camera'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Gallery'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Step 3: AI Processing
          Step(
            title: const Text('AI Analysis'),
            subtitle: const Text('Our AI structures your idea'),
            isActive: _currentStep >= 2,
            content: _isProcessing
                ? const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('The AI is analyzing your idea...'),
                      SizedBox(height: 8),
                      Text(
                        'Structuring patent claims, checking prior art, generating visuals...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : const Column(
                    children: [
                      Icon(Icons.auto_awesome, size: 48),
                      SizedBox(height: 16),
                      Text('Ready to analyze your idea with AI'),
                      SizedBox(height: 8),
                      Text(
                        'This will generate a structured campaign page with title, summary, technical claims, and concept art.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep == 0 && _selectedInputMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an input method')),
      );
      return;
    }
    if (_currentStep == 2) {
      _submitToAgent();
      return;
    }
    setState(() => _currentStep++);
  }

  // ---------------------------------------------------------------------------
  // Voice Recording
  // ---------------------------------------------------------------------------

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Microphone permission is required')),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/voice_${_uuid.v4()}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordingDurationSeconds = 0;
        _voiceFilePath = null;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingDurationSeconds++);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      if (path != null && mounted) {
        setState(() {
          _isRecording = false;
          _voiceFilePath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Image / Sketch Upload
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (image == null) return;

    final file = File(image.path);
    setState(() {
      _sketchLocalFile = file;
      _sketchUrl = null; // reset until upload completes
    });

    try {
      final fileId = _uuid.v4();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('inventions/sketches/$fileId.jpg');

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() => _sketchUrl = downloadUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload sketch: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Submit to Brain API
  // ---------------------------------------------------------------------------

  Future<void> _submitToAgent() async {
    setState(() => _isProcessing = true);

    try {
      String? voiceUrl;

      // Upload voice file to Firebase Storage if it exists
      if (_voiceFilePath != null) {
        try {
          final fileId = _uuid.v4();
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('inventions/voice/$fileId.m4a');

          final uploadTask = storageRef.putFile(
            File(_voiceFilePath!),
            SettableMetadata(contentType: 'audio/mp4'),
          );

          final snapshot = await uploadTask;
          voiceUrl = await snapshot.ref.getDownloadURL();
        } catch (e) {
          debugPrint('Voice upload failed: $e');
          // Continue without voice - the text input may still be sufficient
        }
      }

      // POST to the backend which proxies to the Brain API
      final response = await _dio.post(
        '/api/inventions/analyze',
        data: {
          'raw_text': _ideaController.text.isNotEmpty
              ? _ideaController.text
              : null,
          'voice_url': voiceUrl,
          'sketch_url': _sketchUrl,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>;
      final inventionId = data['invention_id'] as String;

      // Navigate to the AI-processed invention detail page
      context.go('/invention/$inventionId');
    } on DioException catch (e) {
      if (!mounted) return;

      final message = e.response?.data?['detail'] ??
          e.message ??
          'Failed to analyze your idea. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$message'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _submitToAgent,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _InputMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _InputMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(icon,
            color: selected ? theme.colorScheme.onPrimaryContainer : null),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: onTap,
      ),
    );
  }
}
