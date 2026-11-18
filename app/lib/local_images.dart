import 'dart:io';

import 'package:image/image.dart' as img;

/// Processing for the photos the user keeps inside the app (build 20):
/// the custom avatar and the home photo. Both are written into the app
/// documents folder and stay LOCAL ONLY, never synced — the same rule
/// as receipt photos and home documents.

/// The custom avatar's fixed file name in the documents folder.
const customAvatarFileName = 'custom_avatar.jpg';

/// A home's photo file name in the documents folder, per home.
String homePhotoFileName(int homeId) => 'home_photo_$homeId.jpg';

/// Center-crop [sourcePath] to a square, downscale to [size] px and
/// write it as a JPEG at [destPath]. Returns false when the source
/// cannot be decoded or written; the caller then keeps whatever was
/// there before.
Future<bool> writeSquareAvatar(
  String sourcePath,
  String destPath, {
  int size = 256,
}) async {
  try {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return false;
    final cropped = img.copyResizeCropSquare(decoded, size: size);
    await File(destPath).writeAsBytes(img.encodeJpg(cropped, quality: 85));
    return true;
  } catch (_) {
    return false;
  }
}

/// Downscale [sourcePath] so its longest side is at most
/// [maxDimension] px and write it as a JPEG at [destPath]. No crop:
/// the screens show the photo with BoxFit.cover, which center-crops
/// visually without throwing any of the picture away on disk.
Future<bool> writeHomePhoto(
  String sourcePath,
  String destPath, {
  int maxDimension = 1200,
}) async {
  try {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return false;
    var out = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      out = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxDimension)
          : img.copyResize(decoded, height: maxDimension);
    }
    await File(destPath).writeAsBytes(img.encodeJpg(out, quality: 80));
    return true;
  } catch (_) {
    return false;
  }
}
