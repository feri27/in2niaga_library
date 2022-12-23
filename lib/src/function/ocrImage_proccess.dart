import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OcrImageProcess {
  Future<Map?> processImage(
      dynamic image1, dynamic image2, dynamic idType) async {
    Uint8List imageFile1 = File(image1).readAsBytesSync();
    String b64image1 = base64.encode(imageFile1);
    String b64image2 = '';
    if (image2 == null) {
    } else {
      Uint8List imageFile2 = File(image2).readAsBytesSync();
      String b64image = base64.encode(imageFile2);
      b64image2 = b64image;
    }

    if (idType == 'CID') {
      var data = await Cid(b64image1, b64image2);
      return data;
    } else if (idType == 'Special Resident Permit') {
      var data = await Srp(b64image1, b64image2);
      return data;
    } else if (idType == 'Work Permit') {
      var data = await Wp(b64image1);
      return data;
    } else if (idType == 'Passport') {
      var data = await Passport(b64image1);
      return data;
    }
  }

  Future<Map> Cid(String image, String image2) async {
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
      log(response.reasonPhrase.toString());
      return {};
    }
  }

  Future<Map> Srp(String image, String image2) async {
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
      log(response.reasonPhrase.toString());
      return {};
    }
  }

  Future<Map> Passport(String image) async {
    var request = http.MultipartRequest('POST',
        Uri.parse('https://api.iqstars.me/In2Niaga/Verify-Passport.aspx'));
    request.fields.addAll({'Image': image});

    http.StreamedResponse response = await request.send();
    if (response.statusCode == 200) {
      String res = await response.stream.bytesToString();
      Map data = json.decode(res);
      return data;
    } else {
      log(response.reasonPhrase.toString());
      return {};
    }
  }

  Future<Map> Wp(String image) async {
    var request = http.MultipartRequest(
        'POST', Uri.parse('https://api.iqstars.me/In2Niaga/Verify-BtnWP.aspx'));
    request.fields.addAll({'FrontImage': image});

    http.StreamedResponse response = await request.send();
    if (response.statusCode == 200) {
      String res = await response.stream.bytesToString();
      Map data = json.decode(res);
      return data;
    } else {
      log(response.reasonPhrase.toString());
      return {};
    }
  }
}
