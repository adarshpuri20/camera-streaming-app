import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  String? _currentEgressId;

  //Subdomain
  static const String backendHost = 'https://api.mayacam.link';

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
    try {
      // 1. Call backend to get token + start egress
      final backendUrl = '$backendHost/live/start';
      
      debugPrint('📞 Calling backend: $backendUrl');
      
      final resp = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tenantId': 'tenant1',
          'siteId': 'site1',
          'cameraId': 'cam1',
          'mode': 'record-only',
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Backend error: ${resp.statusCode} ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      final url = data['url'] as String;
      final token = data['token'] as String;
      final roomName = data['room'] as String;
      final egressId = data['egressId'] as String;

      debugPrint('✅ Backend response: room=$roomName, egressId=$egressId');

      // 2. Connect to LiveKit using backend token
      final room = Room();

      room.addListener(() {
        debugPrint('🔗 Room state: ${room.connectionState}');
      });

      debugPrint('📡 Connecting to LiveKit...');
      await room.connect(url, token);
      debugPrint('✅ Connected to room: ${room.name}');

      // 3. Enable camera + mic
      final local = room.localParticipant;
      if (local != null) {
        debugPrint('📹 Enabling camera...');
        await local.setCameraEnabled(true);

        debugPrint('🎤 Enabling microphone...');
        await local.setMicrophoneEnabled(true);

        debugPrint('🎥 Streaming started!');
      }

      setState(() {
        _room = room;
        _isStreaming = true;
        _currentEgressId = egressId;
      });

    } catch (e) {
      debugPrint('❌ Error starting stream: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start stream: $e')),
        );
      }
    }
  }

  Future<void> _stopStreaming() async {
    // 1. Optionally tell backend to stop egress
    if (_currentEgressId != null) {
      try {
        final backendUrl = '$backendHost/live/stop';
        debugPrint('📞 Calling backend to stop egress: $_currentEgressId');
        
        await http.post(
          Uri.parse(backendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'egressId': _currentEgressId}),
        );
        
        debugPrint('✅ Backend: egress stop requested');
      } catch (e) {
        debugPrint('⚠️ Failed to call /live/stop: $e');
        // Continue with disconnect anyway
      }
    }

    // 2. Disable camera/mic and disconnect
    final local = _room?.localParticipant;
    if (local != null) {
      await local.setCameraEnabled(false);
      await local.setMicrophoneEnabled(false);
    }
    await _room?.disconnect();

    setState(() {
      _room = null;
      _isStreaming = false;
      _currentEgressId = null;
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