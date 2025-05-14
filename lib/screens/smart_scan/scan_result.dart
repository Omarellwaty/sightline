class ScanResult {
  final String text;
  final double confidence;
  final String rawText;

  ScanResult({
    required this.text,
    this.confidence = 0.0,
    required this.rawText,
  });
}
