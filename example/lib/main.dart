import 'dart:developer';

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

  String? frontImagePath;
  String? backImagePath;

  bool showBtn = false;

  String? idType;

  Future<void> liveness() async {
    final results = await availableCameras().then(
      (value) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FaceDetectionScreen(title: 'Liveness Detection', cameras: value),
        ),
      ),
    );
    if (results != null) {
      setState(() {
        _result = results;
      });
    }
  }

  Future<void> processFace() async {
    setState(() {
      _result = "Pleasewait..";
    });
    Map? data = await ImageVerivication().process(image1, image2);

    setState(() {
      _result = data.toString();
      image1 = null;
      image2 = null;
    });
  }

  Future<void> OcrProcces() async {
    setState(() {
      _result = "Pleasewait..";
    });
    Map? data = await OcrImageProcess()
        .processImage(frontImagePath, backImagePath, idType);

    setState(() {
      _result = data.toString();
      frontImagePath = null;
      backImagePath = null;
    });
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
                    child: new Text('Result: $_result',
                        style: const TextStyle(
                          letterSpacing: 0.5,
                          color: Colors.black54,
                          fontFamily: "Roboto",
                          fontWeight: FontWeight.w600,
                        ))))
          ],
        ),
      ),
    );
  }
}
