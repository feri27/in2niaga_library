import 'dart:developer';

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
  String? result;

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
        result = results;
      });
    }
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
                    result = "Pleasewait..";
                  });
                  var res = await In2niaga().imageSharpness(value.path);

                  setState(() {
                    result = 'Sharpness: $res';
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
                    result = "Pleasewait..";
                  });

                  var res = await In2niaga().imageSharpness(value.path);

                  setState(() {
                    result = 'Sharpness: $res';
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
                height: 60.0,
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
                height: 60.0,
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
            const SizedBox(
              height: 30,
            ),
            SizedBox(
                height: 200,
                width: 200,
                child: Text('Result: $result',
                    style: const TextStyle(
                      letterSpacing: 0.5,
                      color: Colors.black54,
                      fontFamily: "Roboto",
                      fontWeight: FontWeight.w600,
                    )))
          ],
        ),
      ),
    );
  }
}
