import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:ml_kit_sample_app/face_detection/painters/center_oval_overlay.dart';
import 'package:ml_kit_sample_app/face_detection/painters/face_detector_painter.dart';

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({
    super.key,
    this.initialCameraLensDirection = CameraLensDirection.front,
    this.onComplete,
  });

  final VoidCallback? onComplete;
  final CameraLensDirection initialCameraLensDirection;

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;

  int _cameraIndex = -1;

  bool _canProcess = true;
  bool _isBusy = false;
  String? _text;
  final _cameraLensDirection = CameraLensDirection.front;
  CustomPaint? _customPaint;

  bool isFaceValidated = false;
  String instructionText = "";

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableContours: true,
      enableLandmarks: true,
    ),
  );

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _liveFeedBody());
  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty) return Container();
    if (_controller == null) return Container();
    if (_controller?.value.isInitialized == false) return Container();
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(child: CameraPreview(_controller!, child: _customPaint)),
          CenterOvalOverlay(isActive: isFaceValidated),
          _bottomOptionsWidget(context),
          _backButton(),
        ],
      ),
    );
  }

  Widget _backButton() => Positioned(
    top: 40,
    left: 8,
    child: SizedBox(
      height: 50.0,
      width: 50.0,
      child: FloatingActionButton(
        heroTag: Object(),
        onPressed: () => Navigator.of(context).pop(),
        backgroundColor: Colors.black54,
        child: Icon(Icons.arrow_back_ios_outlined, size: 20),
      ),
    ),
  );

  Widget _bottomOptionsWidget(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final ovalHeight = size.height * 0.5;

    return Positioned(
      top: (size.height / 2) + (ovalHeight / 2) + 16,
      left: 24,
      right: 24,
      child: Column(
        children: [
          Text(
            instructionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }

      _controller?.startImageStream(_processCameraImage).then((value) {});
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    _processImage(inputImage);
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final faces = await _faceDetector.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = FaceDetectorPainter(
        faces,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: painter);

      //===================
      //handle the liveness cheecks here

      if (faces.length == 1) {
        // await _controller?.pausePreview();
        //Blink detection

        bool isFaceFitToOval = _detectFaceScreenLocation(
          faces.first,
          inputImage.metadata!,
        );

        if (isFaceFitToOval) {
          bool isBlinkDetected = blinkDetection(faces.first);

          if (isBlinkDetected) {
            _controller?.stopImageStream();

            setState(() {
              instructionText = 'Capturing...';
            });
            widget.onComplete!();
          }
        }

        // if (isBlinkDetected) {
        //   widget.onComplete!();
        //   // _controller?.pausePreview();
        // }
      }

      //===================
    } else {
      String text = 'Faces found: ${faces.length}\n\n';
      for (final face in faces) {
        text += 'face: ${face.boundingBox}\n\n';
      }
      _text = text;
      // TODO: set _customPaint to draw boundingRect on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  // bool blinkDetection(Face face) {
  //   if (face.leftEyeOpenProbability! < 0.4 ||
  //       face.rightEyeOpenProbability! < 0.4) {
  //     debugPrint("Blinking....");
  //     return true;
  //   } else {
  //     debugPrint("not Blinking");
  //     return false;
  //   }
  // }
  // bool blinkDetection(Face face) {
  //   final leftEye = face.leftEyeOpenProbability;
  //   final rightEye = face.rightEyeOpenProbability;
  //
  //   if (leftEye == null || rightEye == null) {
  //     debugPrint('Blink: eye probability not available');
  //     return false;
  //   }
  //
  //   if (leftEye < 0.4 || rightEye < 0.4) {
  //     debugPrint('Blinking.... L:$leftEye R:$rightEye');
  //
  //     return true;
  //   } else {
  //     debugPrint('Not blinking.... L:$leftEye R:$rightEye');
  //     return false;
  //   }
  // }

  bool blinkDetection(Face face) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if (leftEye == null || rightEye == null) {
      debugPrint('Blink: eye probability not available');
      return false;
    }

    if (leftEye < 0.4 || rightEye < 0.4) {
      debugPrint('Blinking.... L:$leftEye R:$rightEye');

      return true;
    }

    return false;
  }

  Rect _translateRect(
    Rect boundingBox,
    Size imageSize,
    Size screenSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
  ) {
    double scaleX, scaleY;

    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      scaleX = screenSize.width / imageSize.height;
      scaleY = screenSize.height / imageSize.width;
    } else {
      scaleX = screenSize.width / imageSize.width;
      scaleY = screenSize.height / imageSize.height;
    }

    double left = boundingBox.left * scaleX;
    double top = boundingBox.top * scaleY;
    double right = boundingBox.right * scaleX;
    double bottom = boundingBox.bottom * scaleY;

    // Mirror for front camera
    if (cameraLensDirection == CameraLensDirection.front) {
      left = screenSize.width - right;
      right = screenSize.width - boundingBox.left * scaleX;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _detectFaceScreenLocation(Face face, InputImageMetadata metadata) {
    final screenSize = MediaQuery.of(context).size;

    final faceRect = _translateRect(
      face.boundingBox,
      metadata.size,
      screenSize,
      metadata.rotation!,
      _cameraLensDirection,
    );

    final faceCenter = faceRect.center;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);

    const tolerance = 60.0; // pixels

    final dx = faceCenter.dx - screenCenter.dx;
    final dy = faceCenter.dy - screenCenter.dy;

    if (dx.abs() < tolerance && dy.abs() < tolerance) {
      debugPrint('FACE POSITION: CENTER');
      setState(() {
        instructionText = 'Blink';
        isFaceValidated = true;
      });
      return true;
    }

    setState(() {
      if (dy < -tolerance) {
        debugPrint('FACE POSITION: TOP');

        instructionText = 'Move your face slightly down.';
      } else if (dy > tolerance) {
        debugPrint('FACE POSITION: BOTTOM');

        instructionText = 'Move your face slightly up.';
      } else if (dx < -tolerance) {
        debugPrint('FACE POSITION: LEFT');

        instructionText = 'Move your face slightly to the right.';
      } else if (dx > tolerance) {
        debugPrint('FACE POSITION: RIGHT');

        instructionText = 'Move your face slightly to the left.';
      }
      isFaceValidated = false;
    });

    return false;
  }

  // bool _analyzeFacePosition(Face face) {
  //   final angleY = face.headEulerAngleY;
  //
  //   if (angleY != null) {
  //     if (angleY > 15) {
  //       debugPrint('analyzeFacePosition: Turned Right');
  //       setState(() {
  //         instructionText = 'Turned Right';
  //       });
  //       return false;
  //     } else if (angleY < -15) {
  //       debugPrint('analyzeFacePosition: Turned Left');
  //       setState(() {
  //         instructionText = 'Turned Left';
  //       });
  //       return false;
  //     } else {
  //       debugPrint('analyzeFacePosition: Centered');
  //       setState(() {
  //         instructionText = 'Centered';
  //       });
  //       return true;
  //     }
  //   } else {
  //     return false;
  //   }
  // }
}
