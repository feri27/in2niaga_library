import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:in2niaga_library/src/constants/colors.dart';
import 'package:in2niaga_library/src/core/image_transformation_functions.dart';
import 'package:in2niaga_library/src/idcrop/inside_line_direction.dart';
import 'package:in2niaga_library/src/idcrop/inside_line_position.dart';
import 'package:in2niaga_library/src/widgets/card_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'border_type.dart';
import 'camera_description.dart';
import 'crop_image.dart';
import 'inside_line.dart';
import 'result.dart';
import 'package:image/image.dart' as imglib;

// ignore: must_be_immutable
class MaskForCameraView extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  final String type;
  final String? idType;
  final String title;

  const MaskForCameraView({
    required this.title,
    required this.cameras,
    required this.type,
    this.idType,
    Key? key,
  }) : super(key: key);

  @override
  _MaskForCameraViewState createState() => _MaskForCameraViewState();
}

class _MaskForCameraViewState extends ConsumerState<MaskForCameraView>
    with WidgetsBindingObserver {
  bool _isBusy = false;
  bool isRunning = false;
  bool passedCard = false;
  bool detecface = false;
  var instruction = '';
  final GlobalKey _stickyKey = GlobalKey();
  late CameraController _cameraController;
  late final List<CameraDescription> cameraDescription;
  late CameraLensDirection direction;
  late Directory tempDir;
  //face detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.1,
    ),
  );
  //parameter
  late double boxWidth;
  late double boxHeight;
  late double boxBorderWidth = 1.8;
  late double boxBorderRadius = 3.2;
  late bool visiblePopButton = true;
  double? _screenWidth;
  double? _screenHeight;
  double? _boxWidthForCrop;
  double? _boxHeightForCrop;
  MaskForCameraViewBorderType borderType = MaskForCameraViewBorderType.dotted;
  MaskForCameraViewInsideLine insideLine = MaskForCameraViewInsideLine(
    position: MaskForCameraViewInsideLinePosition.endPartThree,
    direction: MaskForCameraViewInsideLineDirection.horizontal,
  );
  double? ratio = 1.5;
  late Rect cardRect;
  int sharpnessScore = 0;
  int sharpnessThreshold = 1800;
  List<String> iteration = [];

  @override
  void initState() {
    _setupCamera();
    cardOption(widget.idType);
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    direction = widget.cameras[0].lensDirection;
    getApplicationDocumentsDirectory().then((value) {
      tempDir = value;
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint('app state changed');
      _cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  Future<void> _setupCamera() async {
    debugPrint('_setupCamera');
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
    );
    _cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _cameraController.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  void cardOption(String? ocrType) {
    setState(() {
      boxHeight = ocrType == "Passport"
          ? 210
          : ocrType == "Work Permit"
              ? 178.0
              : 187.0;
    });

    setState(() {
      boxWidth = ocrType == "Passport"
          ? 300.0
          : ocrType == "Work Permit"
              ? 285.0
              : 300;
    });

    if (widget.idType == 'Passport') {
      setState(() {
        cardRect = const Rect.fromLTRB(18, 180, 702, 680);
      });
    } else {
      setState(() {
        cardRect = const Rect.fromLTRB(18, 180, 702, 620);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _boxWidthForCrop = boxWidth;
    _boxHeightForCrop = boxHeight;

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
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                right: 0,
                child: !_cameraController.value.isInitialized
                    ? Container()
                    : Column(
                        children: [
                          Expanded(
                            child: Container(
                              key: _stickyKey,
                              color: kBlue,
                            ),
                          ),
                          CameraPreview(
                            _cameraController,
                          ),
                          Expanded(
                            child: Container(
                              color: kBlue,
                            ),
                          )
                        ],
                      ),
              ),
              Container(
                decoration: ShapeDecoration(
                  shape: CardScannerOverlayShape(
                      borderColor: passedCard ? Colors.green : Colors.white,
                      borderRadius: 12,
                      borderLength: 32,
                      borderWidth: 6,
                      aspecratio: ratio!),
                ),
              ),
              Positioned(
                top: 0.0,
                left: 0.0,
                right: 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  decoration: BoxDecoration(
                    color: kBlue,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                        height: 80,
                        child: Center(
                          child: Text(
                            'Place your document in the rectangle',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w200,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        )),
                  ),
                ),
              ),
              Positioned(
                top: 100,
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                    child: Column(
                  children: [
                    SizedBox(
                      height: 15,
                    ),
                    Text(
                      widget.type + ' side',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    )
                  ],
                )),
              ),
              if (detecface)
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(10),
                        foregroundColor: Colors.white,
                        backgroundColor: passedCard
                            ? Colors.green
                            : Color.fromARGB(202, 255, 255, 255),
                        textStyle: const TextStyle(fontSize: 20)),
                    onPressed: () {},
                    child: Text(
                      instruction,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: passedCard ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0.0,
                bottom: 0.0,
                left: 0.0,
                right: 0.0,
                child: Center(
                  child: DottedBorder(
                    borderType: BorderType.RRect,
                    strokeWidth:
                        borderType == MaskForCameraViewBorderType.dotted
                            ? boxBorderWidth
                            : 0.0,
                    color: passedCard ? Colors.green : Colors.white,
                    dashPattern: const [4, 3],
                    radius: Radius.circular(
                      boxBorderRadius,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isRunning ? Colors.white60 : Colors.transparent,
                        borderRadius: BorderRadius.circular(boxBorderRadius),
                      ),
                      child: Container(
                        width: borderType == MaskForCameraViewBorderType.solid
                            ? boxWidth + boxBorderWidth * 2
                            : boxWidth,
                        height: borderType == MaskForCameraViewBorderType.solid
                            ? boxHeight + boxBorderWidth * 2
                            : boxHeight,
                        decoration: BoxDecoration(
                          border: Border.all(
                            width:
                                borderType == MaskForCameraViewBorderType.solid
                                    ? boxBorderWidth
                                    : 0.0,
                            color:
                                borderType == MaskForCameraViewBorderType.solid
                                    ? Colors.white
                                    : Colors.transparent,
                          ),
                          borderRadius: BorderRadius.circular(
                            boxBorderRadius,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              child: _IsCropping(
                                isRunning: isRunning,
                                widget: widget,
                                boxWidth: boxWidth,
                                boxHeight: boxHeight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.bottomCenter,
                child: Container(
                  height: 90,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            // const SizedBox(
                            //   height: 10,
                            // ),
                            // RichText(
                            //   text: TextSpan(
                            //     text: "Align the ",
                            //     style: TextStyle(
                            //       fontSize: 14,
                            //       fontFamily: "Roboto",
                            //       fontWeight: FontWeight.w400,
                            //       color: kBlue,
                            //     ),
                            //     children: [
                            //       TextSpan(
                            //         text: widget.type.toUpperCase(),
                            //         style: TextStyle(
                            //             fontSize: 16,
                            //             fontStyle: FontStyle.normal,
                            //             fontFamily: "Roboto",
                            //             fontWeight: FontWeight.bold,
                            //             color: kBlue),
                            //       ),
                            //       const TextSpan(
                            //         text: " of your",
                            //         style: TextStyle(
                            //           fontSize: 14,
                            //           fontFamily: "Roboto",
                            //           fontWeight: FontWeight.w400,
                            //           color: kBlue,
                            //         ),
                            //       ),
                            //     ],
                            //   ),
                            // ),
                            // RichText(
                            //   text: TextSpan(
                            //     text: widget.idType! + " within the frame",
                            //     style: TextStyle(
                            //       fontSize: 14,
                            //       fontFamily: "Roboto",
                            //       fontWeight: FontWeight.w400,
                            //       color: kBlue,
                            //     ),
                            //   ),
                            // ),
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
                    ],
                  ),
                  // ],
                ),
              ),
            ],
          );
        }));
  }

  Future _processCameraImage(CameraImage image) async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;

    try {
      final camera = widget.cameras[0];

      Map<String, dynamic> p1 = {
        'sensorOrientation': camera.sensorOrientation,
        'image': image,
      };

      final inputImage = await compute(cameraToInputImage, p1);
      final faces = await _faceDetector.processImage(inputImage);

      if (inputImage.inputImageData?.size != null &&
          inputImage.inputImageData?.imageRotation != null &&
          faces.isNotEmpty) {
        Face face = faces[0];
        Size size = MediaQuery.of(context).size;

        setState(() {
          detecface = true;
        });

        //forward-backward
        final rotation = inputImage.inputImageData!.imageRotation;
        final absoluteImageSize = inputImage.inputImageData!.size;

        if (widget.type == 'Front') {
          final realWidthThreshold = size.width * 0.52;
          final marginWidth = size.width * 0.04;
          final realLeft = translateX(
              face.boundingBox.left, rotation, size, absoluteImageSize);
          final realRight = translateX(
              face.boundingBox.right, rotation, size, absoluteImageSize);
          final realWidth = realLeft + realRight;
          final backwardvalue = realWidthThreshold + marginWidth;
          final forwardvalue = realWidthThreshold - marginWidth;

          //ratio box
          final _ratio = realRight / realLeft;
          setState(() {
            ratio = _ratio;
          });

          print('ratio $ratio');

          if (realWidth > forwardvalue && realWidth < backwardvalue) {
            Map<String, dynamic> p = {
              'direction': direction,
              'image': image,
              'rect': cardRect,
              'square': false,
              'crop': false,
            };

            iteration.add('*');

            imglib.Image img = await compute(cropImage, p);
            List grayImg = await compute(grayImage, img);
            sharpnessScore = await compute(laplacian, grayImg);

            if (sharpnessScore < sharpnessThreshold && iteration.length > 5) {
              setState(() {
                instruction = 'More Light needed';
                passedCard = false;
              });
            } else if (sharpnessScore > sharpnessThreshold &&
                iteration.length > 5) {
              setState(() {
                instruction = 'Hold still...';
                passedCard = true;
              });
            } else {
              setState(() {
                instruction = 'More Light needed';
                passedCard = false;
              });
            }
          } else {
            setState(() {
              instruction = 'Center Document';
              passedCard = false;
              iteration.clear();
            });
          }
        } else if (widget.type == 'Back') {
          final realWidthThreshold = size.width * 0.50;
          final marginWidth = size.width * 0.03;
          final realLeft = translateX(
              face.boundingBox.left, rotation, size, absoluteImageSize);
          final realRight = translateX(
              face.boundingBox.right, rotation, size, absoluteImageSize);

          final realWidth = realRight + realLeft;
          final backwardvalue = realWidthThreshold + marginWidth;
          final forwardvalue = realWidthThreshold - marginWidth;

          final realWidthBack = realWidth - (backwardvalue + forwardvalue);

          //ratio box
          final _ratio = (realWidthBack / forwardvalue) + 0.5;
          setState(() {
            ratio = _ratio;
          });

          print('ratio $ratio');

          print('backward $backwardvalue');

          if (realWidthBack < backwardvalue && realWidthBack > forwardvalue) {
            Map<String, dynamic> p = {
              'direction': direction,
              'image': image,
              'rect': cardRect,
              'square': false,
              'crop': false,
            };

            iteration.add('*');

            imglib.Image img = await compute(cropImage, p);
            List grayImg = await compute(grayImage, img);
            sharpnessScore = await compute(laplacian, grayImg);

            if (sharpnessScore < sharpnessThreshold && iteration.length > 5) {
              setState(() {
                instruction = 'More Light needed';
                passedCard = false;
              });
            } else if (sharpnessScore > sharpnessThreshold &&
                iteration.length > 5) {
              setState(() {
                instruction = 'Hold still...';
                passedCard = true;
              });
            } else {
              setState(() {
                instruction = 'More Light needed';
                passedCard = false;
              });
            }
          } else {
            setState(() {
              instruction = 'Center Document';
              passedCard = false;
              iteration.clear();
            });
          }
        }
      } else {
        setState(() {
          instruction = 'Center Document';
          passedCard = false;
          iteration.clear();
        });
      }

      if (passedCard && detecface && iteration.length > 5) {
        await Future.delayed(const Duration(seconds: 2));
        await _cameraController.stopImageStream();
        await _takePicture(direction, image);
      }
      _isBusy = false;
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        instruction = 'Center Document';
        passedCard = false;
        detecface = false;
        iteration.clear();
      });
    }
  }

  Future<void> _takePicture(
    CameraLensDirection direction,
    CameraImage image,
  ) async {
    setState(() {
      isRunning = true;
    });

    Map<String, dynamic> params = {
      'direction': direction,
      'image': image,
    };

    imglib.Image cardImage = await compute(camera2Image, params);
    String cardImagePath =
        '${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}crop.jpg';
    await File(cardImagePath).writeAsBytes(imglib.encodeJpg(cardImage));

    RenderBox box = _stickyKey.currentContext!.findRenderObject() as RenderBox;
    double size = box.size.height * 3.4;
    String? card = widget.idType;
    MaskForCameraViewResult? result = await CropImage(
      card == 'Passport' ? 'Passport' : 'IdCard',
      cardImagePath,
      _boxHeightForCrop!.toInt(),
      _boxWidthForCrop!.toInt(),
      _screenHeight! - size,
      _screenWidth!,
      insideLine,
    );
    print(result!.thirdPartImage.toString());

    Navigator.pop(
        context, {'CARD': result.croppedImage, 'FACE': result.sixPartImage});
  }
}

class ImageDialog extends StatelessWidget {
  const ImageDialog(this.cardImagePath, {Key? key}) : super(key: key);

  final String cardImagePath;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 200,
        height: 200,
        child: Image.memory(
          File(cardImagePath).readAsBytesSync(),
          fit: BoxFit.cover,
          width: 130,
          height: 100,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton(this.icon, {Key? key, required this.color})
      : super(key: key);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          icon,
          color: color,
        ),
      ),
    );
  }
}

class _IsCropping extends StatelessWidget {
  const _IsCropping(
      {Key? key,
      required this.isRunning,
      required this.widget,
      required this.boxWidth,
      required this.boxHeight})
      : super(key: key);
  final bool isRunning;
  final MaskForCameraView widget;
  final double boxWidth;
  final double boxHeight;

  @override
  Widget build(BuildContext context) {
    return isRunning && boxWidth >= 50.0 && boxHeight >= 50.0
        ? const Center(
            child: CupertinoActivityIndicator(
              radius: 12.8,
            ),
          )
        : Container();
  }
}
