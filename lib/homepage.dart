import 'package:camera/camera.dart';
import 'package:downgradeface/Utils/FaceDetectorPainter.dart';
import 'package:downgradeface/Utils/UtilsScanner.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<CameraImage?> _imageNotifier = ValueNotifier(null);
  CameraController? _cameraController;
  late CameraDescription _cameraDescription;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.back;
  FaceDetector? _faceDetector;
  bool _isWorking = false;
  List<Face> _facesList = [];
  void _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraDescription = cameras[0];
    _cameraController = CameraController(
      _cameraDescription,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _faceDetector = FirebaseVision.instance.faceDetector(
      FaceDetectorOptions(
        enableClassification: true,
        minFaceSize: 0.1,
        mode: FaceDetectorMode.fast,
      ),
    );
    try {
      await _cameraController!.initialize();
    } catch (e) {
      print('Error initializing camera: $e');
    }
    if (!mounted) {
      return;
    }
    _cameraController!.startImageStream((imageFromStream) {
      if (!_isWorking) {
        _isWorking = true;
        // implement FaceDetection
        performDetectionOnStreamFrame(imageFromStream);
      }
    });
    setState(() {});
  }

  void performDetectionOnStreamFrame(CameraImage? imageFromStream) async {
    if (imageFromStream == null || _faceDetector == null) return;
    final FirebaseVisionImageMetadata metadata = FirebaseVisionImageMetadata(
      rawFormat: imageFromStream.format.raw,
      size: Size(
        imageFromStream.width.toDouble(),
        imageFromStream.height.toDouble(),
      ),
      rotation: ImageRotation.rotation90,
    );
    final FirebaseVisionImage visionImage = FirebaseVisionImage.fromBytes(
      imageFromStream.planes[0].bytes,
      metadata,
    );
    try {
      List<Face> faces = await _faceDetector!.processImage(visionImage);
      setState(() {
        _facesList = faces;
      });
    } catch (e) {
      print('Error detecting faces: $e');
    }
    _isWorking = false;
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    super.dispose();
    _cameraController?.dispose();
    _faceDetector?.close();
    _imageNotifier.dispose();
  }

  void toggleCamera() async {
    if (_cameraLensDirection == CameraLensDirection.front) {
      _cameraLensDirection = CameraLensDirection.back;
    } else {
      _cameraLensDirection = CameraLensDirection.front;
    }
    await _cameraController!.stopImageStream();
    await _cameraController!.dispose();
    final cameras = await availableCameras();
    _cameraDescription = cameras.firstWhere(
      (camera) => camera.lensDirection == _cameraLensDirection,
    );
    _cameraController = CameraController(
      _cameraDescription,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await _cameraController!.initialize();
    } catch (e) {
      print('Error initializing camera: $e');
    }
    _cameraController!.startImageStream((imageFromStream) {
      if (!_isWorking) {
        _isWorking = true;
        // implement FaceDetection
        performDetectionOnStreamFrame(imageFromStream);
      }
    });
    setState(() {});
  }

  Widget buildResult() {
    if (_imageNotifier.value == null ||
        !_cameraController!.value.isInitialized) {
      return Container();
    }
    final Size imageSize = Size(
      _cameraController!.value.previewSize!.height,
      _cameraController!.value.previewSize!.width,
    );
    // customPainter
    CustomPainter customPainter = FaceDetectorPainter(
      imageSize,
      _imageNotifier.value! as List<Face>,
      _cameraLensDirection,
    );
    return CustomPaint(
      painter: customPainter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    List<Widget> stackWidgetChildren = [];
    // ... Other widget code ...
    stackWidgetChildren.add(
      Positioned(
        top: 30,
        left: 0.0,
        width: size.width,
        height: size.height - 250,
        child: _facesList.isEmpty
            ? Container(
                color: Colors.amber,
              )
            : CustomPaint(
                painter: FaceDetectorPainter(
                  Size(
                    _cameraController!.value.previewSize!.height,
                    _cameraController!.value.previewSize!.width,
                  ),
                  _facesList,
                  _cameraLensDirection,
                ),
              ),
      ),
    );
    return Scaffold(
      body: ValueListenableBuilder<CameraImage?>(
        valueListenable: _imageNotifier,
        builder: (context, value, _) {
          final List<Widget> stackWidgetChildren = [];
          final size = MediaQuery.of(context).size;
          // add streaming camera
          if (_cameraController != null) {
            stackWidgetChildren.add(
              Positioned(
                top: 30,
                left: 0,
                width: size.width,
                height: size.height - 250,
                child: Container(
                  child: (_cameraController!.value.isInitialized)
                      ? AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: RepaintBoundary(
                            child: CameraPreview(_cameraController!),
                          ),
                        )
                      : Container(),
                ),
              ),
            );
          }
          // toggle camera
          stackWidgetChildren.add(
            Positioned(
              top: size.height - 250,
              left: 0,
              width: size.width,
              height: 250,
              child: Container(
                margin: EdgeInsets.only(bottom: 80),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.switch_camera,
                        color: Colors.white,
                      ),
                      iconSize: 50,
                      color: Colors.black,
                      onPressed: () {
                        toggleCamera();
                      },
                    )
                  ],
                ),
              ),
            ),
          );
          stackWidgetChildren.add(
            Positioned(
              top: 30,
              left: 0.0,
              width: size.width,
              height: size.height - 250,
              child: buildResult(),
            ),
          );
          return Container(
            margin: EdgeInsets.only(top: 0),
            color: Colors.black,
            child: Stack(
              children: stackWidgetChildren,
            ),
          );
        },
      ),
    );
  }
}
