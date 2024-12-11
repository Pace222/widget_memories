import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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

Future<File> updateHomeWidget(SharedPreferencesAsync storage) async {
  final allPhotos = await getAllPhotos((await storage.getString('apiURL'))!);

  final blacklist = await storage.getStringList('blacklist') ?? [];
  // "Randomly" select the picture
  final todaysPhoto = await consensualRandom(allPhotos, blacklist);

  // Save the new blacklist
  storage.setStringList('blacklist', blacklist);

  // Download the photo
  final imageBytes = await downloadPhoto(todaysPhoto['id']!);

  // Save the file edited with the photo's date
  final directory = await getApplicationDocumentsDirectory();
  final file = await saveImageWithText(
      imageBytes,
      DateFormat('dd/MM/yyyy')
          .format(DateTime.parse(todaysPhoto['createdTime']!)),
      "${directory.path}/$filename");

  return file;
}
