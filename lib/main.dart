import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_memories/home_widget.dart';
import 'package:widget_memories/image_bloc.dart';
import 'package:workmanager/workmanager.dart';

import 'drive.dart';

const int updateTime = 0; // Midnight

const String androidDailyTask = 'updateDaily';
const String iOSDailyTask = "com.example.widgetMemories.updateDaily";

late String imgFilename;

const String iOSGroupId = 'group.widget_memories_group';
const String iOSWidgetName = 'PhotoWidget';
const String androidWidgetName = 'PhotoWidget';

int dateStrCompareToNow(String date1Str) {
  final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return date1Str.compareTo(nowStr);
}

// Mandatory if the App is obfuscated or using Flutter 3.1+
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == androidDailyTask || task == iOSDailyTask) {
      final storage = SharedPreferencesAsync();
      final apiURL = await storage.getString('apiURL');
      final blacklist = await storage.getStringList('blacklist');
      final lastUpdate = await storage.getString('lastUpdate');
      if (apiURL == null ||
          blacklist == null ||
          lastUpdate == null ||
          dateStrCompareToNow(lastUpdate) >= 0) {
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
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.isAndroid
      ? (await getApplicationDocumentsDirectory()).path
      : await PathProviderFoundation()
          .getContainerPath(appGroupIdentifier: iOSGroupId);
  imgFilename = "${directory}/todaysPhoto.png";

  await HomeWidget.setAppGroupId(iOSGroupId);

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
  bool _ready = false;

  bool _areButtonsDisabled = false;
  bool _updateDisabled = true;
  bool _launchTaskDisabled = true;

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

  Future<void> initWorkManager() async {
    if (Platform.isIOS) {
      final status = await Permission.backgroundRefresh.status;
      if (status != PermissionStatus.granted) {
        _displayMessage(
            'Background app refresh is disabled, please enable in '
            'App settings. Status: ${status.name}',
            isError: true);
        return;
      }
    }

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    setState(() {
      _launchTaskDisabled = false;
    });
  }

  Future<void> launchBackgroundTask() async {
    final dailyKey = Platform.isAndroid ? androidDailyTask : iOSDailyTask;

    await Workmanager().cancelAll();

    await Workmanager().registerPeriodicTask(
      dailyKey,
      dailyKey,
      frequency: const Duration(
          hours: 12), // Android: Every 12 hours to be sure, iOS: Every 1 hour
      initialDelay: Duration(seconds: _calculateInitialDelay()),
    );

    _displayMessage('Background task scheduled for next night', isError: false);
  }

  int _calculateInitialDelay() {
    final now = DateTime.now();
    var targetTime = DateTime(now.year, now.month, now.day, updateTime, 0, 0);
    if (now.isAfter(targetTime)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }
    return targetTime.difference(now).inSeconds;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    initWorkManager();
    initLayout();
    _controller.addListener(_checkNonEmpty);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  Future<void> initLayout() async {
    final apiURL = await storage.getString('apiURL');
    final file = File(imgFilename);

    if (file.existsSync()) {
      if (apiURL == null) {
        _displayMessage('Inconsistent state. You should clear the widget.',
            isError: true);
        setState(() {
          _launchTaskDisabled = true;
        });
      }
      setState(() {
        _apiURL = apiURL;
        _ready = true;
        _setImageFile(file);
      });
    } else if (apiURL != null) {
      _displayMessage('Inconsistent state. You should clear the widget.',
          isError: true);
      setState(() {
        _launchTaskDisabled = true;
        _apiURL = apiURL;
        _ready = true;
      });
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
    if (!_ready) {
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

  void _displayMessage(String message, {bool isError = false}) {
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
    storage.clear(allowList: {'apiURL', 'blacklist', 'lastUpdate'});
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
        _ready = true;
      });
    } catch (e) {
      _displayMessage(e.toString(), isError: true);
    }
  }

  Future<void> _clearWidget() async {
    try {
      await setHomeWidget(null);

      _successfulUpdate(null, 'Widget successfully cleared');

      _clearStorage();
      await Workmanager().cancelAll();
      setState(() {
        _apiURL = null;
        _updateDisabled = _controller.text.isEmpty;
        _ready = false;
      });
    } catch (e) {
      _displayMessage(e.toString(), isError: true);
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
                    const Spacer(flex: 2),
                    Flexible(
                      flex: 3,
                      child: SizedBox.expand(
                        child: Column(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LoadingButton(
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
                                        horizontal: 16.0,
                                      ),
                                    ),
                                    areButtonsDisabled: _areButtonsDisabled,
                                    setDisableButtons: _setDisableButtons,
                                  ),
                                  LoadingButton(
                                    onPressed: _launchTaskDisabled || !_ready
                                        ? null
                                        : () async {
                                            await launchBackgroundTask();
                                          },
                                    text: 'To background task',
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                        horizontal: 16.0,
                                      ),
                                    ),
                                    areButtonsDisabled: _areButtonsDisabled,
                                    setDisableButtons: _setDisableButtons,
                                  ),
                                ],
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
                              onPressed: !_ready
                                  ? null
                                  : () async {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
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
                    const Spacer(flex: 2),
                    Column(
                      children: [
                        Text(
                          'Current Picture:',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
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

    final Text textWidget = Text(
      widget.text,
      textAlign: TextAlign.center,
    );
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
          ? ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: textWidth,
                minHeight: textHeight,
              ),
              child: Center(
                child: LoadingAnimationWidget.waveDots(
                    color: buttonColor,
                    size: widget.animationSize ?? min(textWidth, textHeight)),
              ),
            )
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
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
                      .withValues(alpha: 0.25)),
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(child: Text('No image selected')),
        );
      }
    });
  }
}
