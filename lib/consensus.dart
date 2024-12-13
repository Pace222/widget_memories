import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'package:intl/intl.dart';

const int blacklistMaxSize = 14; // 2 weeks

Future<Map<String, String>> consensualRandom(
    List<Map<String, String>> allPhotos, List<String> blacklist) async {
  final groupedPhotos =
      allPhotos.fold<Map<String, List<Map<String, String>>>>({}, (acc, photo) {
    final createdTime = DateTime.parse(photo['createdTime']!);
    final monthDay = DateFormat('MM-dd').format(createdTime);
    acc[monthDay] = [...(acc[monthDay] ?? []), photo];
    return acc;
  });

  // Go back in time until a photo is found
  var now = DateTime.now();
  final seedStr = DateFormat('yyyy-MM-dd').format(now);
  Map<String, String>? photo;
  do {
    photo = _checkDate(seedStr, now, groupedPhotos, blacklist);
    now = now.subtract(const Duration(days: 1));
  } while (photo == null);

  // Add photo to blacklist
  blacklist.add(photo['id']!);

  if (blacklist.length > blacklistMaxSize) {
    // Remove oldest photo
    blacklist.removeAt(0);
  }

  return photo;
}

Map<String, String>? _checkDate(
    String seedStr,
    DateTime date,
    Map<String, List<Map<String, String>>> groupedPhotos,
    List<String> blacklist) {
  final monthDay = DateFormat('MM-dd').format(date);

  final candidates = groupedPhotos[monthDay];
  if (candidates == null) {
    return null;
  }

  _deterministicShuffle(seedStr, candidates);

  Map<String, String>? photo = candidates
      .where((photo) => !blacklist.contains(photo['id']!))
      .firstOrNull;

  return photo;
}

void _deterministicShuffle(String seedStr, List list) {
  final seedInt = int.parse(
      sha256.convert(utf8.encode(seedStr)).toString().substring(0, 15),
      radix: 16);
  list.shuffle(Random(seedInt));
}
