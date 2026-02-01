import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _isProcessing = false;
  int _currentStep = 0;
  String? _selectedInputMethod; // 'text', 'voice', 'sketch'

  @override
  void dispose() {
    _ideaController.dispose();
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
                          Icon(Icons.mic, size: 48,
                              color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          const Text('Tap to start recording'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              // TODO: Start voice recording via record package
                            },
                            icon: const Icon(Icons.fiber_manual_record),
                            label: const Text('Record'),
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
                          Icon(Icons.add_photo_alternate, size: 48,
                              color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          const Text('Upload your sketch or diagram'),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) {
      // TODO: Upload to Firebase Storage, then attach URL to draft
    }
  }

  Future<void> _submitToAgent() async {
    setState(() => _isProcessing = true);
    try {
      // TODO: Send to Brain API (Python FastAPI) via Cloud Function proxy
      // POST /api/inventions/analyze
      // Body: { raw_text, voice_url, sketch_url }
      // Response: structured Invention JSON
      await Future.delayed(const Duration(seconds: 3)); // Placeholder
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
