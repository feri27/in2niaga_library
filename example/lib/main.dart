import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:example/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:in2niaga_library/in2niaga_library.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'IN2NIAGA PACKAGE TEST'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _result;

  String? image1;
  String? image2;

  dynamic frontImagePath;
  dynamic backImagePath;

  bool showBtn = false;

  String? idType;

  String? imagePath1;
  String? imagePath2;

  late Size imageSize = const Size(0.00, 0.00);
  late Size imageSize2 = const Size(0.00, 0.00);

  Future<void> liveness() async {
    final results = await availableCameras().then(
      (value) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceDetectionScreen(cameras: value),
        ),
      ),
    );
    if (results != null) {
      Map<String, dynamic> data = jsonDecode(results);
      setState(() {
        _result = data['data'];
        imagePath1 = data['path'];
      });
      _getImageDimension(imagePath1!);
    }
  }

  void _getImageDimension(String pathfile) {
    Image image = Image.memory(File(pathfile).readAsBytesSync());
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          setState(() {
            imageSize =
                Size(myImage.width.toDouble(), myImage.height.toDouble());
          });
        },
      ),
    );
  }

  void _getImageDimension2(String pathfile) {
    Image image = Image.memory(File(pathfile).readAsBytesSync());
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          setState(() {
            imageSize2 =
                Size(myImage.width.toDouble(), myImage.height.toDouble());
          });
        },
      ),
    );
  }

  Future<void> processFace() async {
    setState(() {
      _result = "Pleasewait..";
      imagePath1 = null;
      imagePath2 = null;
    });
    Map? data = await ImageVerivication().process(image1, image2);
    var datas = Map<String, dynamic>.from(data as Map);
    setState(() {
      _result = datas['data_result'].toString();
      image1 = null;
      image2 = null;
      imagePath1 = datas['path_1'].toString();
      imagePath2 = datas['path_2'].toString();
    });

    _getImageDimension(imagePath1!);
    _getImageDimension2(imagePath2!);
  }

  Future<void> OcrProcces() async {
    setState(() {
      _result = "Pleasewait..";
      imagePath1 = null;
      imagePath2 = null;
    });
    Map? data = await OcrImageProcess()
        .processImage(frontImagePath, backImagePath, idType);

    var datas = Map<String, dynamic>.from(data as Map);

    setState(() {
      _result = datas['data_result'].toString();

      imagePath1 = datas['front_path'].toString();

      frontImagePath = null;
      backImagePath = null;
    });
    _getImageDimension(imagePath1!);
  }

  Future<void> showPickerId(BuildContext context, String type) async {
    final result = await availableCameras().then(
      (value) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OcrPageCapture(
            title: "ID Verification",
            cameras: value,
            type: type,
            idType: idType,
          ),
        ),
      ),
    );
    if (result != null) {
      log(result);
      setState(() {
        _result = null;
      });
      setState(() {
        if (type == 'front') {
          frontImagePath = result;
        } else {
          backImagePath = result;
        }
      });
    }
  }

  void showPickerFace(context, String result) {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: const Text('Pick photo from?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _picker
                  .pickImage(source: ImageSource.gallery)
                  .then((value) async {
                if (value != null) {
                  setState(() {
                    _result = null;
                  });
                  if (result == 'image1') {
                    setState(() {
                      image1 = value.path;
                    });
                  } else if (result == 'image2') {
                    setState(() {
                      image2 = value.path;
                    });
                  }
                }
              });
            },
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _picker.pickImage(source: ImageSource.camera).then((value) async {
                if (value != null) {
                  setState(() {
                    _result = null;
                  });
                  if (result == 'image1') {
                    setState(() {
                      image1 = value.path;
                    });
                  } else if (result == 'image2') {
                    setState(() {
                      image2 = value.path;
                    });
                  }
                }
              });
            },
            child: const Text('Camera'),
          ),
        ],
      ),
    );
  }

  void showPicker(context) {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: const Text('Pick photo from?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _picker
                  .pickImage(source: ImageSource.gallery)
                  .then((value) async {
                if (value != null) {
                  setState(() {
                    _result = "Pleasewait..";
                  });
                  var res = await In2niaga().imageSharpness(value.path);

                  setState(() {
                    _result = 'Sharpness: $res';
                  });
                }
              });
            },
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _picker.pickImage(source: ImageSource.camera).then((value) async {
                if (value != null) {
                  setState(() {
                    _result = "Pleasewait..";
                  });

                  var res = await In2niaga().imageSharpness(value.path);

                  setState(() {
                    _result = 'Sharpness: $res';
                  });
                }
              });
            },
            child: const Text('Camera'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: liveness,
              child: const SizedBox(
                height: 50,
                child: Card(
                  color: Colors.green,
                  child: Center(
                    child: Text('Liveness Detection',
                        style: TextStyle(
                            color: Colors.white, fontFamily: "Roboto")),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                showPicker(context);
              },
              child: const SizedBox(
                height: 50,
                child: Card(
                  color: Colors.red,
                  child: Center(
                    child: Text('Image Sharpness',
                        style: TextStyle(
                            color: Colors.white, fontFamily: "Roboto")),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Container(
                color: Colors.grey,
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Face Ferivication"),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            showPickerFace(context, 'image1');
                          },
                          child: SizedBox(
                            height: 50,
                            width: 180,
                            child: Card(
                              color: Colors.blue,
                              child: Center(
                                child: Text(
                                    (image1 == null) ? 'Select Image 1' : 'OK',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: "Roboto")),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            showPickerFace(context, 'image2');
                          },
                          child: SizedBox(
                            height: 50,
                            width: 180,
                            child: Card(
                              color: Colors.blue,
                              child: Center(
                                child: Text(
                                    (image2 == null) ? 'Select Image 2' : 'OK',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: "Roboto")),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        processFace();
                      },
                      child: const SizedBox(
                        height: 50,
                        width: 200,
                        child: Card(
                          color: Colors.black,
                          child: Center(
                            child: Text('Proccess',
                                style: TextStyle(
                                    color: Colors.white, fontFamily: "Roboto")),
                          ),
                        ),
                      ),
                    ),
                  ],
                )),
            SizedBox(
              height: 10,
            ),
            Container(
                color: Colors.grey,
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("OCR"),
                    Container(
                        color: Colors.white,
                        padding: EdgeInsets.all(10),
                        child: CustomDropdown(
                          labelText: 'Select ID',
                          hintText: 'Select ID',
                          value: idType,
                          items: [
                            "CID",
                            "Special Resident Permit",
                            "Work Permit",
                            "Passport"
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              idType = value;
                            });
                          },
                        )),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            showPickerId(context, 'front');
                          },
                          child: SizedBox(
                            height: 50,
                            width: 180,
                            child: Card(
                              color: Colors.blue,
                              child: Center(
                                child: Text(
                                    (frontImagePath == null)
                                        ? 'Front Image'
                                        : 'OK',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: "Roboto")),
                              ),
                            ),
                          ),
                        ),
                        if (idType == 'CID' ||
                            idType == 'Special Resident Permit')
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              showPickerId(context, 'back');
                            },
                            child: SizedBox(
                              height: 50,
                              width: 180,
                              child: Card(
                                color: Colors.blue,
                                child: Center(
                                  child: Text(
                                      (backImagePath == null)
                                          ? 'Back Image'
                                          : 'OK',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: "Roboto")),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        OcrProcces();
                      },
                      child: const SizedBox(
                        height: 50,
                        width: 200,
                        child: Card(
                          color: Colors.black,
                          child: Center(
                            child: Text('Proccess',
                                style: TextStyle(
                                    color: Colors.white, fontFamily: "Roboto")),
                          ),
                        ),
                      ),
                    ),
                  ],
                )),
            const SizedBox(
              height: 30,
            ),
            SizedBox(
                height: 200,
                width: 300,
                child: SingleChildScrollView(
                    child: Column(children: [
                  Text('Result: $_result',
                      style: const TextStyle(
                        letterSpacing: 0.5,
                        color: Colors.black54,
                        fontFamily: "Roboto",
                        fontWeight: FontWeight.w600,
                      )),
                  Row(children: [
                    if (imagePath1 != null)
                      Image.memory(
                        File(imagePath1 ?? '').readAsBytesSync(),
                        fit: BoxFit.cover,
                        width: 130,
                        height: 100,
                      ),
                    const SizedBox(
                      width: 10,
                    ),
                    if (imagePath2 != null)
                      Image.memory(
                        File(imagePath2 ?? '').readAsBytesSync(),
                        fit: BoxFit.cover,
                        width: 130,
                        height: 100,
                      )
                  ]),
                  Row(
                    children: [
                      if (imagePath1 != null)
                        Text(
                          // ignore: unnecessary_null_comparison
                          imageSize != null
                              ? 'W : ${imageSize.width.toString()}'
                              : '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (imagePath1 != null)
                        Text(
                          imageSize != null
                              ? '  H : ${imageSize.height.toString()}'
                              : '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(
                        width: 50,
                      ),
                      if (imagePath2 != null)
                        Text(
                          imageSize2 != null
                              ? 'W : ${imageSize2.width.toString()}'
                              : '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (imagePath2 != null)
                        Text(
                          imageSize2 != null
                              ? '  H : ${imageSize2.height.toString()}'
                              : '',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  )
                ])))
          ],
        ),
      ),
    );
  }
}
