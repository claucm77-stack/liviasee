import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/microbusiness.dart';

class ParsedMapsLocation {
  const ParsedMapsLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

ParsedMapsLocation? parseGoogleMapsLocation(String rawUrl) {
  final text = rawUrl.trim();
  if (text.isEmpty) return null;

  final matches =
      RegExp(r'(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)').allMatches(text);
  for (final match in matches) {
    final latitude = double.tryParse(match.group(1) ?? '');
    final longitude = double.tryParse(match.group(2) ?? '');
    if (latitude == null || longitude == null) continue;
    if (latitude < -90 || latitude > 90) continue;
    if (longitude < -180 || longitude > 180) continue;
    return ParsedMapsLocation(latitude: latitude, longitude: longitude);
  }

  return null;
}

Uri mapsSearchUri(Microbusiness business) {
  final mapsUrl = business.mapsUrl.trim();
  if (mapsUrl.isNotEmpty) {
    final uri = Uri.tryParse(mapsUrl);
    if (uri != null && uri.hasScheme) return uri;
  }

  return Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${business.latitud},${business.longitud}',
  );
}

Uri mapsDirectionsUri(Microbusiness business) {
  final mapsUrl = business.mapsUrl.trim();
  if (mapsUrl.isNotEmpty) {
    final uri = Uri.tryParse(mapsUrl);
    if (uri != null && uri.hasScheme) return uri;
  }

  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${business.latitud},${business.longitud}',
  );
}

Future<void> openMapsUri(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
