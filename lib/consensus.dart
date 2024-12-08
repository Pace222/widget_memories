import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int blacklistMaxSize = 14; // 2 weeks

Future<Map<String, String>> consensualRandom(List<Map<String, String>> allPhotos) async {
  final groupedPhotos = allPhotos.fold<Map<String, List<Map<String, String>>>>({}, (acc, photo) {
    final createdTime = DateTime.parse(photo['createdTime'] as String);
    final monthDay = DateFormat('MM-dd').format(createdTime);
    acc[monthDay] = [...(acc[monthDay] ?? []), photo];
    return acc;
  });

  // Go back in time until a photo is found
  var now = DateTime.now();
  final seedStr = DateFormat('yyyy-MM-dd').format(now);
  Map<String, String>? photo;
  final prefs = await SharedPreferences.getInstance();
  do {
    photo = _checkDate(seedStr, now, groupedPhotos, prefs);
    now = now.subtract(const Duration(days: 1));
  } while (photo == null);

  // Add photo to blacklist
  await prefs.setString(photo['id'] as String, seedStr);
  if (prefs.getKeys().length > blacklistMaxSize) {
    // Remove oldest photo based on time
    final oldestPhoto = prefs.getKeys().reduce((a, b) => DateTime.parse(prefs.getString(a)!).compareTo(DateTime.parse(prefs.getString(b)!)) < 0 ? a : b);
    await prefs.remove(oldestPhoto);
  }

  return photo;
}

Map<String, String>? _checkDate(String seedStr, DateTime date, Map<String, List<Map<String, String>>> groupedPhotos, SharedPreferences prefs) {
  final monthDay = DateFormat('MM-dd').format(date);

  final candidates = groupedPhotos[monthDay];
  if (candidates == null) {
    return null;
  }

  _deterministicShuffle(seedStr, candidates);

  Map<String, String>? photo = candidates.where(
    (photo) => !prefs.containsKey(photo['id'] as String)
  ).firstOrNull;

  return photo;
}


void _deterministicShuffle(String seedStr, List list) {
  final seedInt = int.parse(sha256.convert(utf8.encode(seedStr)).toString().substring(0, 16), radix: 16);
  list.shuffle(Random(seedInt));
}