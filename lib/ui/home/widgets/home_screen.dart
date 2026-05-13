import '../view_models/home_viewmodel.dart';

import 'package:asr_application/ui/core/ui/app_header.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'DISC'),
            const Expanded(
              child: Center(
                child: Text(
                  'Klik op de knop om te beginnen.',
                  style: TextStyle(color: Colors.black, fontSize: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(23, 0, 23, 28),
              child: SizedBox(
                width: double.infinity,
                height: 37,
                child: AnimatedBuilder(
                  animation: viewModel,
                  builder: (context, _) {
                    final isTranscribing = viewModel.isTranscribing;

                    return FilledButton.icon(
                      onPressed: viewModel.toggleTranscribing,
                      style: FilledButton.styleFrom(
                        backgroundColor: isTranscribing ? const Color(0xFFFFB81C) : const Color(0xFFA50034),
                        foregroundColor: isTranscribing ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(
                        isTranscribing ? Icons.stop : Icons.mic,
                        size: 16,
                      ),
                      label: Text(
                        isTranscribing
                            ? 'Stop met luisteren'
                            : 'Begin met luisteren',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
