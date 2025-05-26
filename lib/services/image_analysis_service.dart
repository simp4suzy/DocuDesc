import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/document_model.dart';

class ImageAnalysisService {
  
  Future<DocumentAnalysis> analyzeDocument(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Analyze the document
    final paperSize = _determinePaperSize(image);
    final fontSize = _estimateFontSize(image);
    final margins = _estimateMargins(image);

    return DocumentAnalysis(
      imagePath: imagePath,
      paperSize: paperSize,
      fontSize: fontSize,
      topMargin: margins['top']!,
      bottomMargin: margins['bottom']!,
      leftMargin: margins['left']!,
      rightMargin: margins['right']!,
      createdAt: DateTime.now(),
    );
  }

  String _determinePaperSize(img.Image image) {
    final width = image.width;
    final height = image.height;
    final aspectRatio = width / height;

    // Common paper size aspect ratios
    if ((aspectRatio >= 0.70 && aspectRatio <= 0.72) || 
        (aspectRatio >= 1.39 && aspectRatio <= 1.43)) {
      // A4 ratio is approximately 0.707 (portrait) or 1.414 (landscape)
      if (width > height) {
        return 'A4 Landscape';
      } else {
        return 'A4 Portrait';
      }
    } else if ((aspectRatio >= 0.76 && aspectRatio <= 0.78) || 
               (aspectRatio >= 1.28 && aspectRatio <= 1.32)) {
      // Letter ratio is approximately 0.773 (portrait) or 1.294 (landscape)
      if (width > height) {
        return 'Letter Landscape';
      } else {
        return 'Letter Portrait';
      }
    } else if ((aspectRatio >= 0.60 && aspectRatio <= 0.62) || 
               (aspectRatio >= 1.61 && aspectRatio <= 1.67)) {
      // Legal ratio is approximately 0.607 (portrait) or 1.647 (landscape)
      if (width > height) {
        return 'Legal Landscape';
      } else {
        return 'Legal Portrait';
      }
    }
    
    return 'Custom Size';
  }

  double _estimateFontSize(img.Image image) {
    // Simple font size estimation based on image analysis
    // This is a simplified approach - real implementation would need OCR
    
    final height = image.height;
    
    // Estimate based on document height (simplified approach)
    if (height > 3000) {
      return 14.0; // High resolution, likely standard document
    } else if (height > 2000) {
      return 12.0; // Medium resolution
    } else if (height > 1000) {
      return 11.0; // Lower resolution
    } else {
      return 10.0; // Very low resolution or small document
    }
  }

  Map<String, double> _estimateMargins(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Convert to grayscale for easier analysis
    final grayscale = img.grayscale(image);
    
    // Estimate margins by finding where content typically starts/ends
    // This is a simplified approach
    
    double topMargin = _findTopMargin(grayscale);
    double bottomMargin = _findBottomMargin(grayscale);
    double leftMargin = _findLeftMargin(grayscale);
    double rightMargin = _findRightMargin(grayscale);
    
    // Convert pixel measurements to approximate inches (assuming 150 DPI)
    const dpi = 150.0;
    
    return {
      'top': (topMargin / dpi),
      'bottom': (bottomMargin / dpi),
      'left': (leftMargin / dpi),
      'right': (rightMargin / dpi),
    };
  }

  double _findTopMargin(img.Image image) {
    // Scan from top to find where content starts
    for (int y = 0; y < image.height ~/ 4; y++) {
      int darkPixels = 0;
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance < 200) darkPixels++; // Assuming text is dark
      }
      
      // If we find significant dark content, this might be where text starts
      if (darkPixels > image.width * 0.1) {
        return y.toDouble();
      }
    }
    return image.height * 0.1; // Default 10% margin
  }

  double _findBottomMargin(img.Image image) {
    // Scan from bottom to find where content ends
    for (int y = image.height - 1; y > image.height * 3 ~/ 4; y--) {
      int darkPixels = 0;
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance < 200) darkPixels++;
      }
      
      if (darkPixels > image.width * 0.1) {
        return (image.height - y).toDouble();
      }
    }
    return image.height * 0.1; // Default 10% margin
  }

  double _findLeftMargin(img.Image image) {
    // Scan from left to find where content starts
    for (int x = 0; x < image.width ~/ 4; x++) {
      int darkPixels = 0;
      for (int y = 0; y < image.height; y++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance < 200) darkPixels++;
      }
      
      if (darkPixels > image.height * 0.1) {
        return x.toDouble();
      }
    }
    return image.width * 0.1; // Default 10% margin
  }

  double _findRightMargin(img.Image image) {
    // Scan from right to find where content ends
    for (int x = image.width - 1; x > image.width * 3 ~/ 4; x--) {
      int darkPixels = 0;
      for (int y = 0; y < image.height; y++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance < 200) darkPixels++;
      }
      
      if (darkPixels > image.height * 0.1) {
        return (image.width - x).toDouble();
      }
    }
    return image.width * 0.1; // Default 10% margin
  }
}