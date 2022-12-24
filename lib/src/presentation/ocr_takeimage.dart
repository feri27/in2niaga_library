// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:in2niaga_library/src/constants/colors.dart';
import 'package:in2niaga_library/src/core/image_transformation_functions.dart';
import 'package:in2niaga_library/src/tflite/face_anti_spoofing.dart';
import 'package:in2niaga_library/src/widgets/card_painter.dart';
import 'package:path_provider/path_provider.dart';

class OcrPageCapture extends ConsumerStatefulWidget {
  final List<CameraDescription>? cameras;
  final String type;
  final String? idType;
  final String title;
  const OcrPageCapture({
    required this.title,
    this.cameras,
    required this.type,
    this.idType,
    Key? key,
  }) : super(key: key);

  @override
  _OcrPageState createState() => _OcrPageState();
}

class _OcrPageState extends ConsumerState<OcrPageCapture>
    with WidgetsBindingObserver {
  late CameraController controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.1,
    ),
  );

  late CameraLensDirection direction;
  CustomPaint? customPaint;
  CustomPaint? customPaintCard;
  bool _isBusy = false;
  bool _startRecognition = true;
  bool _startTakePicture = false;

  Rect faceRect = Rect.zero;
  Rect cardRect = const Rect.fromLTRB(18, 180, 702, 620);
  late Directory tempDir;
  bool passedCard = false;
  int sharpnessScore = 0;
  int sharpnessThreshold = FaceAntiSpoofing.laplacianThreshold;
  bool showSharpnessScore = false;
  bool showFocusCircle = false;
  bool loading = false;
  double x = 0;
  double y = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    direction = widget.cameras![0].lensDirection;

    getApplicationDocumentsDirectory().then((value) {
      tempDir = value;
    });

    _setupCamera();
  }

  @override
  void dispose() {
    controller.dispose();
    _faceDetector.close();
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
    debugPrint('_setupCamera');
    controller = CameraController(
      widget.cameras![0],
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

  Future<void> cameraFocus(TapUpDetails details) async {
    if (controller.value.isInitialized) {
      setState(() {
        showFocusCircle = true;
      });
      x = details.localPosition.dx;
      y = details.localPosition.dy;

      double fullWidth = MediaQuery.of(context).size.width;
      double cameraHeight = fullWidth * controller.value.aspectRatio;

      double xp = x / fullWidth;
      double yp = y / cameraHeight;

      Offset point = Offset(xp, yp);
      await controller.setFocusPoint(point);
      setState(() {
        Future.delayed(const Duration(seconds: 2)).whenComplete(() {
          setState(() {
            showFocusCircle = false;
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          // mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: CameraPreview(controller),
            ),
            showFocusCircle
                ? Positioned(
                    top: y - 20,
                    left: x - 20,
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5)),
                    ),
                  )
                : const SizedBox(),
            customPaint ?? const SizedBox(),
            CustomPaint(
              painter: CardPainter(
                cardRect,
                passedCard,
                const Size(720, 1280),
                InputImageRotation.rotation0deg,
              ),
              size: MediaQuery.of(context).size,
            ),
            Positioned(
              top: 0,
              left: 0,
              width: constraints.maxWidth,
              height: constraints.maxHeight - 250,
              child: GestureDetector(
                onTapUp: (details) {
                  cameraFocus(details);
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            // const OverlayWithRectangleClipping(),
            Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: Container(
                height: 250,
                width: double.maxFinite,
                color: Colors.white,
                // children: [

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 40),
                      child: Column(
                        children: [
                          const Text(
                            'Tap to Focus',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          RichText(
                            text: TextSpan(
                              text: "Align the ",
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: "Roboto",
                                fontWeight: FontWeight.w400,
                                color: kBlue,
                              ),
                              children: [
                                TextSpan(
                                  text: widget.type.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.normal,
                                      fontFamily: "Roboto",
                                      fontWeight: FontWeight.bold,
                                      color: kBlue),
                                ),
                                const TextSpan(
                                  text: " of your",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.w400,
                                    color: kBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              text: widget.idType! + " within the frame",
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: "Roboto",
                                fontWeight: FontWeight.w400,
                                color: kBlue,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          RichText(
                            text: TextSpan(
                              text: "Make sure your ",
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: Colors.black,
                                fontStyle: FontStyle.italic,
                              ),
                              children: [
                                TextSpan(
                                  text: widget.idType,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: kBlue,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const TextSpan(
                                  text: " details",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                    color: Colors.black,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: const TextSpan(
                              text: "are clear to read with no blur or glare",
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: Colors.black,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          const Text(
                            'Powered By In2Niaga',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kBlue,
                          minimumSize: const Size.fromHeight(50)),
                      onPressed: _onPressed,
                      child: const Text(
                        'Capture',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // ],
              ),
            ),
            loading
                ? Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black.withOpacity(0.8),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox(),
            // if (showSharpnessScore)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sharpness score : ' + sharpnessScore.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Sharpness threshold > ' + sharpnessThreshold.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _onPressed() async {
    _startTakePicture = true;
  }

  Future<void> _takePicture(
    CameraLensDirection direction,
    CameraImage image,
  ) async {
    Map<String, dynamic> params = {
      'direction': direction,
      'image': image,
      'rect': cardRect,
      'crop': false,
    };

    imglib.Image cardImage = await compute(cameraToImage, params);

    imglib.Image idImage = await compute(
        copyResize, {'input': cardImage, 'width': 640, 'height': 480});

    String cardImagePath =
        '${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    debugPrint("cardImagePath => $cardImagePath");
    await File(cardImagePath).writeAsBytes(imglib.encodeJpg(idImage));

    Navigator.pop(context, cardImagePath);
  }

  Future _processCameraImage(CameraImage image) async {
    if (!_startRecognition) {
      return;
    }
    if (_isBusy) {
      return;
    }
    _isBusy = true;

    Map<String, dynamic> p1 = {
      'direction': direction,
      'image': image,
      'rect': cardRect,
      'square': false,
      'crop': false,
    };

    imglib.Image img = await compute(cropImage, p1);

    List grayImg = await compute(grayImage, img);

    sharpnessScore = await compute(laplacian, grayImg);
    // sharpnessScore = await laplacian(grayImg);
    print('laplace');
    print(sharpnessScore);

    if (sharpnessScore > sharpnessThreshold && _startTakePicture) {
      _startRecognition = false;
      if (mounted) {
        setState(() {
          loading = true;
        });
      }
      await controller.pausePreview();
      await _takePicture(direction, image);
    }

    if (mounted) setState(() {});

    _isBusy = false;
  }
}
