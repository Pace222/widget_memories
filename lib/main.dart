import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_widget/home_widget.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_memories/home_widget.dart';
import 'package:widget_memories/image_bloc.dart';

import 'drive.dart';

const int updateTime = 2; // 2 AM

const String backgroundTaskId = 'com.transistorsoft.updateDaily';

late String imgFilename;

const String iOSGroupId = 'group.widget_memories_group';
const String iOSWidgetName = 'PhotoWidget';
const String androidWidgetName = 'PhotoWidget';

Future<bool> doUpdateWidget() async {
  final storage = SharedPreferencesAsync();
  final apiURL = await storage.getString('apiURL');
  final blacklist = await storage.getStringList('blacklist');
  if (apiURL == null || blacklist == null) {
    // Retry next day
    return false;
  }

  try {
    await updateHomeWidget(storage, apiURL, blacklist);
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> configureBackgroundTasks() async {
  await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 60, // 24 hours
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.NONE,
      ), (String taskId) async {
    // This is the fetch-event callback.

    // Use a switch statement to route task-handling.
    switch (taskId) {
      case backgroundTaskId:
        await doUpdateWidget();
        break;
      default:
        break;
    }
    // Finish, providing received taskId.
    BackgroundFetch.finish(taskId);
  }, (String taskId) async {
    // <-- Event timeout callback
    // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
    BackgroundFetch.finish(taskId);
  });
}

int _calculateInitialDelay() {
  final now = DateTime.now();
  final targetTime = DateTime(now.year, now.month, now.day, 8, 0, 0);
  if (now.isAfter(targetTime)) {
    targetTime.add(const Duration(days: 1));
  }
  return targetTime.difference(now).inMilliseconds;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.isAndroid
      ? (await getApplicationDocumentsDirectory()).path
      : await PathProviderFoundation()
          .getContainerPath(appGroupIdentifier: iOSGroupId);
  imgFilename = "${directory}/todaysPhoto.png";
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

class _HomePageContentState extends State<HomePageContent>
    with WidgetsBindingObserver {
  SharedPreferencesAsync storage = SharedPreferencesAsync();

  String? _apiURL;
  final TextEditingController _controller = TextEditingController();
  String? _validationError;

  bool _updateDisabled = true;

  bool _areButtonsDisabled = false;

  @override
  void didChangeAppLifecycleState(ui.AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        initImage();
        break;
      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    HomeWidget.setAppGroupId(iOSGroupId);

    checkInitBackgroundTasks();

    initApiURL();
    initImage();
    _controller.addListener(_checkNonEmpty);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> checkInitBackgroundTasks() async {
    final isTaskScheduled = await storage.getBool('isTaskScheduled') ?? false;
    if (isTaskScheduled) {
      return;
    }

    await configureBackgroundTasks();

    await BackgroundFetch.scheduleTask(TaskConfig(
      taskId: backgroundTaskId,
      delay: _calculateInitialDelay(),
      periodic: true,
    ));

    await storage.setBool('isTaskScheduled', true);
  }

  Future<void> initApiURL() async {
    final apiURL = await storage.getString('apiURL');
    setState(() {
      _apiURL = apiURL;
    });
  }

  Future<void> initImage() async {
    final file = File(imgFilename);
    if (file.existsSync()) {
      _setImageFile(file);
    }
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

  void _checkNonEmpty() {
    if (_apiURL == null) {
      setState(() {
        _updateDisabled = _controller.text.isEmpty;
      });
    }
  }

  Future<bool> _checkApiUrl(String apiURL) async {
    try {
      await checkApiUrl(apiURL);

      // Valid URL
      setState(() {
        _apiURL = apiURL;
        _validationError = null;
      });
      _controller.clear();

      return true;
    } catch (e) {
      setState(() {
        _validationError = e.toString();
      });
      return false;
    }
  }

  void _displayMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary,
      duration: const Duration(seconds: 4),
    ));
  }

  void _clearStorage() {
    storage.clear(allowList: {'apiURL', 'blacklist'});
  }

  void _successfulUpdate(File? file, String message) {
    _displayMessage(message, isError: false);
    _setImageFile(file);
  }

  Future<void> _updateWidget() async {
    try {
      File file = await updateHomeWidget(storage, _apiURL!, []);

      _successfulUpdate(file, 'Widget successfully updated');

      setState(() {
        _updateDisabled = true;
      });
    } catch (e) {
      _displayMessage(e.toString());
    }
  }

  Future<void> _clearWidget() async {
    try {
      await setHomeWidget(null);

      _successfulUpdate(null, 'Widget successfully cleared');

      _clearStorage();
      setState(() {
        _apiURL = null;
        _updateDisabled = _controller.text.isEmpty;
      });
    } catch (e) {
      _displayMessage(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _URLPicker(
                        apiURL: _apiURL,
                        controller: _controller,
                        validationError: _validationError),
                    const SizedBox(height: 4),
                    const Spacer(flex: 1),
                    Flexible(
                      flex: 4,
                      child: SizedBox.expand(
                        child: Column(
                          children: <Widget>[
                            Expanded(
                              child: LoadingButton(
                                onPressed: _updateDisabled
                                    ? null
                                    : () async {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        if (await _checkApiUrl(
                                            _controller.text)) {
                                          await _updateWidget();
                                        }
                                      },
                                text: 'Update widget',
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 64.0,
                                  ),
                                ),
                                areButtonsDisabled: _areButtonsDisabled,
                                setDisableButtons: _setDisableButtons,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Spacer(flex: 1),
                    Flexible(
                      flex: 2,
                      child: SizedBox.expand(
                        child: Column(children: <Widget>[
                          Expanded(
                            child: LoadingButton(
                              onPressed: () async {
                                FocusManager.instance.primaryFocus?.unfocus();
                                await _clearWidget();
                              },
                              text: 'Clear widget',
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 32.0,
                                ),
                                foregroundColor:
                                    Theme.of(context).colorScheme.onError,
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              animationColor:
                                  Theme.of(context).colorScheme.onError,
                              areButtonsDisabled: _areButtonsDisabled,
                              setDisableButtons: _setDisableButtons,
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Spacer(flex: 1),
                    Column(
                      children: [
                        Text(
                          'Current Picture:',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                            height: constraints.maxHeight * 0.45,
                            child: FittedBox(child: const _ImageDisplay())),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class LoadingButton extends StatefulWidget {
  const LoadingButton(
      {super.key,
      required this.onPressed,
      required this.text,
      this.style,
      this.animationColor,
      this.animationSize,
      required bool areButtonsDisabled,
      required void Function(bool) setDisableButtons})
      : _areButtonsDisabled = areButtonsDisabled,
        _setDisableButtons = setDisableButtons;

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
    final Color buttonColor =
        widget.animationColor ?? Theme.of(context).colorScheme.primary;

    final Text textWidget = Text(widget.text);
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
          text: widget.text, style: DefaultTextStyle.of(context).style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    final double textWidth = textPainter.size.width;
    final double textHeight = textPainter.size.height;

    return ElevatedButton(
      onPressed:
          _isLoading || widget._areButtonsDisabled || widget.onPressed == null
              ? null
              : () async {
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
          ? LoadingAnimationWidget.waveDots(
              color: buttonColor,
              size: widget.animationSize ?? min(textWidth, textHeight))
          : textWidget,
    );
  }
}

class _URLPicker extends StatefulWidget {
  const _URLPicker(
      {super.key,
      required String? apiURL,
      required TextEditingController controller,
      required String? validationError})
      : _apiURL = apiURL,
        _controller = controller,
        _validationError = validationError;

  final String? _apiURL;
  final TextEditingController _controller;
  final String? _validationError;

  @override
  State<_URLPicker> createState() => _URLPickerState();
}

class _URLPickerState extends State<_URLPicker> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Current URL: ',
            style: Theme.of(context)
                .textTheme
                .labelMedium!
                .copyWith(fontWeight: FontWeight.bold),
            children: <TextSpan>[
              TextSpan(
                text: widget._apiURL ?? 'Not set',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
            controller: widget._controller,
            decoration: InputDecoration(
              border: const UnderlineInputBorder(),
              labelText: 'Google Drive URL',
              hintText: 'https://drive.google.com/drive/folders/[a-zA-Z0-9_-]+',
              hintStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.25)),
              errorText: widget._validationError,
            ),
            style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ImageDisplay extends StatelessWidget {
  const _ImageDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(builder: (context, state) {
      if (state is ImageLoaded) {
        return Image.memory(
          state.imageFile.readAsBytesSync(),
        );
      } else {
        return Container(
          width: 180,
          height: 320,
          decoration: BoxDecoration(
            border: Border.all(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(child: Text('No image selected')),
        );
      }
    });
  }
}
