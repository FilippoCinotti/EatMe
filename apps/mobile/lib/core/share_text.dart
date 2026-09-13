import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareText(BuildContext context, String title, String text) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(title: title, text: text, sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size));
}
