import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> dialPhone(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }
  await Clipboard.setData(ClipboardData(text: phone));
  return false;
}
