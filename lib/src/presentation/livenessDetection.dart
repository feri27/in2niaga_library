import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imglib;
import 'package:in2niaga_library/src/core/image_transformation_functions.dart';
import 'package:in2niaga_library/src/widgets/facebox_painter.dart';
import 'package:path_provider/path_provider.dart';

final Color textColor = Colors.white.withOpacity(0.4);

class FaceDetectionScreen extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;

  const FaceDetectionScreen({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends ConsumerState<FaceDetectionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late CameraController controller;
  String? imagePath;
  Uint8List? faceData;

  late CameraLensDirection direction;
  late Directory tempDir;
  bool faceFitted = false;
  bool proccess = false;
  String instruction = 'No face detected';
  bool _isBusy = false;
  bool showAlertLaggy = true;
  int index = 0;
  List<String> imageList = [];
  int count = 4;
  Color? borderColor = Colors.red;
  late String FmagePath;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true),
  );

  @override
  void initState() {
    getApplicationDocumentsDirectory().then((value) {
      tempDir = value;
    });

    direction = widget.cameras[widget.cameras.length - 1].lensDirection;
    _setupCamera();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Consumer(
      builder: (context, ref, child) {
        Size size = MediaQuery.of(context).size;

        var camera = controller.value;
        var scale = size.aspectRatio * camera.aspectRatio;
        if (scale < 1) scale = 1 / scale;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            toolbarHeight: 100,
            automaticallyImplyLeading: false,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Transform.scale(
                  scale: scale,
                  child: Center(
                    child: CameraPreview(controller),
                  ),
                ),

                //Add custom image overlay UI follow requirement
                CustomPaint(
                  painter: FaceboxPainter(borderColor!),
                  size: Size(
                    MediaQuery.of(context).size.width,
                    constraints.maxHeight * 0.75,
                  ),
                ),

                //Add instruction at top of overlay
                const Align(
                  alignment: AlignmentDirectional.topCenter,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.0, vertical: 20),
                    child: Text(
                      "Fit your face inside the frame until it turns green and hold for 2 seconds.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          fontFamily: "Roboto",
                          fontWeight: FontWeight.normal,
                          color: Colors.white),
                    ),
                  ),
                ),

                //Add UI and change background to black color follow requirement
                Align(
                  alignment: AlignmentDirectional.bottomCenter,
                  child: Container(
                    height: constraints.maxHeight * 0.25,
                    width: double.maxFinite,
                    color: Colors.black,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            proccess
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      // The loading indicator
                                      SizedBox(
                                        height: 15,
                                      ),
                                      CircularProgressIndicator(
                                          color: Colors.white),
                                      SizedBox(
                                        height: 15,
                                      ),
                                      // Some text
                                      Text(
                                        'Please wait...',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontFamily: "Roboto",
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white),
                                      )
                                    ],
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 50),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        //Add cancel bottom to cancel process
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text(
                                            "Cancel",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontFamily: "Roboto",
                                                fontWeight: FontWeight.normal,
                                                color: Colors.white),
                                          ),
                                        ),

                                        Text(
                                          instruction,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontFamily: "Roboto",
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white),
                                        ),
                                        const SizedBox(
                                          width: 60,
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint('app state changed');
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  Future<void> _setupCamera() async {
    controller = CameraController(
      widget.cameras[widget.cameras.length - 1],
      ResolutionPreset.high,
    );
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  Future<void> takePicture(
    CameraLensDirection direction,
    CameraImage image,
  ) async {
    Map<String, dynamic> params = {
      'direction': direction,
      'image': image,
    };

    imglib.Image cardImage = await compute(camera2Image, params);

    imglib.Image idImage = await compute(
        copyResize, {'input': cardImage, 'width': 1080, 'height': 1440});

    String cardImagePath =
        '${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    debugPrint("cardImagePath => $cardImagePath");
    await File(cardImagePath).writeAsBytes(imglib.encodeJpg(idImage));
    setState(() {
      FmagePath = cardImagePath;
    });
  }

  Future _processCameraImage(CameraImage image) async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;

    try {
      final camera = widget.cameras[1];

      Map<String, dynamic> p0 = {
        'sensorOrientation': camera.sensorOrientation,
        'image': image,
      };

      final inputImage = await compute(cameraToInputImage, p0);
      final faces = await _faceDetector.processImage(inputImage);

      if (inputImage.inputImageData?.size != null &&
          inputImage.inputImageData?.imageRotation != null &&
          faces.isNotEmpty) {
        Face face = faces[0];

        final rotation = inputImage.inputImageData!.imageRotation;
        final absoluteImageSize = inputImage.inputImageData!.size;

        Size size = MediaQuery.of(context).size;

        final realWidthThreshold = size.width * 0.70;
        final marginWidth = size.width * 0.05;

        final realLeft = translateX(
            face.boundingBox.left, rotation, size, absoluteImageSize);
        final realRight = translateX(
            face.boundingBox.right, rotation, size, absoluteImageSize);

        final realWidth = realLeft - realRight;

        final backwardvalue = realWidthThreshold + marginWidth;
        final forwardvalue = realWidthThreshold - marginWidth;

        if (realWidth > backwardvalue) {
          instruction = 'Please move backwards\nfrom the camera';
          faceFitted = false;
          count = 4;
          imageList.clear();
          setState(() {
            borderColor = Colors.red;
          });
        } else if (realWidth < forwardvalue) {
          instruction = 'Please move forward\nto the camera';
          faceFitted = false;
          count = 4;
          imageList.clear();
          setState(() {
            borderColor = Colors.red;
          });
        } else {
          faceFitted = true;
          borderColor = Colors.green;

          //start code
          Map<String, dynamic> pFace = {
            'direction': direction,
            'image': image,
            'rect': face.boundingBox,
            'crop': true,
          };

          imglib.Image cropFaceImage = await compute(cameraToImage, pFace);

          int dt = DateTime.now().microsecondsSinceEpoch;
          String faceImagePath = '${tempDir.path}/1-$dt.jpg';
          await File(faceImagePath)
              .writeAsBytes(imglib.encodeJpg(cropFaceImage));

          Uint8List imageFile = File(faceImagePath).readAsBytesSync();
          String bs64 = base64.encode(imageFile);

          imageList.add('"$bs64"');
          int counter = count - imageList.length;

          instruction = 'Hold Stil for $counter';

          if (imageList.length == 3) {
            await takePicture(direction, image);
            await controller.stopImageStream();
            faceFitted = false;
            instruction = '';
            sendImageAPI(faceImagePath);
          }

          //end code

        }

        index++;
      } else {
        instruction = 'No face detected';
        faceFitted = false;
      }

      _isBusy = false;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  //Add imagePath to get capture selfie image path
  sendImageAPI(String imagePath) async {
    //Please add catch error exception for error handler
    try {
      instruction = "";
      setState(() {
        proccess = true;
      });

      var headers = {'Content-Type': 'application/json'};
      var request = http.Request(
          'POST', Uri.parse('http://18.141.220.19:5051/spoof-imagesList'));

      request.body = json.encode({"Images": imageList});
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        String res = await response.stream.bytesToString();

        //Add Image path to pass to the main App
        Map toJson() => {
              'data': res,
              'path': FmagePath,
            };

        // ignore: use_build_context_synchronously
        Navigator.pop(context, jsonEncode(toJson()));
      } else {
        Map toJson() => {
              'data': response.reasonPhrase.toString(),
              'path': FmagePath,
            };
        // ignore: use_build_context_synchronously
        Navigator.pop(context, jsonEncode(toJson()));
      }
    } catch (e) {
      if (kDebugMode) {
        print('error $e');
      }
    }
  }
}
