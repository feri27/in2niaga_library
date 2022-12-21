import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:in2niaga_library/src/constants/colors.dart';
import 'package:in2niaga_library/src/core/image_transformation_functions.dart';
import 'package:in2niaga_library/src/widgets/face_painter.dart';
import 'package:in2niaga_library/src/widgets/facebox_painter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imglib;

final Color textColor = Colors.white.withOpacity(0.4);

class FaceDetectionScreen extends ConsumerStatefulWidget {
  final String title;
  final List<CameraDescription> cameras;
  const FaceDetectionScreen({
    Key? key,
    required this.title,
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
  Face? faceDetected;
  Size? imageSize;

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
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            backgroundColor: kBlue,
            elevation: 0,
            title: Text(widget.title),
            centerTitle: true,
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
                if (faceFitted)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: size.height * 0.15,
                    child: CustomPaint(
                      painter: FacePainter(
                          face: faceDetected, imageSize: imageSize!),
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.topCenter,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    height: 35,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 8.0),
                              child: Text(
                                "Selfie",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontFamily: "Roboto",
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    height: constraints.maxHeight * 0.12,
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white.withOpacity(0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 25,
                            ),
                            if (proccess)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  // The loading indicator
                                  CircularProgressIndicator(
                                    backgroundColor: kBlue,
                                    // valueColor:
                                    //     AlwaysStoppedAnimation(Colors.blue),
                                  ),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  // Some text
                                  Text(
                                    'Pleasewait...',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontFamily: "Roboto",
                                      fontWeight: FontWeight.w400,
                                    ),
                                  )
                                ],
                              ),
                            if (!proccess)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 8.0),
                                child: Text(
                                  instruction,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.w400,
                                  ),
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

  getImageSize() {
    assert(controller.value.previewSize != null, 'Preview size is null');
    return Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
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
        faceDetected = face;

        final rotation = inputImage.inputImageData!.imageRotation;
        final absoluteImageSize = inputImage.inputImageData!.size;

        Size size = MediaQuery.of(context).size;

        final realWidthThreshold = size.width * 0.70;
        final marginWidth = size.width * 0.04;

        final realLeft = translateX(
            face.boundingBox.left, rotation, size, absoluteImageSize);
        final realRight = translateX(
            face.boundingBox.right, rotation, size, absoluteImageSize);

        final realWidth = realLeft - realRight;

        imageSize = getImageSize();

        log(imageSize.toString());

        if (realWidth > realWidthThreshold + marginWidth) {
          instruction = 'Please move backwards from the camera';
          faceFitted = false;
          count = 4;
          imageList.clear();
          setState(() {});
        } else if (realWidth < realWidthThreshold - marginWidth) {
          instruction = 'Please move forward to the camera';
          faceFitted = false;
          count = 4;
          imageList.clear();
          setState(() {});
        } else {
          faceFitted = true;

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

          imageList.add('"' + bs64 + '"');
          int counter = count - imageList.length;

          instruction = 'Hold Stil for ' + counter.toString() + '';

          if (imageList.length == 3) {
            await controller.stopImageStream();
            faceFitted = false;
            instruction = '';
            sendImageAPI();
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

  sendImageAPI() async {
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
      log(res);
      Navigator.pop(context, res);
    } else {
      log(response.reasonPhrase.toString());
      Navigator.pop(context, response.reasonPhrase.toString());
    }
  }
}
