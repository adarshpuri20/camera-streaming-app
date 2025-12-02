import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:livekit_client/livekit_client.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Camera Streaming App',
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;

  Room? _room;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    
    controller = CameraController(cameras[0], ResolutionPreset.high);
    try {
      await controller!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _startStreaming() async {
    // TEMP: still hard-coded until backend is ready
    const url = 'wss://livekit.mayacam.link';
    const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2aWRlbyI6eyJyb29tSm9pbiI6dHJ1ZSwicm9vbSI6InRlc3Qtcm9vbSIsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZSwiY2FuUHVibGlzaERhdGEiOnRydWV9LCJzdWIiOiJ1c2VyLTEyMyIsImlzcyI6ImRldmtleSIsIm5iZiI6MTc2NDY2ODMyMCwiZXhwIjoxNzY0NzU0NzIwfQ.Z9oC17-zgxPKj41b-KKE74BF2H0IIoGrDSr_IH30c7A';

    try {
      final room = Room();

      // Add listener for connection state
      room.addListener(() {
        debugPrint('🔗 Room state: ${room.connectionState}'); // Fixed syntax here
      });

      debugPrint('📡 Connecting to LiveKit...'); // Fixed syntax here
      await room.connect(url, token);
      debugPrint('✅ Connected to room: ${room.name}'); // Fixed syntax here

      final local = room.localParticipant;
      if (local != null) {
        debugPrint('📹 Enabling camera...'); // Fixed syntax here
        await local.setCameraEnabled(true);

        debugPrint('🎤 Enabling microphone...'); // Fixed syntax here
        await local.setMicrophoneEnabled(true);

        debugPrint('🎥 Streaming started!'); // Fixed syntax here
      }

      setState(() {
        _room = room;
        _isStreaming = true;
      });

    } catch (e) {
      debugPrint('❌ Error starting stream: $e'); // Fixed syntax here
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start stream: $e')),
        );
      }
    }
  }

  Future<void> _stopStreaming() async {
    final local = _room?.localParticipant;
    if (local != null) {
      await local.setCameraEnabled(false);
      await local.setMicrophoneEnabled(false);
    }
    await _room?.disconnect();

    setState(() {
      _room = null;
      _isStreaming = false;
    });
  }

  @override
  void dispose() {
    _room?.disconnect();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If camera isn't ready, show loading
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Camera Preview')),
      body: Stack(
        children: [
          CameraPreview(controller!),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _isStreaming ? _stopStreaming : _startStreaming,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isStreaming ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isStreaming ? 'Stop' : 'Go Live'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}