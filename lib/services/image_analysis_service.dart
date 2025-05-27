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

    // Preprocess the image for better analysis
    final processedImage = _preprocessImage(image);
    
    // Analyze the document with enhanced algorithms
    final paperSize = _determinePaperSize(processedImage);
    final fontSize = await _estimateFontSize(processedImage);
    final margins = _estimateMargins(processedImage);

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

  // Enhanced image preprocessing
  img.Image _preprocessImage(img.Image image) {
    // Convert to grayscale for easier analysis
    var processed = img.grayscale(image);
    
    // Apply contrast enhancement
    processed = img.contrast(processed, contrast: 1.2);
    
    // Apply slight sharpening to help with text detection
    processed = img.convolution(
      processed,
      filter: [
        -1, -1, -1,
        -1,  9, -1,
        -1, -1, -1
      ],
    );
    
    return processed;
  }

  String _determinePaperSize(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    // Determine orientation and calculate aspect ratio
    final isLandscape = width > height;
    final aspectRatio = isLandscape ? height / width : width / height;
    
    print('Image aspect ratio: $aspectRatio (${isLandscape ? 'Landscape' : 'Portrait'})');
    
    // More precise aspect ratio matching with tolerance
    const tolerance = 0.05;
    
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
    
    // A3: 297 x 420 mm -> ratio ≈ 0.707 (but larger)
    if (_isWithinTolerance(aspectRatio, 0.707, tolerance) && (width > 2000 || height > 2000)) {
      return isLandscape ? 'A3 Landscape' : 'A3 Portrait';
    }
    
    // Tabloid: 11 x 17" -> ratio ≈ 0.647
    if (_isWithinTolerance(aspectRatio, 0.647, tolerance)) {
      return isLandscape ? 'Tabloid Landscape' : 'Tabloid Portrait';
    }
    
    return 'Custom Size (${width}x${height})';
  }

  bool _isWithinTolerance(double value, double target, double tolerance) {
    return (value - target).abs() < tolerance;
  }

  // Enhanced font size estimation using multiple techniques
  Future<double> _estimateFontSize(img.Image image) async {
    final width = image.width;
    final height = image.height;
    
    // Method 1: Analyze text line heights
    final lineHeight = _analyzeLineHeights(image);
    double fontSizeFromLines = lineHeight * 0.75; // Typical font size is ~75% of line height
    
    // Method 2: Analyze character dimensions
    final charDimensions = _analyzeCharacterDimensions(image);
    double fontSizeFromChars = charDimensions;
    
    // Method 3: Use image resolution as baseline
    final estimatedDPI = _estimateDPI(image);
    double fontSizeFromDPI = _getFontSizeFromDPI(estimatedDPI, width, height);
    
    // Combine methods with weights
    double combinedSize = (fontSizeFromLines * 0.4) + 
                         (fontSizeFromChars * 0.4) + 
                         (fontSizeFromDPI * 0.2);
    
    // Clamp to reasonable range
    combinedSize = math.max(8.0, math.min(24.0, combinedSize));
    
    print('Font size analysis - Lines: $fontSizeFromLines, Chars: $fontSizeFromChars, DPI: $fontSizeFromDPI, Combined: $combinedSize');
    
    return double.parse(combinedSize.toStringAsFixed(1));
  }

  double _analyzeLineHeights(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    List<int> lineHeights = [];
    bool inTextRegion = false;
    int currentLineStart = 0;
    
    // Scan horizontally to find text lines
    for (int y = 0; y < height; y++) {
      int darkPixels = 0;
      
      // Count dark pixels in this row (potential text)
      for (int x = width ~/ 4; x < (width * 3) ~/ 4; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance < 180) darkPixels++;
      }
      
      double darkRatio = darkPixels / (width / 2);
      
      if (darkRatio > 0.05 && !inTextRegion) {
        // Start of text line
        inTextRegion = true;
        currentLineStart = y;
      } else if (darkRatio < 0.02 && inTextRegion) {
        // End of text line
        inTextRegion = false;
        int lineHeight = y - currentLineStart;
        if (lineHeight > 5 && lineHeight < 200) { // Reasonable line height
          lineHeights.add(lineHeight);
        }
      }
    }
    
    if (lineHeights.isEmpty) return 16.0;
    
    // Calculate average line height
    double avgLineHeight = lineHeights.reduce((a, b) => a + b) / lineHeights.length;
    
    // Convert pixels to points (assuming 96 DPI as baseline)
    return (avgLineHeight * 72) / 96;
  }

  double _analyzeCharacterDimensions(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    List<int> charWidths = [];
    
    // Analyze vertical segments to estimate character widths
    for (int x = width ~/ 4; x < (width * 3) ~/ 4; x += 2) {
      int darkPixels = 0;
      for (int y = height ~/ 4; y < (height * 3) ~/ 4; y++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance < 180) darkPixels++;
      }
      
      if (darkPixels > height ~/ 20) { // Potential character column
        // Look for character boundaries
        int charStart = x;
        while (x < (width * 3) ~/ 4) {
          darkPixels = 0;
          for (int y = height ~/ 4; y < (height * 3) ~/ 4; y++) {
            final pixel = image.getPixel(x, y);
            final luminance = img.getLuminance(pixel);
            if (luminance < 180) darkPixels++;
          }
          
          if (darkPixels < height ~/ 40) {
            int charWidth = x - charStart;
            if (charWidth > 3 && charWidth < 50) {
              charWidths.add(charWidth);
            }
            break;
          }
          x++;
        }
      }
    }
    
    if (charWidths.isEmpty) return 12.0;
    
    double avgCharWidth = charWidths.reduce((a, b) => a + b) / charWidths.length;
    
    // Convert to font size (characters are typically 0.6x their font size in width)
    return ((avgCharWidth * 72) / 96) / 0.6;
  }

  double _estimateDPI(img.Image image) {
    // Estimate DPI based on image dimensions and typical document sizes
    final width = image.width;
    final height = image.height;
    final aspectRatio = width > height ? height / width : width / height;
    
    // For A4 documents, estimate DPI
    if (_isWithinTolerance(aspectRatio, 0.707, 0.05)) {
      // A4 is 8.27 x 11.69 inches
      final longerSide = math.max(width, height);
      return longerSide / 11.69; // DPI estimate
    }
    
    // For Letter documents
    if (_isWithinTolerance(aspectRatio, 0.773, 0.05)) {
      // Letter is 8.5 x 11 inches
      final longerSide = math.max(width, height);
      return longerSide / 11.0;
    }
    
    // Default assumption
    return 150.0;
  }

  double _getFontSizeFromDPI(double dpi, int width, int height) {
    // Typical document with 12pt font at 150 DPI
    if (dpi > 200) return 14.0;
    if (dpi > 150) return 12.0;
    if (dpi > 100) return 11.0;
    if (dpi > 72) return 10.0;
    return 9.0;
  }

  // COMPLETELY REWRITTEN MARGIN DETECTION
  Map<String, double> _estimateMargins(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    print('Starting margin analysis for ${width}x${height} image');
    
    // Create a histogram-based approach for better content detection
    final contentMap = _createContentMap(image);
    
    // Find margins using the content map
    double topMargin = _findTopMarginFromContentMap(contentMap, width, height);
    double bottomMargin = _findBottomMarginFromContentMap(contentMap, width, height);
    double leftMargin = _findLeftMarginFromContentMap(contentMap, width, height);
    double rightMargin = _findRightMarginFromContentMap(contentMap, width, height);
    
    // Convert pixel measurements to inches using estimated DPI
    final estimatedDPI = _estimateDPI(image);
    
    print('Margins in pixels - T:$topMargin, B:$bottomMargin, L:$leftMargin, R:$rightMargin');
    print('Estimated DPI: $estimatedDPI');
    
    // Ensure minimum reasonable margins
    final topInches = math.max(0.1, topMargin / estimatedDPI);
    final bottomInches = math.max(0.1, bottomMargin / estimatedDPI);
    final leftInches = math.max(0.1, leftMargin / estimatedDPI);
    final rightInches = math.max(0.1, rightMargin / estimatedDPI);
    
    return {
      'top': double.parse(topInches.toStringAsFixed(2)),
      'bottom': double.parse(bottomInches.toStringAsFixed(2)),
      'left': double.parse(leftInches.toStringAsFixed(2)),
      'right': double.parse(rightInches.toStringAsFixed(2)),
    };
  }

  // Create a simplified content map for faster processing
  List<List<bool>> _createContentMap(img.Image image) {
    final width = image.width;
    final height = image.height;
    final samplingRate = math.max(1, (width * height) ~/ 100000); // Adaptive sampling
    
    List<List<bool>> contentMap = List.generate(
      (height / samplingRate).ceil(),
      (i) => List.filled((width / samplingRate).ceil(), false),
    );
    
    print('Creating content map with sampling rate: $samplingRate');
    
    for (int y = 0; y < height; y += samplingRate) {
      for (int x = 0; x < width; x += samplingRate) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        // More aggressive threshold - anything not near white is content
        bool hasContent = luminance < 240; // Changed from 200 to 240
        
        contentMap[y ~/ samplingRate][x ~/ samplingRate] = hasContent;
      }
    }
    
    return contentMap;
  }

  double _findTopMarginFromContentMap(List<List<bool>> contentMap, int originalWidth, int originalHeight) {
    final mapHeight = contentMap.length;
    final mapWidth = contentMap[0].length;
    final samplingRate = originalHeight / mapHeight;
    
    // Look for the first row with significant content
    for (int y = 0; y < mapHeight ~/ 2; y++) {
      int contentPixels = 0;
      
      // Check middle 60% of the width to avoid edge noise
      int startX = (mapWidth * 0.2).round();
      int endX = (mapWidth * 0.8).round();
      
      for (int x = startX; x < endX; x++) {
        if (contentMap[y][x]) contentPixels++;
      }
      
      double contentRatio = contentPixels / (endX - startX);
      print('Top margin check at row $y: content ratio = $contentRatio');
      
      // If we find a row with at least 5% content density
      if (contentRatio > 0.05) {
        // Look ahead to confirm this is real content, not noise
        bool confirmedContent = false;
        for (int checkY = y; checkY < math.min(y + 5, mapHeight); checkY++) {
          int checkContentPixels = 0;
          for (int x = startX; x < endX; x++) {
            if (contentMap[checkY][x]) checkContentPixels++;
          }
          if (checkContentPixels / (endX - startX) > 0.03) {
            confirmedContent = true;
            break;
          }
        }
        
        if (confirmedContent) {
          double margin = y * samplingRate;
          print('Found top margin: $margin pixels');
          return margin;
        }
      }
    }
    
    // Default to 5% of image height
    double defaultMargin = originalHeight * 0.05;
    print('Using default top margin: $defaultMargin pixels');
    return defaultMargin;
  }

  double _findBottomMarginFromContentMap(List<List<bool>> contentMap, int originalWidth, int originalHeight) {
    final mapHeight = contentMap.length;
    final mapWidth = contentMap[0].length;
    final samplingRate = originalHeight / mapHeight;
    
    // Search from bottom up
    for (int y = mapHeight - 1; y > mapHeight ~/ 2; y--) {
      int contentPixels = 0;
      
      int startX = (mapWidth * 0.2).round();
      int endX = (mapWidth * 0.8).round();
      
      for (int x = startX; x < endX; x++) {
        if (contentMap[y][x]) contentPixels++;
      }
      
      double contentRatio = contentPixels / (endX - startX);
      print('Bottom margin check at row $y: content ratio = $contentRatio');
      
      if (contentRatio > 0.05) {
        // Confirm with look-back
        bool confirmedContent = false;
        for (int checkY = y; checkY > math.max(y - 5, 0); checkY--) {
          int checkContentPixels = 0;
          for (int x = startX; x < endX; x++) {
            if (contentMap[checkY][x]) checkContentPixels++;
          }
          if (checkContentPixels / (endX - startX) > 0.03) {
            confirmedContent = true;
            break;
          }
        }
        
        if (confirmedContent) {
          double margin = (mapHeight - 1 - y) * samplingRate;
          print('Found bottom margin: $margin pixels');
          return margin;
        }
      }
    }
    
    double defaultMargin = originalHeight * 0.05;
    print('Using default bottom margin: $defaultMargin pixels');
    return defaultMargin;
  }

  double _findLeftMarginFromContentMap(List<List<bool>> contentMap, int originalWidth, int originalHeight) {
    final mapHeight = contentMap.length;
    final mapWidth = contentMap[0].length;
    final samplingRate = originalWidth / mapWidth;
    
    // Search from left
    for (int x = 0; x < mapWidth ~/ 2; x++) {
      int contentPixels = 0;
      
      int startY = (mapHeight * 0.2).round();
      int endY = (mapHeight * 0.8).round();
      
      for (int y = startY; y < endY; y++) {
        if (contentMap[y][x]) contentPixels++;
      }
      
      double contentRatio = contentPixels / (endY - startY);
      print('Left margin check at col $x: content ratio = $contentRatio');
      
      if (contentRatio > 0.05) {
        // Confirm with look-ahead
        bool confirmedContent = false;
        for (int checkX = x; checkX < math.min(x + 5, mapWidth); checkX++) {
          int checkContentPixels = 0;
          for (int y = startY; y < endY; y++) {
            if (contentMap[y][checkX]) checkContentPixels++;
          }
          if (checkContentPixels / (endY - startY) > 0.03) {
            confirmedContent = true;
            break;
          }
        }
        
        if (confirmedContent) {
          double margin = x * samplingRate;
          print('Found left margin: $margin pixels');
          return margin;
        }
      }
    }
    
    double defaultMargin = originalWidth * 0.05;
    print('Using default left margin: $defaultMargin pixels');
    return defaultMargin;
  }

  double _findRightMarginFromContentMap(List<List<bool>> contentMap, int originalWidth, int originalHeight) {
    final mapHeight = contentMap.length;
    final mapWidth = contentMap[0].length;
    final samplingRate = originalWidth / mapWidth;
    
    // Search from right
    for (int x = mapWidth - 1; x > mapWidth ~/ 2; x--) {
      int contentPixels = 0;
      
      int startY = (mapHeight * 0.2).round();
      int endY = (mapHeight * 0.8).round();
      
      for (int y = startY; y < endY; y++) {
        if (contentMap[y][x]) contentPixels++;
      }
      
      double contentRatio = contentPixels / (endY - startY);
      print('Right margin check at col $x: content ratio = $contentRatio');
      
      if (contentRatio > 0.05) {
        // Confirm with look-back
        bool confirmedContent = false;
        for (int checkX = x; checkX > math.max(x - 5, 0); checkX--) {
          int checkContentPixels = 0;
          for (int y = startY; y < endY; y++) {
            if (contentMap[y][checkX]) checkContentPixels++;
          }
          if (checkContentPixels / (endY - startY) > 0.03) {
            confirmedContent = true;
            break;
          }
        }
        
        if (confirmedContent) {
          double margin = (mapWidth - 1 - x) * samplingRate;
          print('Found right margin: $margin pixels');
          return margin;
        }
      }
    }
    
    double defaultMargin = originalWidth * 0.05;
    print('Using default right margin: $defaultMargin pixels');
    return defaultMargin;
  }
}