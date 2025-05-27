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
  String _analysisStatus = '';

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
                          'Capture Tips for Best Results',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTipItem('📄', 'Place document on flat, contrasting surface'),
                        _buildTipItem('💡', 'Use bright, even lighting (avoid shadows)'),
                        _buildTipItem('📐', 'Keep camera parallel and centered'),
                        _buildTipItem('🔍', 'Fill frame with document (include all edges)'),
                        _buildTipItem('📱', 'Hold steady and tap to focus before capture'),
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
                    icon: _isAnalyzing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.camera_alt, size: 28),
                    label: Text(
                      _isAnalyzing ? 'Analyzing Document...' : 'Open Camera',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAnalyzing ? Colors.grey : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Gallery option for testing
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _captureImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, size: 24),
                    label: const Text(
                      'Choose from Gallery',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                
                if (_isAnalyzing) ...[
                  const SizedBox(height: 30),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _analysisStatus.isEmpty 
                                ? 'Processing image...' 
                                : _analysisStatus,
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This may take a few moments for accurate results',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
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
      // Request appropriate permissions
      late PermissionStatus permissionStatus;
      
      if (source == ImageSource.camera) {
        permissionStatus = await Permission.camera.request();
        if (!permissionStatus.isGranted) {
          _showErrorSnackBar('Camera permission is required');
          return;
        }
      } else {
        // For gallery access
        permissionStatus = await Permission.photos.request();
        if (!permissionStatus.isGranted) {
          // Try storage permission for older Android versions
          permissionStatus = await Permission.storage.request();
          if (!permissionStatus.isGranted) {
            _showErrorSnackBar('Storage permission is required to access gallery');
            return;
          }
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100, // Maximum quality for better analysis
        maxWidth: 4096,    // Higher resolution for better analysis
        maxHeight: 4096,
        preferredCameraDevice: CameraDevice.rear, // Use rear camera for documents
      );

      if (image != null) {
        setState(() {
          _isAnalyzing = true;
          _analysisStatus = 'Loading image...';
        });

        try {
          // Update status
          setState(() {
            _analysisStatus = 'Preprocessing image...';
          });
          
          await Future.delayed(const Duration(milliseconds: 500)); // Allow UI update
          
          setState(() {
            _analysisStatus = 'Analyzing document features...';
          });
          
          // Analyze the image
          final analysis = await _analysisService.analyzeDocument(image.path);
          
          setState(() {
            _analysisStatus = 'Saving results...';
          });
          
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
          print('Analysis error: $e');
          _showErrorSnackBar('Failed to analyze document: ${e.toString()}');
        } finally {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _analysisStatus = '';
            });
          }
        }
      }
    } catch (e) {
      print('Capture error: $e');
      _showErrorSnackBar('Failed to capture image: ${e.toString()}');
      setState(() {
        _isAnalyzing = false;
        _analysisStatus = '';
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }
}