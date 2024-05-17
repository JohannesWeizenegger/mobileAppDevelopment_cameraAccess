import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras =
  await availableCameras(); //return Future<List<CameraDescription>>
  final firstCamera = cameras.first;
  runApp(MaterialApp(
      home: TakePictureScreen(camera: firstCamera, availableCameras: cameras)));
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
    required this.availableCameras,
  });

  final CameraDescription camera;
  final List<CameraDescription> availableCameras;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

enum FlashState { off, on, auto }

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  int _selectedCameraIndex = 0; // Index of current Camera
  FlashState _flashState = FlashState.off; //Flash state

  double _currentZoomLevel = 1.0; // Current zoom level
  double _maxZoomLevel = 1.0; // Maximaler Zoom, wird später festgelegt

  @override
  void initState() {
    super.initState();
    _initializeCamera(widget.camera);
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize().then((_) {
      _maxZoomLevel = 1.0;
      if (_maxZoomLevel < 1.0) _maxZoomLevel = 1.0;
    });
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _onSwitchCamera() {
    _selectedCameraIndex++;
    if (_selectedCameraIndex >= widget.availableCameras.length) {
      _selectedCameraIndex = 0;
    }
    _controller.dispose();
    _initializeCamera(widget.availableCameras[_selectedCameraIndex]);
  }

  void _toggleFlash() {
    setState(() {
      switch (_flashState) {
        case FlashState.off:
          _flashState = FlashState.on;
          // Oder FlashMode.always für Foto-Blitz
          break;
        case FlashState.on:
          _flashState = FlashState.auto;
          _controller.setFlashMode(FlashMode.auto);
          break;
        case FlashState.auto:
          _flashState = FlashState.off;
          _controller.setFlashMode(FlashMode.off);
          break;
      }
    });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  Future<void> _setZoomLevel(double zoom) async {
    if (_controller.value.isInitialized) {
      print(zoom);
      await _controller.setZoomLevel(zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // AppBar transparent
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CameraPreview(_controller),
                ),
                Positioned(
                  bottom: 0.0,
                  left: 0.0,
                  right: 0.0,
                  child: _captureControlRowWidget(),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _captureControlRowWidget() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      color: Colors.black.withOpacity(0.7),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceEvenly, // Gleichmäßige Verteilung
        children: <Widget>[
          FloatingActionButton(
            onPressed: _onCapturePressed,
            child: const Icon(Icons.camera_alt),
          ),
          FloatingActionButton(
            onPressed: () => {
              _setZoomLevel(_currentZoomLevel - 0.1),
              _currentZoomLevel = _currentZoomLevel - 0.1,
            },
            child: const Icon(Icons.zoom_out),
          ),
          FloatingActionButton(
              onPressed: () => {
                _toggleFlash(),
              },
              child: Icon(_getFlashIcon())),
          FloatingActionButton(
            onPressed: () => {
              _setZoomLevel(_currentZoomLevel + 0.1),
              _currentZoomLevel = _currentZoomLevel + 0.1,
            },
            child: const Icon(Icons.zoom_in),
          ),
          FloatingActionButton(
            onPressed: _onSwitchCamera, // Wechsel-Methode anbinden
            child: const Icon(Icons.switch_camera),
          ),
        ],
      ),
    );
  }

  void _onCapturePressed() async {
    try {
      // Stellen Sie sicher, dass die Kamera initialisiert ist
      await _initializeControllerFuture;

      // Versuchen Sie, ein Bild aufzunehmen und dann die Position zu erhalten,
      // wo die Bilddatei gespeichert ist.
      if (_flashState == FlashState.on) {
        _controller.setFlashMode(FlashMode.torch);
      }
      final image = await _controller.takePicture();
      if (_flashState == FlashState.on) {
        _controller.setFlashMode(FlashMode.off);
      }

      // Find temp Directory
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // New File
      final File newImage = File(filePath);
      await newImage.writeAsBytes(await image.readAsBytes());

      // Das Bild in der Galerie speichern
      GallerySaver.saveImage(newImage.path).then((bool? success) {
        if (success == true) {
          print('Bild wurde erfolgreich an${image.path}gespeichert!');
        } else {
          print('Fehler beim Speichern des Bildes.');
        }
      });
    } catch (e) {
      print(e);
    }
  }

  IconData _getFlashIcon() {
    switch (_flashState) {
      case FlashState.off:
        return Icons.flash_off;
      case FlashState.on:
        return Icons.flash_on;
      case FlashState.auto:
        return Icons.flash_auto;
      default:
        return Icons.flash_off;
    }
  }
}
