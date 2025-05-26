class DocumentAnalysis {
  final int? id;
  final String imagePath;
  final String paperSize;
  final double fontSize;
  final double topMargin;
  final double bottomMargin;
  final double leftMargin;
  final double rightMargin;
  final DateTime createdAt;

  DocumentAnalysis({
    this.id,
    required this.imagePath,
    required this.paperSize,
    required this.fontSize,
    required this.topMargin,
    required this.bottomMargin,
    required this.leftMargin,
    required this.rightMargin,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'paperSize': paperSize,
      'fontSize': fontSize,
      'topMargin': topMargin,
      'bottomMargin': bottomMargin,
      'leftMargin': leftMargin,
      'rightMargin': rightMargin,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DocumentAnalysis.fromMap(Map<String, dynamic> map) {
    return DocumentAnalysis(
      id: map['id'],
      imagePath: map['imagePath'],
      paperSize: map['paperSize'],
      fontSize: map['fontSize'].toDouble(),
      topMargin: map['topMargin'].toDouble(),
      bottomMargin: map['bottomMargin'].toDouble(),
      leftMargin: map['leftMargin'].toDouble(),
      rightMargin: map['rightMargin'].toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}