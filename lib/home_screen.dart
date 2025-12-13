import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'face_detection/face_detection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Home"),
        actions: <Widget>[],
      ),
      body: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _onTapFaceDetection,
              child: Text("Face Detection"),
            ),
          ],
        ),
      ),
    );
  }

  _onTapFaceDetection() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FaceDetectionScreen(
          onComplete: () {
            debugPrint("callback is calling.......");
          },
        ),
      ),
    );
  }
}
