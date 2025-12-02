import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:livekit_client/livekit_client.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
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
    controller = CameraController(cameras[0], ResolutionPreset.high);
    controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _startStreaming() async {
    // TEMP: still hard‑coded until backend is ready
    const url = 'wss://livekit.mayacam.link';
    const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZGVudGl0eSI6IiIsIm5hbWUiOiIiLCJ2aWRlbyI6eyJyb29tQ3JlYXRlIjpmYWxzZSwicm9vbUxpc3QiOmZhbHNlLCJyb29tUmVjb3JkIjpmYWxzZSwicm9vbUFkbWluIjpmYWxzZSwicm9vbUpvaW4iOnRydWUsInJvb20iOiJ0ZXN0LXJvb20iLCJjYW5QdWJsaXNoIjp0cnVlLCJjYW5TdWJzY3JpYmUiOnRydWUsImNhblB1Ymxpc2hEYXRhIjp0cnVlLCJjYW5QdWJsaXNoU291cmNlcyI6W10sImNhblVwZGF0ZU93bk1ldGFkYXRhIjpmYWxzZSwiaW5ncmVzc0FkbWluIjpmYWxzZSwiaGlkZGVuIjpmYWxzZSwicmVjb3JkZXIiOmZhbHNlLCJhZ2VudCI6ZmFsc2V9LCJtZXRhZGF0YSI6IiIsInNoYTI1NiI6IiIsInN1YiI6InVzZXItMTIzIiwiaXNzIjoiZGV2a2V5IiwibmJmIjoxNzY0NjQ0OTIzLCJleHAiOjE3NjQ2NjY1MjN9.HThdNowDVjQmhd16jiBdM9hSFzIKH2aWOBVOI5cYgJI';

  try {
    final room = Room();
    
    // Add listener for connection state
    room.addListener(() {
      print('🔗 Room state: ${room.connectionState}');
    });
    
    print('📡 Connecting to LiveKit...');
    await room.connect(url, token);
    print('✅ Connected to room: ${room.name}');
    
    final local = room.localParticipant;
    if (local != null) {
      print('📹 Enabling camera...');
      await local.setCameraEnabled(true);
      
      print('🎤 Enabling microphone...');
      await local.setMicrophoneEnabled(true);
      
      print('🎥 Streaming started!');
    }

    setState(() {
      _room = room;
      _isStreaming = true;
    });
    
  } catch (e) {
    print('❌ Error starting stream: $e');
    // Show error to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start stream: $e')),
      );
    }
  }
}

//   Future<void> _startStreaming() async {
//   // 1) Call your backend to get { url, token }
//   final config = await fetchLiveKitConfig(); // e.g. HTTPS GET

//   final room = Room();
//   await room.connect(config.url, config.token);
//     final local = room.localParticipant;
//     if (local != null) {
//       await local.setCameraEnabled(true);
//       await local.setMicrophoneEnabled(true);
// }

//   setState(() {
//     _room = room;
//     _isStreaming = true;
//   });
// }

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
    if (controller == null || !controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
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
                child: Text(_isStreaming ? 'Stop' : 'Go Live'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
