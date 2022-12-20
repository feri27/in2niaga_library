# IN2NIAGA PACKAGE

## Sample
available in the examples folder

## Installation pub
```pub
in2niaga_library:
    path: "in2niaga_library"
```
## Import on project

```dart
import 'package:in2niaga_library/in2niaga_library.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```
## Call and get results Liveness

```dart
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

```


## dependency on the in2niaga package

```pub

  google_mlkit_face_detection: ^0.5.0
  image: ^3.2.2
  camera: ^0.10.0+5
  dio: ^4.0.6
  flutter_riverpod: ^2.1.1
  path_provider: ^2.0.11
  tflite_flutter:
    path: "tflite_flutter"
  http: ^0.13.5

```
The tflite_flutter package is required to process images and calculate thresholds and sharpness, and create grayscale


## License
[In2niaga]