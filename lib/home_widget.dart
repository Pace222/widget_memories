import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_memories/consensus.dart';
import 'package:widget_memories/drive.dart';
import 'package:widget_memories/edit_image.dart';
import 'package:widget_memories/main.dart';

Future<void> setHomeWidget(File? file) async {
  await HomeWidget.saveWidgetData('filename', file?.path);

  var ok = await HomeWidget.updateWidget(
    iOSName: iOSWidgetName,
    androidName: androidWidgetName,
  );

  if (ok == null || !ok) {
    throw Exception('Failed to update the home widget');
  }
}

Future<File> fetchFindDownload(String apiURL, List<String> blacklist) async {
  final allPhotos = await getAllPhotos(apiURL);

  // "Randomly" select the picture
  final todaysPhoto = await consensualRandom(allPhotos, blacklist);

  // Download the photo
  final imageBytes = await downloadPhoto(todaysPhoto['id']!);

  // Save the file edited with the photo's date
  final file = File(imgFilename);
  final png = await imageWithText(
    imageBytes,
    DateFormat('dd/MM/yyyy')
        .format(DateTime.parse(todaysPhoto['createdTime']!)),
  );
  await file.writeAsBytes(png);

  return file;
}

Future<File> updateHomeWidget(SharedPreferencesAsync storage, String apiURL,
    List<String> blacklist) async {
  File file = await fetchFindDownload(apiURL, blacklist);

  await setHomeWidget(file);

  // Save the new API URL
  storage.setString('apiURL', apiURL);

  // Save the new blacklist
  storage.setStringList('blacklist', blacklist);

  // Update last update time
  storage.setString('lastUpdate', DateFormat('yyyy-MM-dd').format(DateTime.now()));

  return file;
}
