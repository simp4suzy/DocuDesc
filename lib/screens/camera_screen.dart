import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/image_analysis_service.dart';
import '../services/database_service.dart';
import 'results_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final ImageAnalysisService _analysisService = ImageAnalysisService();
  bool _isAnalyzing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Document'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Instructions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Capture Tips',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTipItem('📄', 'Place document on flat surface'),
                        _buildTipItem('💡', 'Ensure good lighting'),
                        _buildTipItem('📐', 'Keep camera parallel to document'),
                        _buildTipItem('🔍', 'Include entire document in frame'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Camera Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _captureImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: Text(
                      _isAnalyzing ? 'Analyzing...' : 'Open Camera',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Gallery Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _captureImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, size: 28),
                    label: const Text(
                      'Choose from Gallery',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                
                if (_isAnalyzing) ...[
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Analyzing document...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String emoji, String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      // Request permissions
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          _showErrorSnackBar('Camera permission is required');
          return;
        }
      } else {
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          _showErrorSnackBar('Photo library permission is required');
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _isAnalyzing = true;
        });

        try {
          // Analyze the image
          final analysis = await _analysisService.analyzeDocument(image.path);
          
          // Save to database
          await DatabaseService.instance.createDocument(analysis);

          // Navigate to results
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ResultsScreen(analysis: analysis),
              ),
            );
          }
        } catch (e) {
          _showErrorSnackBar('Failed to analyze document: ${e.toString()}');
        } finally {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
            });
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to capture image: ${e.toString()}');
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}