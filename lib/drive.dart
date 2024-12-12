import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

// Regular expression to validate Google Drive folder URLs
final RegExp driveFolderRegex = RegExp(
  r'^https:\/\/drive\.google\.com\/drive\/(?:u\/\d+\/)?folders\/([a-zA-Z0-9_-]+)(?:\?usp=sharing)?$',
);
const String driveApiKey = 'AIzaSyDUSefAwtItioFWlbIX0jGDUybWVmQosX0';

Future<http.Response> fetch(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Failed to fetch data');
  }
  return response;
}

String getDriveFolderId(String apiUrl) {
  final match = driveFolderRegex.firstMatch(apiUrl);
  final folderId = match?.group(1);
  if (folderId == null) {
    throw Exception('Unable to extract folder ID from the URL');
  }
  return folderId;
}

Future<void> checkApiUrl(String apiUrl) async {
  if (!driveFolderRegex.hasMatch(apiUrl)) {
    // Invalid URL format
    throw 'Invalid Google Drive folder URL';
  }

  final String folderId;
  // Extract folder ID from the URL
  folderId = getDriveFolderId(apiUrl);

  try {
    // Validate the folder is public by making a request to Google Drive API
    await fetch(
        'https://www.googleapis.com/drive/v3/files?q="$folderId"+in+parents&key=$driveApiKey');
  } catch (e) {
    throw 'The folder is not public or accessible';
  }
}

Future<List<Map<String, String>>> getAllPhotos(String apiUrl) async {
  final folderId = getDriveFolderId(apiUrl);

  // Function to recursively list files in a folder
  Future<List<Map<String, String>>> recursiveFetch(String folderId) async {
    final response = await fetch(
        'https://www.googleapis.com/drive/v3/files?q="$folderId"+in+parents&key=$driveApiKey&fields=files(id,createdTime,mimeType)');

    final files = jsonDecode(response.body)['files']
        .map((file) => file as Map<String, dynamic>)
        .toList();
    final List<Future<List<Map<String, String>>>> futures = [];

    for (var file in files) {
      futures.add(() async {
        final mimeType = file['mimeType'] as String;
        if (mimeType == 'application/vnd.google-apps.folder') {
          // Recursively list files in subfolder
          return await recursiveFetch(file['id'] as String);
        } else if (mimeType.startsWith('image/')) {
          return [castMap(file)];
        }
        return <Map<String, String>>[];
      }());
    }

    // Wait for all futures to complete and combine results
    final results = await Future.wait(futures);
    return results.expand((x) => x).toList();
  }

  // Start listing files from the root folder
  final allPhotos = await recursiveFetch(folderId);

  return allPhotos;
}

Map<String, String> castMap(Map<String, dynamic> map) {
  return map.map((key, value) => MapEntry(key, value.toString()));
}

Future<Uint8List> downloadPhoto(String photoId) async {
  final response = await fetch(
      'https://www.googleapis.com/drive/v3/files/$photoId?alt=media&key=$driveApiKey');
  return response.bodyBytes;
}
