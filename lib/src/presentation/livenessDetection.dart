import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';
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
//import 'package:step_progress_indicator/step_progress_indicator.dart';

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
  CustomPaint? customPaint;
  late CameraLensDirection direction;
  late Directory tempDir;
  bool faceFitted = false;
  bool centerHead = false;
  bool proccess = false;
  String instruction = 'No face detected';
  bool _isBusy = false;
  bool showAlertLaggy = true;
  int index = 0;
  List<String> imageList = [];
  int count = 4;
  Color? borderColor = Colors.red;
  late String FmagePath;
  late Animation<double> currentStepAnimation;
  double currentStep = 0;
  late AnimationController animationController;

  //constrait

  late BoxConstraints cnstrt;

  //smile
  double smilingProbability = -1;
  double smilingProbabilityThreshold = 0.6;
  //blink
  double rightEyeOpenProbability = -1;
  double leftEyeOpenProbability = -1;
  double blinkProbabilityThreshold = 0.1;

  bool processSmile = true;
  bool processBlink = true;
  bool processCapture = true;
  bool processDistance = true;
  bool processPassive = true;

  //countdown
  int countdown = 3;
  bool showCountdown = false;
  int countdownStart = 0;

  //image
  imglib.Image faceLivenessImg = imglib.Image(0, 0);
  imglib.Image faceSmileImg = imglib.Image(0, 0);
  imglib.Image faceBlinkImg = imglib.Image(0, 0);
  imglib.Image faceFinalImg = imglib.Image(0, 0);

  //timer
  late Timer _timer;

  //Frame
  final GlobalKey key1 = GlobalKey();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true),
  );

  @override
  void initState() {
    getApplicationDocumentsDirectory().then((value) {
      tempDir = value;
    });

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 500,
      ),
    );
    currentStepAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(
        CurvedAnimation(parent: animationController, curve: Curves.easeInOut))
      ..addListener(() {
        setState(() {});
      });

    animationController.forward();

    direction = widget.cameras[widget.cameras.length - 1].lensDirection;
    _setupCamera();

    super.initState();
  }

  void setProgress(double begin, double end) {
    animationController.reset();
    setState(() {
      currentStep = end;
    });
    currentStepAnimation = Tween<double>(
      begin: begin < 0 ? 0 : begin,
      end: end < 0 ? 0 : end,
    ).animate(
        CurvedAnimation(parent: animationController, curve: Curves.easeInOut))
      ..addListener(() {
        setState(() {});
      });

    animationController.forward();
  }

  void startTimer() {
    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) {
        if (countdown == 0) {
          setState(() {
            timer.cancel();
          });
        } else {
          setState(() {
            countdown--;
          });
        }
      },
    );
  }

  void test() {}

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
                  key: key1,
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

  bool between(x, min, max) {
    return x >= min && x <= max;
  }

  _getPositions() {}

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

        Map<String, dynamic> pFace = {
          'direction': direction,
          'image': image,
        };

        Size? Frame = key1.currentContext!.size;

        var FrameData = Offset(size.width * 0.5, size.height * 0.5 - 10);

        var frame_left = Frame!.centerLeft(FrameData).dx;
        var frame_right = Frame.centerRight(FrameData).dx;
        var frame_top = Frame.topCenter(FrameData).dx;
        var frame_btm = Frame.bottomCenter(FrameData).dx;

        //log('frame_left: $frame_left frame_right: $frame_right frame_top: $frame_top frame_btm: $frame_btm');

        var FaceBoundingBox = face.boundingBox;

        var left = FaceBoundingBox.left;
        var right = FaceBoundingBox.right;
        var top = FaceBoundingBox.top;
        var btm = FaceBoundingBox.bottom;

        //log(size.height.toString());

        //log('left : $left right : $right top : $top btm : $btm');

        if (realWidth > backwardvalue) {
          if (processPassive == true) {
            setState(() {
              instruction = 'Please move backwards\nfrom the camera';
              borderColor = Colors.red;

              faceFitted = false;
            });
          }
        } else if (realWidth < forwardvalue) {
          if (processPassive == true) {
            setState(() {
              instruction = 'Please move forward\nto the camera';
              borderColor = Colors.red;

              faceFitted = false;
            });
          }
        } else {
          setState(() {
            faceFitted = true;
          });

          if (left > frame_left ||
              right < frame_right ||
              top > frame_top ||
              btm < frame_btm) {
            setState(() {
              borderColor = Colors.red;
              centerHead = false;
              instruction = 'Fit your face inside the frame!';
            });
          } else {
            setState(() {
              borderColor = Colors.green;
              centerHead = true;
            });

            if (processBlink == true &&
                processSmile == true &&
                processPassive == true &&
                centerHead == true) {
              faceLivenessImg = await compute(camera2Image, pFace);

              setProgress(
                currentStep,
                90,
              );
              setState(() {
                processPassive = false;
                instruction = 'Please blink!';
              });
            }
          }
        }

        if (currentStep == 90 && centerHead == true && faceFitted == true) {
          setState(() {
            instruction = 'Please blink!';
          });
        } else if (currentStep == 180 &&
            centerHead == true &&
            faceFitted == true) {
          setState(() {
            instruction = 'Please smile!';
          });
        }

        if (currentStep == 90 &&
            processBlink == true &&
            centerHead == true &&
            faceFitted == true) {
          leftEyeOpenProbability = face.leftEyeOpenProbability ?? 0;
          rightEyeOpenProbability = face.rightEyeOpenProbability ?? 0;

          if (leftEyeOpenProbability < blinkProbabilityThreshold ||
              rightEyeOpenProbability < blinkProbabilityThreshold) {
            faceBlinkImg = await compute(camera2Image, pFace);
            setProgress(
              currentStep,
              180,
            );
            setState(() {
              processBlink = false;
              instruction = 'Please smile!';
            });
          }
        }

        if (currentStep == 180 &&
            processSmile == true &&
            centerHead == true &&
            faceFitted == true) {
          smilingProbability =
              face.smilingProbability ?? smilingProbabilityThreshold + 1;
          if (smilingProbability > smilingProbabilityThreshold) {
            faceSmileImg = await compute(camera2Image, pFace);
            setProgress(
              currentStep,
              270,
            );
            setState(() {
              processSmile = false;
              instruction = '';
            });
          }
        }

        if (currentStep == 270 &&
            processCapture == true &&
            centerHead == true) {
          if (countdown == 0) {
            setProgress(
              currentStep,
              360,
            );
            setState(() {
              processCapture = false;
              instruction = 'Taking selfie!';
            });
            await takePicture(direction, image);
          } else {
            setState(() {
              showCountdown = true;
              instruction = 'Taking selfie!';
            });

            startTimer();
          }
        }

        if (currentStep == 360 && processCapture == false) {
          setState(() {
            proccess = true;
            instruction = '';
          });

          int dt = DateTime.now().microsecondsSinceEpoch;
          //noexpesion

          imglib.Image livenessimg = await compute(copyResize, {
            'input': faceLivenessImg,
            // 'width': 480,
            // 'height': 820,
          });

          String faceImagePathLiveness = '${tempDir.path}/noex-$dt.jpg';
          await File(faceImagePathLiveness)
              .writeAsBytes(imglib.encodeJpg(livenessimg));
          Uint8List imageFileLiveness =
              File(faceImagePathLiveness).readAsBytesSync();
          String bs64Liveness = base64.encode(imageFileLiveness);
          imageList.add(bs64Liveness);

          //blink
          imglib.Image blink = await compute(copyResize, {
            'input': faceBlinkImg,
            // 'width': 480,
            // 'height': 640,
          });
          String faceImagePathBlink = '${tempDir.path}/blink-$dt.jpg';
          await File(faceImagePathBlink).writeAsBytes(imglib.encodeJpg(blink));
          Uint8List imageFileBlink = File(faceImagePathBlink).readAsBytesSync();
          String bs64Blink = base64.encode(imageFileBlink);
          imageList.add(bs64Blink);

          //smile
          imglib.Image smile = await compute(copyResize, {
            'input': faceSmileImg,
            // 'width': 480,
            // 'height': 640,
          });
          String faceImagePathSmile = '${tempDir.path}/smile-$dt.jpg';
          await File(faceImagePathSmile).writeAsBytes(imglib.encodeJpg(smile));
          Uint8List imageFileSmile = File(faceImagePathSmile).readAsBytesSync();
          String bs64Smile = base64.encode(imageFileSmile);
          imageList.add(bs64Smile);

          if (imageList.length == 3) {
            await controller.stopImageStream();
            faceFitted = false;
            instruction = '';
            sendImageAPI();
          }
        }

        index++;
      } else {
        instruction = 'No face detected';
        countdown = 3;
        faceFitted = false;
        borderColor = Colors.red;
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
  sendImageAPI() async {
    //Please add catch error exception for error handler
    try {
      var headers = {'Content-Type': 'application/json'};
      var request = http.Request(
          'POST', Uri.parse('https://api.iqstars.me/In2Niaga/Antispoof.aspx'));
      request.body = json.encode({"Images": imageList});
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();

      //log(imageList.toString());
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

        print(toJson());
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
