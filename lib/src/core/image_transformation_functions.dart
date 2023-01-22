import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart';

double translateX(
  double x,
  InputImageRotation rotation,
  Size size,
  Size absoluteImageSize,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x *
          size.width /
          (Platform.isIOS ? absoluteImageSize.width : absoluteImageSize.height);
    case InputImageRotation.rotation270deg:
      return size.width -
          x *
              size.width /
              (Platform.isIOS
                  ? absoluteImageSize.width
                  : absoluteImageSize.height);
    default:
      return x * size.width / absoluteImageSize.width;
  }
}

double translateY(
  double y,
  InputImageRotation rotation,
  Size size,
  Size absoluteImageSize,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y *
          size.height /
          (Platform.isIOS ? absoluteImageSize.height : absoluteImageSize.width);
    default:
      return y * size.height / absoluteImageSize.height;
  }
}

Future<imglib.Image> path2Image(String path) async {
  final bytes = await File(path).readAsBytes();
  imglib.Image? img = imglib.decodeImage(bytes);
  return img!;
}

Future<imglib.Image> copyResize(Map<String, dynamic> params) async {
  imglib.Image input = params["input"];
  int width = params["width"] ?? input.width;
  int height = params["height"] ?? input.height;

  return imglib.copyResize(
    input,
    width: width,
    height: height,
  );
}

Future<imglib.Image> copyCrop(Map<String, dynamic> params) async {
  imglib.Image input = params["input"];
  int x = params["x"] ?? 0;
  int y = params["y"] ?? 0;
  int w = params["w"] ?? 0;
  int h = params["h"] ?? 0;
  return imglib.copyCrop(input, x, y, w, h);
}

Future<imglib.Image> decodeImg(XFile file) async {
  final bytes = await File(file.path).readAsBytes();
  imglib.Image? src = imglib.decodeImage(bytes);
  return src!;
}

Future<imglib.Image> resizeImg(imglib.Image src) async {
  imglib.Image as = imglib.copyResize(
    src,
    width: 480,
    height: 800,
  );
  return as;
}

Future<imglib.Image> cropIDImage(imglib.Image file) async {
  imglib.Image destImage = imglib.copyCrop(file, 15, 45, 480, 320);
  return destImage;
}

Future<imglib.Image> cropSSMImage(imglib.Image file) async {
  imglib.Image destImage = imglib.copyCrop(file, 15, 90, 480, 410);
  return destImage;
}

Future<List<int>> encodeImg(imglib.Image img) async {
  final jpg = imglib.encodeJpg(img);
  return jpg;
}

Future<InputImage> cameraToInputImage(Map<String, dynamic> params) async {
  final CameraImage image = params['image'];
  final int sensorOrientation = params['sensorOrientation'];

  final WriteBuffer allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

  final imageRotation =
      InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;

  final inputImageFormat =
      InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

  final planeData = image.planes.map(
    (Plane plane) {
      return InputImagePlaneMetadata(
        bytesPerRow: plane.bytesPerRow,
        height: plane.height,
        width: plane.width,
      );
    },
  ).toList();

  final inputImageData = InputImageData(
    size: imageSize,
    imageRotation: imageRotation,
    inputImageFormat: inputImageFormat,
    planeData: planeData,
  );

  return InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
}

// Future<imglib.Image> camera2Image(Map<String, dynamic> params) async {
//   try {
//     final CameraLensDirection direction = params['direction'];
//     final CameraImage image = params['image'];

//     final int width = image.width;
//     final int height = image.height;

//     final img = imglib.Image(width, height);
//     const int hexFF = 0xFF000000;
//     final int uvyButtonStride = image.planes[1].bytesPerRow;
//     final int uvPixelStride = image.planes[1].bytesPerPixel ?? 0;

//     for (int x = 0; x < width; x++) {
//       for (int y = 0; y < height; y++) {
//         final int uvIndex =
//             uvPixelStride * (x / 2).floor() + uvyButtonStride * (y / 2).floor();
//         final int index = y * width + x;
//         final yp = image.planes[0].bytes[index];
//         final up = image.planes[1].bytes[uvIndex];
//         final vp = image.planes[2].bytes[uvIndex];

//         int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
//         int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
//             .round()
//             .clamp(0, 255);
//         int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

//         img.data[index] = hexFF | (b << 16) | (g << 8) | r;
//       }
//     }

//     var img1 = (direction == CameraLensDirection.front)
//         ? imglib.copyRotate(img, -90)
//         : imglib.copyRotate(img, 90);

//     return img1;
//   } catch (e) {
//     debugPrint(e.toString());
//     return imglib.Image(0, 0);
//   }
// }

Future<imglib.Image> camera2Image(Map<String, dynamic> params) async {
  final CameraLensDirection direction = params['direction'];
  final CameraImage image = params['image'];

  final int width = image.width;
  final int height = image.height;

  final yRowStride = image.planes[0].bytesPerRow;
  final uvRowStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel!;

  var img = imglib.Image(width, height);

  for (var w = 0; w < width; w++) {
    for (var h = 0; h < height; h++) {
      final uvIndex =
          uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
      final index = h * width + w;
      final yIndex = h * yRowStride + w;

      final y = image.planes[0].bytes[yIndex];
      final u = image.planes[1].bytes[uvIndex];
      final v = image.planes[2].bytes[uvIndex];

      img.data[index] = yuv2rgb(y, u, v);
    }
  }
  var img1 = (direction == CameraLensDirection.front)
      ? imglib.copyRotate(img, -90)
      : imglib.copyRotate(img, 90);

  return img1;
}

yuv2rgb(int y, int u, int v) {
  var r = (y + v * 1436 / 1024 - 179).round();
  var g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
  var b = (y + u * 1814 / 1024 - 227).round();
  r = r.clamp(0, 255);
  g = g.clamp(0, 255);
  b = b.clamp(0, 255);

  return 0xff000000 | ((b << 16) & 0xff0000) | ((g << 8) & 0xff00) | (r & 0xff);
}

Future<imglib.Image> cameraToImage(Map<String, dynamic> params) async {
  try {
    final CameraLensDirection direction = params['direction'];
    final CameraImage image = params['image'];
    final Rect rect = params['rect'];
    final bool crop = params['crop'] ?? true;
    final int left = (rect.left - 10).floor();
    final int top = (rect.top - 10).floor();
    final int right = (rect.right + 10).floor();
    final int bottom = (rect.bottom + 10).floor();

    final int width = image.width;
    final int height = image.height;

    final img = imglib.Image(width, height);
    const int hexFF = 0xFF000000;
    final int uvyButtonStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 0;
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvyButtonStride * (y / 2).floor();
        final int index = y * width + x;
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        img.data[index] = hexFF | (b << 16) | (g << 8) | r;
      }
    }

    var img1 = (direction == CameraLensDirection.front)
        ? imglib.copyRotate(img, -90)
        : imglib.copyRotate(img, 90);

    imglib.Image croppedImage = imglib.copyCrop(
      img1,
      left,
      top,
      right - left,
      bottom - top,
    );
    if (crop) {
      return imglib.copyResizeCropSquare(croppedImage, 112);
    }
    return croppedImage;
  } catch (e) {
    debugPrint(e.toString());
    return imglib.Image(0, 0);
  }
}

// Future<List> recognize(Map<String, dynamic> params) async {
//   try {
//     final imglib.Image image = params['image'];
//     final Interpreter interpreter = Interpreter.fromAddress(params['address']);

//     const int inputSize = 112;
//     const double mean = 128;
//     const double std = 128;
//     var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
//     var buffer = Float32List.view(convertedBytes.buffer);
//     int pixelIndex = 0;
//     for (var i = 0; i < inputSize; i++) {
//       for (var j = 0; j < inputSize; j++) {
//         var pixel = image.getPixel(j, i);
//         buffer[pixelIndex++] = (imglib.getRed(pixel) - mean) / std;
//         buffer[pixelIndex++] = (imglib.getGreen(pixel) - mean) / std;
//         buffer[pixelIndex++] = (imglib.getBlue(pixel) - mean) / std;
//       }
//     }
//     List input = convertedBytes.buffer.asFloat32List();

//     input = input.reshape([1, 112, 112, 3]);
//     List output = List.filled(1 * 192, null, growable: false).reshape([1, 192]);
//     interpreter.run(input, output);
//     return output.reshape([192]);
//   } catch (e) {
//     debugPrint(e.toString());
//     return [];
//   }
// }

Future<double> euclideanDistance(List<List> embeds) async {
  try {
    final List e1 = embeds[0];
    final List e2 = embeds[1];
    double sum1 = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum1 += pow((e1[i] - e2[i]), 2);
    }

    return sqrt(sum1);
  } catch (e) {
    debugPrint(e.toString());
    return 0;
  }
}

Future<imglib.Image> cropImage(Map<String, dynamic> params) async {
  try {
    final CameraLensDirection direction = params['direction'];
    final CameraImage image = params['image'];
    final Rect rect = params['rect'];
    final bool square = params['square'] ?? true;
    final bool crop = params['crop'] ?? true;
    int left = (rect.left - 10).floor();
    int top = (rect.top - 10).floor();
    int right = (rect.right + 10).floor();
    int bottom = (rect.bottom + 10).floor();
    final int width = image.width;
    final int height = image.height;
    var img = imglib.Image(width, height); // Create Image buffer
    const int hexFF = 0xFF000000;
    final int uvyButtonStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 0;
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvyButtonStride * (y / 2).floor();
        final int index = y * width + x;
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        img.data[index] = hexFF | (b << 16) | (g << 8) | r;
      }
    }

    var img1 = (direction == CameraLensDirection.front)
        ? imglib.copyRotate(img, -90)
        : imglib.copyRotate(img, 90);

    int cropWidth = right - left;
    int cropHeight = bottom - top;

    if (square) {
      if (cropWidth < cropHeight) {
        left = left - (cropHeight - cropWidth) ~/ 2;
        cropWidth = cropHeight;
      }
      if (cropWidth > cropHeight) {
        top = top - (cropWidth - cropHeight) ~/ 2;
        cropHeight = cropWidth;
      }
    }

    imglib.Image croppedImage = imglib.copyCrop(
      img1,
      left,
      top,
      cropWidth,
      cropHeight,
    );

    if (crop) {
      croppedImage = imglib.copyResizeCropSquare(croppedImage, 256);
    } else {
      croppedImage = imglib.copyResize(croppedImage, width: 256, height: 256);
    }

    return croppedImage;
  } catch (e) {
    debugPrint(e.toString());
    return imglib.Image(0, 0);
  }
}

Future<List> grayImage(imglib.Image croppedImage) async {
  croppedImage = imglib.grayscale(croppedImage);
  int w = croppedImage.width;
  int h = croppedImage.height;

  List result = List.filled(w * h, null, growable: false).reshape([w, h]);

  int alpha = 0xFF << 24;

  for (var y = 0, pi = 0; y < h; ++y) {
    for (var x = 0; x < w; ++x, ++pi) {
      var rgba = croppedImage[pi];
      int red = imglib.getRed(rgba);
      int green = imglib.getGreen(rgba);
      int blue = imglib.getBlue(rgba);
      int grey = (red * 0.3 + green * 0.59 + blue * 0.11).toInt();
      grey = alpha | (grey << 16) | (grey << 8) | grey;
      result[x][y] = grey;
    }
  }

  // for (int i = 0; i < h; i++) {
  //   for (int j = 0; j < w; j++) {
  //     int pixel = croppedImage.getPixel(i, j);
  //     int red = imglib.getRed(pixel);
  //     int green = imglib.getGreen(pixel);
  //     int blue = imglib.getBlue(pixel);

  //     int grey = (red * 0.3 + green * 0.59 + blue * 0.11).toInt();
  //     grey = alpha | (grey << 16) | (grey << 8) | grey;
  //     result[i][j] = grey;
  //   }
  // }
  return result;
}

Future<int> laplacian(List img) async {
  try {
    final List laplace = [
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0]
    ];
    final int size = laplace.length;

    final int height = img.length;
    final int width = img[0].length;

    int score = 0;
    for (int x = 0; x < height - size + 1; x++) {
      for (int y = 0; y < width - size + 1; y++) {
        int result = 0;

        for (int i = 0; i < size; i++) {
          for (int j = 0; j < size; j++) {
            result += (img[x + i][y + j] & 0xFF) * laplace[i][j] as int;
          }
        }
        if (result > 50) {
          score++;
        }
      }
    }
    return score;
  } catch (e) {
    debugPrint(e.toString());
    return 0;
  }
}

Future<Float32List> imageToByteListFloat32(imglib.Image image) async {
  try {
    const int inputSize = 256;
    const double mean = 0;
    const double std = 256;
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (imglib.getRed(pixel) - mean) / std;
        buffer[pixelIndex++] = (imglib.getGreen(pixel) - mean) / std;
        buffer[pixelIndex++] = (imglib.getBlue(pixel) - mean) / std;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  } catch (e) {
    debugPrint(e.toString());
    return Float32List(0);
  }
}

// Future<double> antiSpoofing(Map<String, dynamic> params) async {
//   try {
//     List input = params['input'];
//     final Interpreter interpreter = Interpreter.fromAddress(params['address']);

//     input = input.reshape([1, 256, 256, 3]);
//     Map<int, Object> output = {};
//     List clssPred = List.filled(1 * 8, null, growable: false).reshape([1, 8]);
//     List leafNodeMask =
//         List.filled(1 * 8, null, growable: false).reshape([1, 8]);
//     output[interpreter.getOutputIndex("Identity")] = clssPred;
//     output[interpreter.getOutputIndex("Identity_1")] = leafNodeMask;
//     interpreter.runForMultipleInputs([input], output);
//     double score = 0;
//     for (int i = 0; i < 8; i++) {
//       score += (clssPred[0][i]).abs() * leafNodeMask[0][i];
//     }
//     return score;
//   } catch (e) {
//     debugPrint(e.toString());
//     return 0;
//   }
// }
