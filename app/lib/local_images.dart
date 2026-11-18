import 'dart:io';

import 'package:image/image.dart' as img;

/// Processing for the photos the user keeps inside the app (build 20):
/// the custom avatar and the home photo. Both are written into the app
/// documents folder and stay LOCAL ONLY, never synced — the same rule
/// as receipt photos and home documents.
///
/// Orientation (build 21): both writers bake the picked photo's EXIF
/// orientation into the pixels right after decoding, so the JPEG on
/// disk is physically upright with the flag cleared and shows the
/// right way up in every viewer. This cannot be left to the decoders:
/// the JPEG decoder happens to apply orientation while decoding, but
/// the WebP decoder hands the flag back unapplied (and the square
/// crop never applied it either), so a sideways-stored photo used to
/// survive processing sideways. Baking here, at the one shared point,
/// covers every format the picker can return.

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
    final cropped =
        img.copyResizeCropSquare(img.bakeOrientation(decoded), size: size);
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
    var out = img.bakeOrientation(decoded);
    if (out.width > maxDimension || out.height > maxDimension) {
      out = out.width >= out.height
          ? img.copyResize(out, width: maxDimension)
          : img.copyResize(out, height: maxDimension);
    }
    await File(destPath).writeAsBytes(img.encodeJpg(out, quality: 80));
    return true;
  } catch (_) {
    return false;
  }
}
