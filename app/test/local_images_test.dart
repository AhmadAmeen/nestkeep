import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nestkeep/local_images.dart';

/// Build 21: picked photos must be stored physically upright.
/// The two fixtures are the same picture written by an independent
/// encoder (PIL): 40x20 stored pixels, the left half red and the
/// right half blue, carrying EXIF orientation 6 — so shown correctly
/// it stands 20 wide x 40 high with red on top and blue underneath.
/// The WebP one is the case that used to slip through: its decoder
/// hands the orientation flag back unapplied, and processing kept
/// the sideways pixels. The JPEG one guards against double
/// rotation, because the JPEG decoder applies the flag itself and
/// the explicit bake in the pipeline must then be a no-op.
const _jpegFixture =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/2wBDAAIBAQEBAQIBAQECAgICAgQDAgICAgUEBAMEBgUGBgYFBgYGBwkIBgcJBwYGCAsICQoKCgoKBggLDAsKDAkKCgr/2wBDAQICAgICAgUDAwUKBwYHCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgr/wAARCAAUACgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD5booor+fz/Xw85+P/APzCf+2//tOvOa9G+P8A/wAwn/tv/wC0685r/X36Ln/Jiso/7mP/AFKrH+Wv0jf+TzZp/wBwP/UeiFFFFfv5+In0ZRRRX+AZ/twec/H/AP5hP/bf/wBp15zRRX+vv0XP+TFZR/3Mf+pVY/y1+kb/AMnmzT/uB/6j0Qooor9/PxE//9k=';
const _webpFixture =
    'UklGRq4AAABXRUJQVlA4WAoAAAAIAAAAJwAAEwAAVlA4IG4AAADwBQCdASooABQAPhkKhEEhBgEABABhKAMz/AngH4AfsB/QOQC7AfsBhAPwArv/cAAL3mDP7VGTAAD++b4X/9x2HtbOT//+j307FTXPP4ATGjeAgjMg39kMF4LrltDU0sFtjc9Xq2liVALRAoAAAEVYSUYaAAAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAA=';

bool _isRed(img.Pixel p) => p.r > 150 && p.r > p.b + 60;
bool _isBlue(img.Pixel p) => p.b > 150 && p.b > p.r + 60;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nk_local_images');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<String> fixture(String name, String base64) async {
    final path = '${dir.path}/$name';
    await File(path).writeAsBytes(base64Decode(base64));
    return path;
  }

  test('a WebP home photo is stored upright: dimensions swapped, '
      'red on top, flag cleared', () async {
    final src = await fixture('src.webp', _webpFixture);
    final dest = '${dir.path}/home.jpg';
    expect(await writeHomePhoto(src, dest), isTrue);
    final out = img.decodeJpg(await File(dest).readAsBytes())!;
    expect(out.width, 20);
    expect(out.height, 40);
    expect(out.exif.imageIfd.hasOrientation, isFalse);
    expect(_isRed(out.getPixel(10, 4)), isTrue);
    expect(_isBlue(out.getPixel(10, 35)), isTrue);
  });

  test('a WebP custom avatar is cropped from the upright picture: '
      'red on top, blue underneath', () async {
    final src = await fixture('src.webp', _webpFixture);
    final dest = '${dir.path}/avatar.jpg';
    expect(await writeSquareAvatar(src, dest), isTrue);
    final out = img.decodeJpg(await File(dest).readAsBytes())!;
    expect(out.width, 256);
    expect(out.height, 256);
    expect(_isRed(out.getPixel(128, 25)), isTrue);
    expect(_isBlue(out.getPixel(128, 230)), isTrue);
  });

  test('a JPEG home photo stays upright exactly once (no double '
      'rotation)', () async {
    final src = await fixture('src.jpg', _jpegFixture);
    final dest = '${dir.path}/home.jpg';
    expect(await writeHomePhoto(src, dest), isTrue);
    final out = img.decodeJpg(await File(dest).readAsBytes())!;
    expect(out.width, 20);
    expect(out.height, 40);
    expect(_isRed(out.getPixel(10, 4)), isTrue);
    expect(_isBlue(out.getPixel(10, 35)), isTrue);
  });
}
