import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_memories/image_bloc.dart';

import 'consensus.dart';
import 'drive.dart';
import 'edit_image.dart';

const String filename = 'todaysPhoto.png';

const String iOSWidgetName = 'PhotoWidget';
const String androidWidgetName = 'PhotoWidget';

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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ImageBloc(),
      child: const HomePageContent(title: 'Sharing memories'),
    );
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key, required this.title});

  final String title;

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  SharedPreferences? storage;
  String? _apiURL;
  bool _areButtonsDisabled = false;

  @override
  void initState() {
    super.initState();
    initStorageAndApiURL();
    initImage();
  }

  void initStorageAndApiURL() async {
    final prefs = await SharedPreferences.getInstance();
    final apiURL = prefs.getString('apiURL');
    setState(() {
      storage = prefs;
    });
    if (apiURL != null) {
      setState(() {
        _setApiURL(apiURL);
      });
    }
  }

  void initImage() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File("${directory.path}/$filename");
    if (file.existsSync()) {
      _setImageFile(file);
    }
  }

  void _setApiURL(String apiURL) {
    storage!.setString('apiURL', apiURL);
    setState(() {
      _apiURL = apiURL;
    });
  }

  void _setImageFile(File? file) {
    if (file != null) {
      context.read<ImageBloc>().add(LoadImage(file));
    } else {
      context.read<ImageBloc>().add(ClearImage());
    }
  }

  void _setDisableButtons(bool disabled) {
    setState(() {
      _areButtonsDisabled = disabled;
    });
  }

  void _displayMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
      duration: const Duration(seconds: 4),
    ));
  }

  void _clearStorage() {
    storage!.clear();
  }

  Future<bool> _saveHomeWidget(File? file) async {
    try {
      await HomeWidget.saveWidgetData('filename', file?.path);

      var ok = await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        androidName: androidWidgetName,
      );

      if (ok != null && ok) {
        _displayMessage('Widget updated successfully', isError: false);

        _setImageFile(file);

        return true;
      } else {
        _displayMessage('Failed to update the widget');
      }
    } catch (e) {
      _displayMessage(e.toString());
    }

    return false;
  }

  Future<void> _updateWidget() async {
    try {
      final allPhotos = await getAllPhotos(_apiURL as String);

      // "Randomly" select the picture
      var blacklist = storage!.getKeys().fold<Map<String, String>>({}, (acc, key) {
        acc[key] = storage!.getString(key)!;
        return acc;
      });
      final (todaysPhoto, oldestPhotoId) = await consensualRandom(allPhotos, blacklist);
      // Remove oldest photo from storage
      if (oldestPhotoId != null) {
        storage!.remove(oldestPhotoId);
      }
      final fileId = todaysPhoto['id'] as String;

      final imageBytes = await downloadPhoto(fileId);

      // Save the file edited with the photo's date
      final directory = await getApplicationDocumentsDirectory();
      final file = await saveImageWithText(imageBytes, DateFormat('dd/MM/yyyy').format(DateTime.parse(todaysPhoto['createdTime']!)), "${directory.path}/$filename");

      await _saveHomeWidget(file);
  
    } catch (e) {
      _displayMessage(e.toString());
    }
  }

  Future<void> _clearWidget() async {
    // Clear the home widget
    var ok = await _saveHomeWidget(null);

    if (ok) {
      setState(() {
        _apiURL = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted || storage == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Use MediaQuery to get the available height minus the keyboard
    final availableHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).viewInsets.bottom; // Accounts for the keyboard

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[

            const Spacer(flex:10),

            _URLPicker(apiURL: _apiURL, areButtonsDisabled: _areButtonsDisabled, setApiURL: _setApiURL, setDisableButtons: _setDisableButtons),

            const Spacer(flex:20),

            LoadingButton(
              onPressed: _apiURL == null ? null : () async {
                _clearStorage();
                await _updateWidget();
              },
              text: 'Update widget',
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, availableHeight * 0.12),
              ),
              areButtonsDisabled: _areButtonsDisabled,
              setDisableButtons: _setDisableButtons,
            ),

            const Spacer(flex:5),

            LoadingButton(
              onPressed: () async {
                _clearStorage();
                await _clearWidget();
              },
              text: 'Clear widget',
              style: ElevatedButton.styleFrom(
                minimumSize: Size(100, availableHeight * 0.06),
                foregroundColor: Theme.of(context).colorScheme.onError,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              animationColor: Theme.of(context).colorScheme.onError,
              areButtonsDisabled: _areButtonsDisabled,
              setDisableButtons: _setDisableButtons,
            ),
                        

            const Spacer(flex:20),

            const ImageDisplay(),

            const Spacer(flex:10),
          ],
        ),
      ),
    );
  }
}


class LoadingButton extends StatefulWidget {
  const LoadingButton({super.key, required this.onPressed, required this.text, this.style, this.animationColor, this.animationSize, required bool areButtonsDisabled, required void Function(bool) setDisableButtons}) : _areButtonsDisabled = areButtonsDisabled, _setDisableButtons = setDisableButtons;

  final Future<void> Function()? onPressed;
  final String text;
  final ButtonStyle? style;

  final Color? animationColor;
  final double? animationSize;

  final bool _areButtonsDisabled;
  final Function(bool) _setDisableButtons;

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  var _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = widget.animationColor ?? Theme.of(context).colorScheme.primary;

    final Text textWidget = Text(widget.text);
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: DefaultTextStyle.of(context).style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    final double textWidth = textPainter.size.width;
    final double textHeight = textPainter.size.height;

    return ElevatedButton(
      onPressed: _isLoading || widget._areButtonsDisabled || widget.onPressed == null ? null : () async {
        setState(() {
          _isLoading = true;
        });
        widget._setDisableButtons(true);

        try {
          await widget.onPressed!();
        } finally {
          widget._setDisableButtons(false);
          setState(() {
            _isLoading = false;
          });
        }
      },
      style: widget.style,
      child: _isLoading
        ? LoadingAnimationWidget.waveDots(color: buttonColor, size: widget.animationSize ?? min(textWidth, textHeight))
        : textWidget,
    );
  }
}


class _URLPicker extends StatefulWidget {
  const _URLPicker({super.key, required String? apiURL, required bool areButtonsDisabled, required void Function(String) setApiURL, required void Function(bool) setDisableButtons}) : _setDisableButtons = setDisableButtons, _setApiURL = setApiURL, _apiURL = apiURL, _areButtonsDisabled = areButtonsDisabled;

  final String? _apiURL;
  final bool _areButtonsDisabled;
  final Function(String) _setApiURL;
  final Function(bool) _setDisableButtons;

  @override
  State<_URLPicker> createState() => _URLPickerState();
}

class _URLPickerState extends State<_URLPicker> {
  final TextEditingController _controller = TextEditingController();
  String? _validationError;

  Future<void> _checkApiUrl(apiUrl) async {
    String? error;
    try {
      error = await checkApiUrl(apiUrl);
    } catch (e) {
      error = e.toString();
    }
    
    setState(() {
      _validationError = error;
    });

    if (error == null) {
      // Successfully validated
  
      widget._setApiURL(apiUrl);
      _controller.clear();
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
                text: widget._apiURL ?? 'Not set',
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
            LoadingButton(
              onPressed: () async {
                await _checkApiUrl(_controller.text);
              },
              text: 'Check',
              areButtonsDisabled: widget._areButtonsDisabled,
              setDisableButtons: widget._setDisableButtons,
            ),
          ],
        ),  
      ],
    );
  }
}

class ImageDisplay extends StatelessWidget {
  const ImageDisplay({super.key});


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        if (state is ImageLoaded) {
          return Column(
            children: [
              Text(
                'Current Picture:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Image.memory(
                state.imageFile.readAsBytesSync(),
                width: 200,
                height: 200,
              )
            ],
          );
        } else {
          return Column(
            children: [
              Text(
                'Current Picture:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                width: 200,
                height: 200,
                child: const Center(child: Text('No image selected')),
              ),
            ],
          );
        }
      }
    );
  }
}
