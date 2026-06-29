/// Domain entity representing a generated QR code.
class QrGenerationResult {
  const QrGenerationResult({
    required this.qrImageUrl,
    required this.token,
    required this.deepLink,
    required this.fallbackUrl,
  });

  final String qrImageUrl;
  final String token;
  final String deepLink;
  final String fallbackUrl;
}
