import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';

class DataExport {
  static Future<Directory> directory() async =>
      Directory('${(await getTemporaryDirectory()).path}/eatme-exports');
  static Future<void> clear() async {
    final folder = await directory();
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  static Future<void> share(BuildContext context, Json data) async {
    await clear();
    final folder = await directory();
    await folder.create(recursive: true);
    final file = File('${folder.path}/eatme-data.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        title: 'EatMe+ data export',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    // Retain the file until the next launch/logout so the selected receiver can read it.
  }
}
