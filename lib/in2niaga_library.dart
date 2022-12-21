library in2niaga_library;

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as imglib;
import 'package:in2niaga_library/src/core/image_transformation_functions.dart';
export 'package:in2niaga_library/src/presentation/livenessDetection.dart';

class In2niaga {
  Future<int> imageSharpness(String imagePath) async {
    imglib.Image img = await compute(path2Image, imagePath);
    imglib.Image input = await compute(copyResize, {'input': img});
    List grayImg = await compute(grayImage, input);
    final result = await compute(laplacian, grayImg);

    log(result.toString());
    return result;
  }
}
