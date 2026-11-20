/// What the app needs from the phone besides the network.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A picked reference picture.
typedef PickedImage = ({Uint8List bytes, String mime});

/// The phone's share sheet and gallery, replaceable in tests.
class Services {
  /// Uses [share] and [pickImage].
  const new({required this.share, required this.pickImage});

  /// The real phone.
  const new phone() : share = sharePng, pickImage = pickFromGallery;

  /// Hands a finished PNG to the share sheet.
  final Future<void> Function(Uint8List png) share;

  /// Lets the reviewer pick a picture; null when they back out.
  final Future<PickedImage?> Function() pickImage;
}

/// Writes [png] to the cache and opens the share sheet on it.
Future<void> sharePng(Uint8List png) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/logos.png');
  await file.writeAsBytes(png);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
  );
}

/// Picks one picture from the gallery, downscaled to fit the upload limit.
Future<PickedImage?> pickFromGallery() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;
  final name = file.name.toLowerCase();
  final mime = name.endsWith('.png')
      ? 'image/png'
      : name.endsWith('.webp')
      ? 'image/webp'
      : name.endsWith('.gif')
      ? 'image/gif'
      : 'image/jpeg';
  return (bytes: await file.readAsBytes(), mime: mime);
}
