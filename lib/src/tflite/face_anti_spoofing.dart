import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;
import 'package:in2niaga_library/src/tflite/util.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceAntiSpoofing {
  static const int inputImageSize = 256;
  static double threshold = 0.2;
  static int laplaceThreshold = 50;
  static int laplacianThreshold = 1500;

  double factor = 0.709;
  double pNetThreshold = 0.6;
  double rNetThreshold = 0.7;
  double oNetThreshold = 0.7;

  late Interpreter _interpreter;

  FaceAntiSpoofing() {
    _loadModel();
  }

  void _loadModel() async {
    InterpreterOptions options = InterpreterOptions();
    // final gpuDelegateV2 = GpuDelegateV2(
    //   options: GpuDelegateOptionsV2(
    //     isPrecisionLossAllowed: false,
    //     inferencePreference: TfLiteGpuInferenceUsage.fastSingleAnswer,
    //     inferencePriority1: TfLiteGpuInferencePriority.minLatency,
    //     inferencePriority2: TfLiteGpuInferencePriority.auto,
    //     inferencePriority3: TfLiteGpuInferencePriority.auto,
    //   ),
    // );
    options.threads = 12;
    // options.addDelegate(gpuDelegateV2);

    _interpreter = await Interpreter.fromAsset(
      'tflite/faceantispoofing.tflite',
      options: options,
    );
  }

  void dispose() {
    _interpreter.close();
  }

  int getAddres() {
    return _interpreter.address;
  }

  Future<double> getScore(Map<String, dynamic> params) async {
    CameraLensDirection direction = params['direction'];
    CameraImage image = params['image'];
    int left = params['left'];
    int top = params['top'];
    int right = params['right'];
    int bottom = params['bottom'];
    int width = image.width;
    int height = image.height;
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
        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        // color: 0x FF  FF  FF  FF
        //           A   B   G   R
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
    croppedImage = imglib.copyResizeCropSquare(croppedImage, inputImageSize);

    var convertedBytes = Float32List(1 * inputImageSize * inputImageSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputImageSize; i++) {
      for (var j = 0; j < inputImageSize; j++) {
        var pixel = croppedImage.getPixel(j, i);
        buffer[pixelIndex++] = (imglib.getRed(pixel) - 128) / 128;
        buffer[pixelIndex++] = (imglib.getGreen(pixel) - 128) / 128;
        buffer[pixelIndex++] = (imglib.getBlue(pixel) - 128) / 128;
      }
    }
    List input = convertedBytes.buffer.asFloat32List();

    input = input.reshape([1, inputImageSize, inputImageSize, 3]);
    Map<int, Object> output = {};
    List clssPred = List.filled(1 * 8, null, growable: false).reshape([1, 8]);
    List leafNodeMask =
        List.filled(1 * 8, null, growable: false).reshape([1, 8]);
    output[_interpreter.getOutputIndex("Identity")] = clssPred;
    output[_interpreter.getOutputIndex("Identity_1")] = leafNodeMask;
    _interpreter.runForMultipleInputs([input], output);

    double score = 0;
    for (int i = 0; i < 8; i++) {
      score += (clssPred[0][i]).abs() * leafNodeMask[0][i];
    }
    return score;
  }

  Future<double> antiSpoofing(imglib.Image croppedImage) async {
    List input =
        Util.imageToByteListFloat32(croppedImage, inputImageSize, 128, 128);
    input = input.reshape([1, inputImageSize, inputImageSize, 3]);
    Map<int, Object> output = {};
    List clssPred = List.filled(1 * 8, null, growable: false).reshape([1, 8]);
    List leafNodeMask =
        List.filled(1 * 8, null, growable: false).reshape([1, 8]);
    output[_interpreter.getOutputIndex("Identity")] = clssPred;
    output[_interpreter.getOutputIndex("Identity_1")] = leafNodeMask;
    _interpreter.runForMultipleInputs([input], output);
    return leafScore(clssPred, leafNodeMask);
  }

  double leafScore(List clssPred, List leafNodeMask) {
    double score = 0;
    for (int i = 0; i < 8; i++) {
      score += (clssPred[0][i]).abs() * leafNodeMask[0][i];
    }
    return score;
  }

  Future<int> laplacian(imglib.Image croppedImage) async {
    List img = grayImage(croppedImage);
    List laplace = [
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0]
    ];
    int size = laplace.length;

    int height = img.length;
    int width = img[0].length;

    int score = 0;
    for (int x = 0; x < height - size + 1; x++) {
      for (int y = 0; y < width - size + 1; y++) {
        int result = 0;

        for (int i = 0; i < size; i++) {
          for (int j = 0; j < size; j++) {
            result += (img[x + i][y + j] & 0xFF) * laplace[i][j] as int;
          }
        }
        if (result > laplaceThreshold) {
          score++;
        }
      }
    }
    return score;
  }

  imglib.Image cropImage(
    CameraLensDirection direction,
    CameraImage image,
    int left,
    int top,
    int right,
    int bottom,
  ) {
    int width = image.width;
    int height = image.height;
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
        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        // color: 0x FF  FF  FF  FF
        //           A   B   G   R
        img.data[index] = hexFF | (b << 16) | (g << 8) | r;
      }
    }

    var img1 = (direction == CameraLensDirection.front)
        ? imglib.copyRotate(img, -90)
        : imglib.copyRotate(img, 90);

    int cropWidth = right - left;
    int cropHeight = bottom - top;
    if (cropWidth < cropHeight) {
      left = left - (cropHeight - cropWidth) ~/ 2;
      cropWidth = cropHeight;
    }
    if (cropWidth > cropHeight) {
      top = top - (cropWidth - cropHeight) ~/ 2;
      cropHeight = cropWidth;
    }

    imglib.Image croppedImage = imglib.copyCrop(
      img1,
      left,
      top,
      cropWidth,
      cropHeight,
    );
    croppedImage = imglib.copyResizeCropSquare(croppedImage, inputImageSize);
    return croppedImage;
  }

  List grayImage(imglib.Image croppedImage) {
    int w = croppedImage.width;
    int h = croppedImage.height;

    List result = List.filled(w * h, null, growable: false).reshape([w, h]);

    int alpha = 0xFF << 24;

    for (int i = 0; i < h; i++) {
      for (int j = 0; j < w; j++) {
        int val = croppedImage.getPixel(i, j);
        int red = ((val >> 16) & 0xFF);
        int green = ((val >> 8) & 0xFF);
        int blue = (val & 0xFF);

        int grey = (red * 0.3 + green * 0.59 + blue * 0.11).toInt();
        grey = alpha | (grey << 16) | (grey << 8) | grey;
        result[i][j] = grey;
      }
    }
    return result;
  }
}
