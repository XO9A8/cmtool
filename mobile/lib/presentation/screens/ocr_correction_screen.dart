import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class OcrCorrectionScreen extends StatefulWidget {
  final Map<String, dynamic> parsedData;
  final String screenshotPath;
  final bool isKnockout;

  const OcrCorrectionScreen({
    super.key,
    required this.parsedData,
    required this.screenshotPath,
    this.isKnockout = false,
  });

  @override
  State<OcrCorrectionScreen> createState() => _OcrCorrectionScreenState();
}

class _OcrCorrectionScreenState extends State<OcrCorrectionScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  
  // Fields that are flagged as low confidence by ML Kit
  final Set<String> _lowConfidenceFields = {'possession', 'interceptions'};

  @override
  void initState() {
    super.initState();
    _controllers = {
      'goals_for': TextEditingController(text: widget.parsedData['goals_for']?.toString() ?? ''),
      'goals_against': TextEditingController(text: widget.parsedData['goals_against']?.toString() ?? ''),
      'possession': TextEditingController(text: widget.parsedData['possession']?.toString() ?? ''),
      'passes_completed': TextEditingController(text: widget.parsedData['passes_completed']?.toString() ?? ''),
      'passes_attempted': TextEditingController(text: widget.parsedData['passes_attempted']?.toString() ?? ''),
      'shots_on_target': TextEditingController(text: widget.parsedData['shots_on_target']?.toString() ?? ''),
      'shots_total': TextEditingController(text: widget.parsedData['shots_total']?.toString() ?? ''),
      'interceptions': TextEditingController(text: widget.parsedData['interceptions']?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final gf = double.tryParse(_controllers['goals_for']?.text ?? '0') ?? 0;
      final ga = double.tryParse(_controllers['goals_against']?.text ?? '0') ?? 0;

      if (widget.isKnockout && gf == ga) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Knockout matches cannot end in a draw. Please input the score after penalties or extra time.'),
            backgroundColor: AppColors.lossRed,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      final updatedData = {
        for (var entry in _controllers.entries)
          entry.key: double.tryParse(entry.value.text) ?? 0,
      };
      
      // Return the updated data to the previous screen
      Navigator.pop(context, updatedData);
    }
  }

  Widget _buildTextField(String label, String key) {
    final isLowConfidence = _lowConfidenceFields.contains(key);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: isLowConfidence ? AppColors.lossRed : AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isLowConfidence ? AppColors.lossRed.withValues(alpha: 0.8) : AppColors.textMuted,
          ),
          filled: true,
          fillColor: isLowConfidence 
              ? AppColors.lossRed.withValues(alpha: 0.05) 
              : (AppColors.isLight ? AppColors.surfaceLight : Colors.white.withValues(alpha: 0.05)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isLowConfidence ? AppColors.lossRed : AppColors.cardBorder,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isLowConfidence ? AppColors.lossRed : AppColors.cardBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isLowConfidence ? AppColors.lossRed : AppColors.primary,
            ),
          ),
          prefixIcon: isLowConfidence 
              ? Icon(Icons.warning_amber_rounded, color: AppColors.lossRed)
              : null,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Required field';
          }
          if (double.tryParse(value) == null) {
            return 'Must be a number';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'REVIEW OCR DATA',
          style: GoogleFonts.rajdhani(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // Top 40%: Zoomable Screenshot Preview
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.black45,
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    // Placeholder for actual image: Image.file(File(widget.screenshotPath))
                    Icon(Icons.image, size: 50, color: Colors.white24),
                    // Tapping a field would theoretically animate the InteractiveViewer's TransformationController to zoom into a bounding box here.
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom 60%: Form Fields
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Please verify the extracted values. Low confidence fields are highlighted in red.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Goals For', 'goals_for')),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Goals Against', 'goals_against')),
                          ],
                        ),
                        _buildTextField('Possession %', 'possession'),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Passes Completed', 'passes_completed')),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Passes Attempted', 'passes_attempted')),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Shots on Target', 'shots_on_target')),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Total Shots', 'shots_total')),
                          ],
                        ),
                        _buildTextField('Interceptions', 'interceptions'),
                        
                        const SizedBox(height: 24),
                        
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'CONFIRM & SUBMIT',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
