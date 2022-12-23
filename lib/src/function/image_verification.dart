import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imglib;
import 'package:in2niaga_library/src/core/image_transformation_functions.dart';
import 'package:path_provider/path_provider.dart';

class ImageVerivication {
  late Directory tempDir;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true),
  );

  Future<Map?> process(String? imagePath1, String? imagePath2) async {
    getApplicationDocumentsDirectory().then((value) {
      tempDir = value;
    });

    if (imagePath1 == null || imagePath2 == null) {}
    if (imagePath1 != null && imagePath2 != null) {
      int dt = DateTime.now().microsecondsSinceEpoch;

      InputImage image1 = InputImage.fromFilePath(imagePath1);
      List<Face> faces1 = await _faceDetector.processImage(image1);

      if (faces1.isEmpty) {}

      imglib.Image img1 = await compute(path2Image, imagePath1);

      imglib.Image faceImage1 = await compute(copyResize, {
        'input': img1,
        'width': 1080,
        'height': 692,
      });

      String faceImage1Path = '${tempDir.path}/1-$dt.jpg';
      File(faceImage1Path).writeAsBytesSync(imglib.encodeJpg(faceImage1));

      InputImage image2 = InputImage.fromFilePath(imagePath2);
      List<Face> faces2 = await _faceDetector.processImage(image2);

      if (faces2.isEmpty) {}

      imglib.Image img2 = await compute(path2Image, imagePath2);

      imglib.Image faceImage2 = await compute(copyResize, {
        'input': img2,
        'height': 1080,
        'width': 1925,
      });

      log(img2.width.toString());
      log(img2.height.toString());

      String faceImage2Path = '${tempDir.path}/2-$dt.jpg';
      File(faceImage2Path).writeAsBytesSync(imglib.encodeJpg(faceImage2));

      var request = http.MultipartRequest(
          'POST', Uri.parse('http://13.214.153.201/v1/verify?threshold=0.42'));
      request.files
          .add(await http.MultipartFile.fromPath('file1', faceImage1Path));
      request.files
          .add(await http.MultipartFile.fromPath('file2', faceImage2Path));

      http.StreamedResponse response = await request.send();
      String res = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        Map data = json.decode(res);

        return data;
      } else {
        return {};
      }
    }
  }
}
