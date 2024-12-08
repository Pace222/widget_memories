import 'dart:io';

import 'package:flutter/material.dart';

import 'drive.dart';

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

  void _checkApiUrl(apiUrl) async {
    String? error = await checkApiUrl(apiUrl);
    
    setState(() {
      _validationError = error;
    });

    if (error == null) {
      // Successfully validated
  
      // Update the state
      widget.onApiURLChanged(apiUrl);
      // Clear text field
      _controller.clear();
      // Remove keyboard
      FocusManager.instance.primaryFocus?.unfocus();
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
              onPressed: () {
                _checkApiUrl(_controller.text);
              },
              child: const Text('Check'),
            ),
          ],
        ),  
      ],
    );
  }
}