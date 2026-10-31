// ===== SAVE AS:  C:\dev\artisan_app\lib\screens\camera_screen.dart =====
import 'dart:typed_data';
 
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
 
/// Opens the camera, takes one photo and returns its bytes
/// (Navigator.pop with a Uint8List). Returns null if the user goes back.
/// On a laptop in Chrome this uses the webcam; the browser asks for permission.
class CameraScreen extends StatefulWidget {
  final String title;
  final bool front;
 
  const CameraScreen({super.key, required this.title, this.front = true});
 
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}
 
class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  String? _error;
  bool _taking = false;
 
  @override
  void initState() {
    super.initState();
    _start();
  }
 
  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera was found on this device.');
        return;
      }
      final wanted = widget.front ? CameraLensDirection.front : CameraLensDirection.back;
      final chosen = cameras.firstWhere(
        (c) => c.lensDirection == wanted,
        orElse: () => cameras.first,
      );
      final controller = CameraController(chosen, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error =
            'Could not open the camera (${e.description ?? e.code}). '
            'Allow camera access for this page in the browser, then go back and try again.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the camera.');
    }
  }
 
  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _taking = false;
          _error = 'The photo could not be taken. Go back and try again.';
        });
      }
    }
  }
 
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : controller == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(child: Center(child: CameraPreview(controller))),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: _taking ? null : _capture,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_taking ? 'Please wait...' : 'Take photo'),
                      ),
                    ),
                  ],
                ),
    );
  }
}