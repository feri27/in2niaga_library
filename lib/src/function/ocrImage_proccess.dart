import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in2niaga_library/src/core/image_transformation_functions.dart';
import 'package:image/image.dart' as imglib;
import 'package:path_provider/path_provider.dart';

class OcrImageProcess {
  Future<Map?> processImage(
      Uint8List? image1, Uint8List? image2, dynamic idType) async {
    Directory tempDir = await getTemporaryDirectory();
    getApplicationDocumentsDirectory().then((value) {
      tempDir = value;
    });

    Uint8List imageFile1 = image1!;
    String b64image1 = base64.encode(imageFile1);
    String b64image2 = '';
    if (image2 == null) {
    } else {
      Uint8List imageFile2 = image2;
      String b64image = base64.encode(imageFile2);
      b64image2 = b64image;
    }

    String Path =
        '${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}result_id.jpg';
    await File(Path).writeAsBytes(image1);

    imglib.Image img1 = await compute(path2Image, Path);

    imglib.Image IdImage1 = await compute(copyResize, {
      'input': img1,
      'width': 1080,
      'height': 810,
    });
    int dt = DateTime.now().microsecondsSinceEpoch;
    String idImage1Path = '${tempDir.path}/Id1-$dt.jpg';
    File(idImage1Path).writeAsBytesSync(imglib.encodeJpg(IdImage1));

    if (idType == 'CID') {
      var data = await Cid(b64image1, b64image2);

      Map toJson() => {
            'data_result': data,
            'front_path': idImage1Path,
          };
      return toJson();
    } else if (idType == 'Special Resident Permit') {
      var data = await Srp(b64image1, b64image2);
      Map toJson() => {
            'data_result': data,
            'front_path': idImage1Path,
          };
      return toJson();
    } else if (idType == 'Work Permit') {
      var data = await Wp(b64image1);
      Map toJson() => {
            'data_result': data,
            'front_path': idImage1Path,
          };
      return toJson();
    } else if (idType == 'Passport') {
      var data = await Passport(b64image1);
      Map toJson() => {
            'data_result': data,
            'front_path': idImage1Path,
          };
      return toJson();
    }
  }

  // ignore: non_constant_identifier_names
  Future<Map?> Cid(String image, String image2) async {
    try {
      var request = http.MultipartRequest('POST',
          Uri.parse('https://api.iqstars.me/In2Niaga/Verify-BtnCID.aspx'));
      request.fields.addAll({'FrontImage': image});
      request.fields.addAll({'BackImage': image2});

      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        String res = await response.stream.bytesToString();
        Map data = json.decode(res);
        return data;
      } else {
        Map data = json.decode(response.reasonPhrase.toString());
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('error $e');
      }
    }
  }

  Future<Map?> Srp(String image, String image2) async {
    try {
      var request = http.MultipartRequest('POST',
          Uri.parse('https://api.iqstars.me/In2Niaga/Verify-BtnSRP.aspx'));
      request.fields.addAll({'FrontImage': image});
      request.fields.addAll({'BackImage': image2});

      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        String res = await response.stream.bytesToString();
        Map data = json.decode(res);
        return data;
      } else {
        Map data = json.decode(response.reasonPhrase.toString());
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('error $e');
      }
    }
  }

  Future<Map?> Passport(String image) async {
    try {
      var request = http.MultipartRequest('POST',
          Uri.parse('https://api.iqstars.me/In2Niaga/Verify-Passport.aspx'));
      request.fields.addAll({'Image': image});

      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        String res = await response.stream.bytesToString();
        Map data = json.decode(res);
        return data;
      } else {
        Map data = json.decode(response.reasonPhrase.toString());
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('error $e');
      }
    }
  }

  Future<Map?> Wp(String image) async {
    try {
      var request = http.MultipartRequest('POST',
          Uri.parse('https://api.iqstars.me/In2Niaga/Verify-BtnWP.aspx'));
      request.fields.addAll({'FrontImage': image});

      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        String res = await response.stream.bytesToString();
        Map data = json.decode(res);
        return data;
      } else {
        Map data = json.decode(response.reasonPhrase.toString());
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('error $e');
      }
    }
  }
}
