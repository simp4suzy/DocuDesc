import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
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

    print('Original image dimensions: ${image.width} x ${image.height}');

    // Enhanced preprocessing pipeline
    final processedImage = _preprocessImage(image);
    
    // Detect document boundaries first
    final documentBounds = _detectDocumentBounds(processedImage);
    print('Document bounds detected: $documentBounds');
    
    // Analyze with detected bounds
    final paperSize = _determinePaperSize(processedImage);
    final fontSize = await _estimateFontSize(processedImage, documentBounds);
    final margins = _calculateMarginsFromBounds(processedImage, documentBounds);

    print('Analysis results - Paper: $paperSize, Font: $fontSize, Margins: $margins');

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

  // Enhanced preprocessing with better noise reduction
  img.Image _preprocessImage(img.Image image) {
    // Convert to grayscale
    var processed = img.grayscale(image);
    
    // Apply slight Gaussian blur to reduce noise
    processed = img.gaussianBlur(processed, radius: 1);
    
    // Enhance contrast for better text detection
    processed = img.contrast(processed, contrast: 1.2);
    
    // Apply brightness adjustment if needed
    processed = img.adjustColor(processed, brightness: 1.1);
    
    return processed;
  }

  // Improved document boundary detection
  Map<String, int> _detectDocumentBounds(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    print('Starting boundary detection for ${width}x$height image');
    
    // Method 1: Content-based detection (more reliable for text documents)
    final contentBounds = _detectContentBounds(image);
    print('Content bounds: $contentBounds');
    
    // Method 2: Edge-based detection as fallback
    final edgeBounds = _detectEdgeBasedBounds(image);
    print('Edge bounds: $edgeBounds');
    
    // Method 3: Projection-based detection
    final projectionBounds = _detectProjectionBounds(image);
    print('Projection bounds: $projectionBounds');
    
    // Combine results intelligently
    final finalBounds = {
      'top': _selectBestBound([contentBounds['top']!, edgeBounds['top']!, projectionBounds['top']!], height, true),
      'bottom': _selectBestBound([contentBounds['bottom']!, edgeBounds['bottom']!, projectionBounds['bottom']!], height, false),
      'left': _selectBestBound([contentBounds['left']!, edgeBounds['left']!, projectionBounds['left']!], width, true),
      'right': _selectBestBound([contentBounds['right']!, edgeBounds['right']!, projectionBounds['right']!], width, false),
    };
    
    print('Final selected bounds: $finalBounds');
    return finalBounds;
  }

  // New projection-based method for more accurate boundary detection
  Map<String, int> _detectProjectionBounds(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Horizontal projection (for top/bottom)
    List<int> horizontalProjection = [];
    for (int y = 0; y < height; y++) {
      int darkPixels = 0;
      for (int x = 0; x < width; x++) {
        int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
        if (luminance < 200) darkPixels++;
      }
      horizontalProjection.add(darkPixels);
    }
    
    // Vertical projection (for left/right)
    List<int> verticalProjection = [];
    for (int x = 0; x < width; x++) {
      int darkPixels = 0;
      for (int y = 0; y < height; y++) {
        int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
        if (luminance < 200) darkPixels++;
      }
      verticalProjection.add(darkPixels);
    }
    
    // Find boundaries based on projection thresholds
    int contentThresholdH = (width * 0.05).round(); // Minimum dark pixels for content row
    int contentThresholdV = (height * 0.05).round(); // Minimum dark pixels for content column
    
    int top = _findFirstSignificantProjection(horizontalProjection, contentThresholdH, true);
    int bottom = _findFirstSignificantProjection(horizontalProjection, contentThresholdH, false);
    int left = _findFirstSignificantProjection(verticalProjection, contentThresholdV, true);
    int right = _findFirstSignificantProjection(verticalProjection, contentThresholdV, false);
    
    return {
      'top': top,
      'bottom': bottom,
      'left': left,
      'right': right,
    };
  }
  
  int _findFirstSignificantProjection(List<int> projection, int threshold, bool fromStart) {
    if (fromStart) {
      for (int i = 0; i < projection.length; i++) {
        if (projection[i] > threshold) {
          // Look for sustained content
          int consecutiveCount = 0;
          for (int j = i; j < math.min(i + 5, projection.length); j++) {
            if (projection[j] > threshold ~/ 2) consecutiveCount++;
          }
          if (consecutiveCount >= 3) return math.max(0, i - 2);
        }
      }
      return (projection.length * 0.05).round();
    } else {
      for (int i = projection.length - 1; i >= 0; i--) {
        if (projection[i] > threshold) {
          // Look for sustained content
          int consecutiveCount = 0;
          for (int j = i; j >= math.max(i - 5, 0); j--) {
            if (projection[j] > threshold ~/ 2) consecutiveCount++;
          }
          if (consecutiveCount >= 3) return math.min(projection.length - 1, i + 2);
        }
      }
      return projection.length - (projection.length * 0.05).round();
    }
  }

  Map<String, int> _detectEdgeBasedBounds(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Apply edge detection
    final edgeImage = _simpleEdgeDetection(image);
    
    // Find edges by scanning from borders
    int top = _findTopEdgeImproved(edgeImage);
    int bottom = _findBottomEdgeImproved(edgeImage);
    int left = _findLeftEdgeImproved(edgeImage);
    int right = _findRightEdgeImproved(edgeImage);
    
    return {
      'top': top,
      'bottom': bottom,
      'left': left,
      'right': right,
    };
  }

  // Simplified but more reliable edge detection
  img.Image _simpleEdgeDetection(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Simple gradient calculation
        int current = img.getLuminance(image.getPixel(x, y)).toInt();
        int right = img.getLuminance(image.getPixel(x + 1, y)).toInt();
        int down = img.getLuminance(image.getPixel(x, y + 1)).toInt();
        
        int gradientX = (right - current).abs();
        int gradientY = (down - current).abs();
        int gradient = gradientX + gradientY;
        
        gradient = math.min(255, gradient);
        result.setPixel(x, y, img.ColorRgb8(gradient, gradient, gradient));
      }
    }
    
    return result;
  }

  int _findTopEdgeImproved(img.Image edgeImage) {
    final width = edgeImage.width;
    final height = edgeImage.height;
    
    // Start from top and look for first significant edge activity
    for (int y = 0; y < height ~/ 3; y++) {
      int edgePixels = 0;
      int strongEdgePixels = 0;
      
      // Check across the width, focusing on middle section
      for (int x = width ~/ 6; x < (width * 5) ~/ 6; x++) {
        int intensity = img.getLuminance(edgeImage.getPixel(x, y)).toInt();
        if (intensity > 50) edgePixels++;
        if (intensity > 100) strongEdgePixels++;
      }
      
      double edgeRatio = edgePixels / (width * 2 / 3);
      double strongEdgeRatio = strongEdgePixels / (width * 2 / 3);
      
      // Look for significant edge activity
      if (edgeRatio > 0.1 || strongEdgeRatio > 0.05) {
        return math.max(0, y - 3);
      }
    }
    
    return (height * 0.08).round();
  }

  int _findBottomEdgeImproved(img.Image edgeImage) {
    final width = edgeImage.width;
    final height = edgeImage.height;
    
    for (int y = height - 1; y >= height * 2 ~/ 3; y--) {
      int edgePixels = 0;
      int strongEdgePixels = 0;
      
      for (int x = width ~/ 6; x < (width * 5) ~/ 6; x++) {
        int intensity = img.getLuminance(edgeImage.getPixel(x, y)).toInt();
        if (intensity > 50) edgePixels++;
        if (intensity > 100) strongEdgePixels++;
      }
      
      double edgeRatio = edgePixels / (width * 2 / 3);
      double strongEdgeRatio = strongEdgePixels / (width * 2 / 3);
      
      if (edgeRatio > 0.1 || strongEdgeRatio > 0.05) {
        return math.min(height - 1, y + 3);
      }
    }
    
    return height - (height * 0.08).round();
  }

  int _findLeftEdgeImproved(img.Image edgeImage) {
    final width = edgeImage.width;
    final height = edgeImage.height;
    
    for (int x = 0; x < width ~/ 3; x++) {
      int edgePixels = 0;
      int strongEdgePixels = 0;
      
      for (int y = height ~/ 6; y < (height * 5) ~/ 6; y++) {
        int intensity = img.getLuminance(edgeImage.getPixel(x, y)).toInt();
        if (intensity > 50) edgePixels++;
        if (intensity > 100) strongEdgePixels++;
      }
      
      double edgeRatio = edgePixels / (height * 2 / 3);
      double strongEdgeRatio = strongEdgePixels / (height * 2 / 3);
      
      if (edgeRatio > 0.1 || strongEdgeRatio > 0.05) {
        return math.max(0, x - 3);
      }
    }
    
    return (width * 0.08).round();
  }

  int _findRightEdgeImproved(img.Image edgeImage) {
    final width = edgeImage.width;
    final height = edgeImage.height;
    
    for (int x = width - 1; x >= width * 2 ~/ 3; x--) {
      int edgePixels = 0;
      int strongEdgePixels = 0;
      
      for (int y = height ~/ 6; y < (height * 5) ~/ 6; y++) {
        int intensity = img.getLuminance(edgeImage.getPixel(x, y)).toInt();
        if (intensity > 50) edgePixels++;
        if (intensity > 100) strongEdgePixels++;
      }
      
      double edgeRatio = edgePixels / (height * 2 / 3);
      double strongEdgeRatio = strongEdgePixels / (height * 2 / 3);
      
      if (edgeRatio > 0.1 || strongEdgeRatio > 0.05) {
        return math.min(width - 1, x + 3);
      }
    }
    
    return width - (width * 0.08).round();
  }

  // Improved content detection with better thresholding
  Map<String, int> _detectContentBounds(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Detect content by analyzing dark pixel density with adaptive thresholding
    int top = _findContentTopImproved(image);
    int bottom = _findContentBottomImproved(image);
    int left = _findContentLeftImproved(image);
    int right = _findContentRightImproved(image);
    
    return {
      'top': top,
      'bottom': bottom,
      'left': left,
      'right': right,
    };
  }

  int _findContentTopImproved(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Calculate background luminance from corners
    int backgroundLuminance = _calculateBackgroundLuminance(image);
    int contentThreshold = backgroundLuminance - 30; // Adaptive threshold
    
    print('Background luminance: $backgroundLuminance, Content threshold: $contentThreshold');
    
    for (int y = 0; y < height ~/ 2; y++) {
      int contentPixels = 0;
      int totalPixels = 0;
      
      // Sample across most of the width
      for (int x = (width * 0.1).round(); x < (width * 0.9).round(); x++) {
        int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
        if (luminance < contentThreshold) contentPixels++;
        totalPixels++;
      }
      
      double contentRatio = contentPixels / totalPixels;
      
      if (contentRatio > 0.08) { // Lowered threshold for better detection
        // Verify with a few more lines
        bool consistentContent = _verifyConsistentContent(image, y, y + 5, contentThreshold, true);
        if (consistentContent) {
          print('Found content top at y=$y with ratio=$contentRatio');
          return math.max(0, y - 5);
        }
      }
    }
    
    return (height * 0.1).round();
  }

  int _findContentBottomImproved(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    int backgroundLuminance = _calculateBackgroundLuminance(image);
    int contentThreshold = backgroundLuminance - 30;
    
    for (int y = height - 1; y >= height ~/ 2; y--) {
      int contentPixels = 0;
      int totalPixels = 0;
      
      for (int x = (width * 0.1).round(); x < (width * 0.9).round(); x++) {
        int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
        if (luminance < contentThreshold) contentPixels++;
        totalPixels++;
      }
      
      double contentRatio = contentPixels / totalPixels;
      
      if (contentRatio > 0.08) {
        bool consistentContent = _verifyConsistentContent(image, y - 5, y, contentThreshold, true);
        if (consistentContent) {
          print('Found content bottom at y=$y with ratio=$contentRatio');
          return math.min(height - 1, y + 5);
        }
      }
    }
    
    return height - (height * 0.1).round();
  }

  int _findContentLeftImproved(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    int backgroundLuminance = _calculateBackgroundLuminance(image);
    int contentThreshold = backgroundLuminance - 30;
    
    for (int x = 0; x < width ~/ 2; x++) {
      int contentPixels = 0;
      int totalPixels = 0;
      
      for (int y = (height * 0.1).round(); y < (height * 0.9).round(); y++) {
        int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
        if (luminance < contentThreshold) contentPixels++;
        totalPixels++;
      }
      
      double contentRatio = contentPixels / totalPixels;
      
      if (contentRatio > 0.08) {
        bool consistentContent = _verifyConsistentContent(image, x, x + 5, contentThreshold, false);
        if (consistentContent) {
          print('Found content left at x=$x with ratio=$contentRatio');
          return math.max(0, x - 5);
        }
      }
    }
    
    return (width * 0.1).round();
  }

  int _findContentRightImproved(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    int backgroundLuminance = _calculateBackgroundLuminance(image);
    int contentThreshold = backgroundLuminance - 30;
    
    for (int x = width - 1; x >= width ~/ 2; x--) {
      int contentPixels = 0;
      int totalPixels = 0;
      
      for (int y = (height * 0.1).round(); y < (height * 0.9).round(); y++) {
        int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
        if (luminance < contentThreshold) contentPixels++;
        totalPixels++;
      }
      
      double contentRatio = contentPixels / totalPixels;
      
      if (contentRatio > 0.08) {
        bool consistentContent = _verifyConsistentContent(image, x - 5, x, contentThreshold, false);
        if (consistentContent) {
          print('Found content right at x=$x with ratio=$contentRatio');
          return math.min(width - 1, x + 5);
        }
      }
    }
    
    return width - (width * 0.1).round();
  }

  // Calculate background luminance from image corners
  int _calculateBackgroundLuminance(img.Image image) {
    final width = image.width;
    final height = image.height;
    final cornerSize = math.min(width, height) ~/ 20;
    
    List<int> cornerLuminances = [];
    
    // Sample from four corners
    for (int corner = 0; corner < 4; corner++) {
      int startX, startY;
      switch (corner) {
        case 0: startX = 0; startY = 0; break; // Top-left
        case 1: startX = width - cornerSize; startY = 0; break; // Top-right
        case 2: startX = 0; startY = height - cornerSize; break; // Bottom-left
        case 3: startX = width - cornerSize; startY = height - cornerSize; break; // Bottom-right
        default: startX = 0; startY = 0;
      }
      
      int sum = 0;
      int count = 0;
      
      for (int y = startY; y < startY + cornerSize && y < height; y++) {
        for (int x = startX; x < startX + cornerSize && x < width; x++) {
          sum += img.getLuminance(image.getPixel(x, y)).toInt();
          count++;
        }
      }
      
      if (count > 0) {
        cornerLuminances.add(sum ~/ count);
      }
    }
    
    // Return median of corner luminances
    if (cornerLuminances.isNotEmpty) {
      cornerLuminances.sort();
      return cornerLuminances[cornerLuminances.length ~/ 2];
    }
    
    return 240; // Default for white background
  }

  // Verify content consistency in a region
  bool _verifyConsistentContent(img.Image image, int start1, int end1, int threshold, bool isHorizontal) {
    final width = image.width;
    final height = image.height;
    int goodLines = 0;
    int totalLines = 0;
    
    if (isHorizontal) {
      for (int y = start1; y <= end1 && y < height; y++) {
        int contentPixels = 0;
        int totalPixels = 0;
        
        for (int x = (width * 0.1).round(); x < (width * 0.9).round(); x++) {
          int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
          if (luminance < threshold) contentPixels++;
          totalPixels++;
        }
        
        if (totalPixels > 0 && (contentPixels / totalPixels) > 0.03) {
          goodLines++;
        }
        totalLines++;
      }
    } else {
      for (int x = start1; x <= end1 && x < width; x++) {
        int contentPixels = 0;
        int totalPixels = 0;
        
        for (int y = (height * 0.1).round(); y < (height * 0.9).round(); y++) {
          int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
          if (luminance < threshold) contentPixels++;
          totalPixels++;
        }
        
        if (totalPixels > 0 && (contentPixels / totalPixels) > 0.03) {
          goodLines++;
        }
        totalLines++;
      }
    }
    
    return totalLines > 0 && (goodLines / totalLines) > 0.6;
  }

  // Improved bound selection with multiple candidates
  int _selectBestBound(List<int> candidates, int maxDimension, bool isStartBound) {
    // Remove obviously bad candidates
    List<int> validCandidates = candidates.where((bound) {
      double ratio = bound / maxDimension;
      if (isStartBound) {
        return ratio >= 0.01 && ratio <= 0.4; // 1% to 40% from start
      } else {
        double fromEnd = (maxDimension - bound) / maxDimension;
        return fromEnd >= 0.01 && fromEnd <= 0.4; // 1% to 40% from end
      }
    }).toList();
    
    if (validCandidates.isEmpty) {
      // Fallback to default margins
      return isStartBound 
          ? (maxDimension * 0.08).round() 
          : maxDimension - (maxDimension * 0.08).round();
    }
    
    // For start bounds, prefer smaller values (closer to edge)
    // For end bounds, prefer larger values (closer to edge)
    validCandidates.sort();
    
    if (isStartBound) {
      return validCandidates.first;
    } else {
      return validCandidates.last;
    }
  }

  String _determinePaperSize(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    final isLandscape = width > height;
    final aspectRatio = isLandscape ? height / width : width / height;
    
    print('Image aspect ratio: $aspectRatio (${isLandscape ? 'Landscape' : 'Portrait'})');
    
    const tolerance = 0.08;
    
    // A4: 210 x 297 mm -> ratio ≈ 0.707
    if (_isWithinTolerance(aspectRatio, 0.707, tolerance)) {
      return isLandscape ? 'A4 Landscape' : 'A4 Portrait';
    }
    
    // US Letter: 8.5 x 11" -> ratio ≈ 0.773
    if (_isWithinTolerance(aspectRatio, 0.773, tolerance)) {
      return isLandscape ? 'Letter Landscape' : 'Letter Portrait';
    }
    
    // US Legal: 8.5 x 14" -> ratio ≈ 0.607
    if (_isWithinTolerance(aspectRatio, 0.607, tolerance)) {
      return isLandscape ? 'Legal Landscape' : 'Legal Portrait';
    }
    
    return 'Custom Size (${width}x${height})';
  }

  bool _isWithinTolerance(double value, double target, double tolerance) {
    return (value - target).abs() < tolerance;
  }

  Future<double> _estimateFontSize(img.Image image, Map<String, int> bounds) async {
    // Focus analysis on content area
    final contentWidth = bounds['right']! - bounds['left']!;
    final contentHeight = bounds['bottom']! - bounds['top']!;
    
    if (contentWidth <= 0 || contentHeight <= 0) {
      print('Invalid content dimensions, using default font size');
      return 12.0;
    }
    
    // Create content region for analysis
    final contentImage = img.copyCrop(
      image, 
      x: bounds['left']!,
      y: bounds['top']!,
      width: contentWidth,
      height: contentHeight,
    );
    
    final lineHeight = _analyzeLineHeights(contentImage);
    final charWidth = _analyzeCharacterDimensions(contentImage);
    final estimatedDPI = _estimateDPI(image);
    
    // Calculate font size from line height (most reliable)
    double fontSizeFromLines = (lineHeight * 72) / estimatedDPI * 0.8;
    
    // Calculate from character width
    double fontSizeFromChars = (charWidth * 72) / estimatedDPI;
    
    // Weighted average
    double combinedSize = (fontSizeFromLines * 0.7) + (fontSizeFromChars * 0.3);
    
    // Reasonable bounds
    combinedSize = math.max(8.0, math.min(18.0, combinedSize));
    
    print('Font analysis - Line height: $lineHeight px, Char width: $charWidth px, DPI: $estimatedDPI, Final: $combinedSize pt');
    
    return double.parse(combinedSize.toStringAsFixed(1));
  }

  double _analyzeLineHeights(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    List<int> lineHeights = [];
    List<int> rowDensities = [];
    
    // Calculate text density for each row
    for (int y = 0; y < height; y++) {
      int darkPixels = 0;
      for (int x = 0; x < width; x++) {
        int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
        if (luminance < 180) darkPixels++;
      }
      rowDensities.add(darkPixels);
    }
    
    // Find text lines based on density changes
    bool inTextLine = false;
    int lineStart = 0;
    
    for (int y = 0; y < height; y++) {
      double density = rowDensities[y] / width;
      
      if (density > 0.05 && !inTextLine) {
        inTextLine = true;
        lineStart = y;
      } else if (density < 0.02 && inTextLine) {
        inTextLine = false;
        int lineHeight = y - lineStart;
        
        if (lineHeight >= 8 && lineHeight <= 100) {
          lineHeights.add(lineHeight);
        }
      }
    }
    
    if (lineHeights.isEmpty) return 18.0;
    
    // Remove outliers and calculate median
    lineHeights.sort();
    double median = lineHeights.length % 2 == 0
        ? (lineHeights[lineHeights.length ~/ 2 - 1] + lineHeights[lineHeights.length ~/ 2]) / 2.0
        : lineHeights[lineHeights.length ~/ 2].toDouble();
    
    return median;
  }

  double _analyzeCharacterDimensions(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    List<int> charWidths = [];
    
    // Analyze middle section for typical character widths
    int startY = height ~/ 4;
    int endY = (height * 3) ~/ 4;
    
    for (int y = startY; y < endY; y += 3) {
      bool inChar = false;
      int charStart = 0;
      
      for (int x = 0; x < width; x++) {
        int luminance = img.getLuminance(image.getPixel(x, y)).toInt();
        bool isDark = luminance < 180;
        
        if (isDark && !inChar) {
          inChar = true;
          charStart = x;
        } else if (!isDark && inChar) {
          inChar = false;
          int charWidth = x - charStart;
          
          if (charWidth >= 3 && charWidth <= 40) {
            charWidths.add(charWidth);
          }
        }
      }
    }
    
    if (charWidths.isEmpty) return 8.0;
    
    // Calculate median character width
    charWidths.sort();
    double median = charWidths.length % 2 == 0
        ? (charWidths[charWidths.length ~/ 2 - 1] + charWidths[charWidths.length ~/ 2]) / 2.0
        : charWidths[charWidths.length ~/ 2].toDouble();
    
    return median;
  }

  double _estimateDPI(img.Image image) {
    final width = image.width;
    final height = image.height;
    final aspectRatio = width > height ? height / width : width / height;
    final longerSide = math.max(width, height);
    
    // Estimate based on common paper sizes and typical scan/photo resolutions
    if (_isWithinTolerance(aspectRatio, 0.707, 0.08)) {
      // A4 document
      if (longerSide > 3000) return 300.0;      // High-res scan
      if (longerSide > 2000) return 200.0;      // Medium scan
      if (longerSide > 1500) return 150.0;      // Low scan
      return 100.0;                             // Phone photo
    }
    
    if (_isWithinTolerance(aspectRatio, 0.773, 0.08)) {
      // Letter document
      if (longerSide > 3300) return 300.0;
      if (longerSide > 2200) return 200.0;
      if (longerSide > 1650) return 150.0;
      return 100.0;
    }
    
    // Default estimation based on image size
    if (longerSide > 3000) return 250.0;
    if (longerSide > 2000) return 180.0;
    if (longerSide > 1200) return 120.0;
    return 96.0;
  }

  // Fixed margin calculation - this was the main issue!
  Map<String, double> _calculateMarginsFromBounds(img.Image image, Map<String, int> bounds) {
    final width = image.width;
    final height = image.height;
    final estimatedDPI = _estimateDPI(image);
    
    // Calculate margins in pixels
    double topMarginPx = bounds['top']!.toDouble();
    double bottomMarginPx = (height - bounds['bottom']!).toDouble();
    double leftMarginPx = bounds['left']!.toDouble();
    double rightMarginPx = (width - bounds['right']!).toDouble();
    
    print('Margins in pixels - T:$topMarginPx, B:$bottomMarginPx, L:$leftMarginPx, R:$rightMarginPx');
    print('Estimated DPI: $estimatedDPI');
    print('Image dimensions: ${width}x$height');
    
    // Convert to inches - Fixed calculation!
    Map<String, double> marginsInInches = {
      'top': topMarginPx / estimatedDPI,
      'bottom': bottomMarginPx / estimatedDPI,
      'left': leftMarginPx / estimatedDPI,
      'right': rightMarginPx / estimatedDPI,
    };
    
    print('Margins before bounds check: $marginsInInches');
    
    // Apply reasonable bounds but don't force to 0.1 minimum if detection found smaller margins
    marginsInInches.forEach((key, value) {
      // Only apply minimum if the detected margin is unreasonably small (likely detection error)
      if (value < 0.05) {
        marginsInInches[key] = 0.1; // 0.1 inch minimum for very small detections
      } else if (value > 3.0) {
        marginsInInches[key] = 3.0; // 3 inch maximum
      } else {
        marginsInInches[key] = double.parse(value.toStringAsFixed(2)); // Keep detected value
      }
    });
    
    print('Final margins in inches: $marginsInInches');
    
    return marginsInInches;
  }
}