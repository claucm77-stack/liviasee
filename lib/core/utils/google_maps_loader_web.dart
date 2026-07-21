// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

Future<void> loadGoogleMapsApi() async {
  if (_apiKey.trim().isEmpty ||
      html.document.querySelector('script[data-google-maps-api]') != null) {
    return;
  }

  final script = html.ScriptElement()
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(_apiKey)}&loading=async'
    ..async = true
    ..defer = true
    ..dataset['googleMapsApi'] = 'true';

  html.document.head?.append(script);
  await script.onLoad.first;
}
