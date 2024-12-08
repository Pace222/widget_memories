import 'package:http/http.dart' as http;

// Regular expression to validate Google Drive folder URLs
final RegExp driveFolderRegex = RegExp(
  r'^https:\/\/drive\.google\.com\/drive\/(?:u\/\d+\/)?folders\/([a-zA-Z0-9_-]+)(?:\?usp=sharing)?$',
);
const String driveApiKey = '***REMOVED***';


Future<String?> checkApiUrl(apiUrl) async {
  if (!driveFolderRegex.hasMatch(apiUrl)) {
    // Invalid URL format
    return 'Invalid Google Drive folder URL';
  }

  // Extract folder ID from the URL
  final match = driveFolderRegex.firstMatch(apiUrl);
  final folderId = match?.group(1);

  if (folderId == null) {
    return 'Unable to extract folder ID from the URL';
  }

  try {
    // Validate the folder is public by making a request to Google Drive API
    final url = Uri.parse('https://www.googleapis.com/drive/v3/files?q="$folderId"+in+parents&key=$driveApiKey');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return null;
    } else {
      return 'The folder is not public or accessible';
    }
  } catch (e) {
    // Handle any unexpected errors
    return 'Error: ${e.toString()}';
  }
}