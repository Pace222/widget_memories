import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Regular expression to validate Google Drive folder URLs
final RegExp driveFolderRegex = RegExp(
  r'^https:\/\/drive\.google\.com\/drive\/(?:u\/\d+\/)?folders\/([a-zA-Z0-9_-]+)(?:\?usp=sharing)?$',
);
const String driveApiKey = 'AIzaSyDUSefAwtItioFWlbIX0jGDUybWVmQosX0';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sharing memories',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Sharing memories'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _apiURL;
  File? _imageFile;

  void setApiURL(String apiURL) {
    setState(() {
      _apiURL = apiURL;
    });
  }

  void _updateWidget() {
    // Update the home widget
  }

  void _clearWidget() {
    // Clear the home widget
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[

            const Spacer(flex:1),

            _URLPicker(apiURL: _apiURL, onApiURLChanged: setApiURL),

            const Spacer(flex:2),

            ElevatedButton(
              onPressed: _apiURL == null ? null : () {
                _updateWidget();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 100),
              ),
              child: const Text('Update widget'),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () {
                _clearWidget();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 50),
                foregroundColor: Theme.of(context).colorScheme.onError,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Clear widget'),
            ),
                        

            const Spacer(flex:2),

            Column(
              children: <Widget>[
                Text(
                  'Current Picture:',
                    style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (_imageFile != null)
                  Image.file(
                    _imageFile!,
                    width: 200,
                    height: 200,
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    width: 200,
                    height: 200,
                    child: const Center(child: Text('No image selected')),
                  ), // Empty space if the image is null
              ],
            ),
            
            const Spacer(flex:1),
          ],
        ),
      ),
    );
  }
}

class _URLPicker extends StatefulWidget {
  const _URLPicker({super.key, required this.apiURL, required this.onApiURLChanged});

  final String? apiURL;
  final Function(String) onApiURLChanged;

  @override
  State<_URLPicker> createState() => _URLPickerState();
}

class _URLPickerState extends State<_URLPicker> {
  final TextEditingController _controller = TextEditingController();
  String? _validationError;

  Future<String?> _checkApiUrl(apiUrl) async {
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
        // Successfully validated; update the state
        widget.onApiURLChanged(apiUrl);
        return null;
      } else {
        return 'The folder is not public or accessible';
      }
    } catch (e) {
      // Handle any unexpected errors
      return 'Error: ${e.toString()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Current URL: ',
            style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.bold),
            children: <TextSpan>[
              TextSpan(
                text: widget.apiURL ?? 'Not set',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  border: const UnderlineInputBorder(),
                  labelText: 'Google Drive URL',
                  hintText: 'https://drive.google.com/drive/folders/[a-zA-Z0-9_-]+',
                  hintStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25)),
                  errorText: _validationError,
                ),
                style: const TextStyle(fontSize: 12)
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                String? error = await _checkApiUrl(_controller.text);
              
                setState(() {
                  _validationError = error;
                });

                if (error == null) {
                  _controller.clear();
                  // Remove keyboard
                  FocusManager.instance.primaryFocus?.unfocus();
                }
              },
              child: const Text('Check'),
            ),
          ],
        ),  
      ],
    );
  }
}