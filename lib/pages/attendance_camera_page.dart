import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class AttendanceCameraPage extends StatefulWidget {
  const AttendanceCameraPage({Key? key}) : super(key: key);

  @override
  State<AttendanceCameraPage> createState() => _AttendanceCameraPageState();
}

class _AttendanceCameraPageState extends State<AttendanceCameraPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  XFile? _capturedImage;
  Position? _currentPosition;
  String _permissionStatus = '';
  final TextEditingController _captionController = TextEditingController();
  String? _selectedOption = 'Perjalanan Dinas';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request permissions
    final cameraStatus = await Permission.camera.request();
    final locationStatus = await Permission.location.request();

    if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
      setState(() {
        _permissionStatus = 'Camera permission denied';
      });
      return;
    }

    if (locationStatus.isDenied || locationStatus.isPermanentlyDenied) {
      setState(() {
        _permissionStatus = 'Location permission denied. Continuing without GPS.';
      });
    }

    try {
      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _permissionStatus = 'No cameras available';
        });
        return;
      }

      // Initialize the front camera (index 1) or back camera (index 0)
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Get current location
      _getCurrentLocation();
    } catch (e) {
      setState(() {
        _permissionStatus = 'Error initializing camera: ${e.toString()}';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied ||
          hasPermission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      
      // Refresh location before capture
      await _getCurrentLocation();

      setState(() {
        _capturedImage = image;
        _isCapturing = false;
      });
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing photo: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
    });
  }

  Future<void> _confirmPhoto() async {
    if (_capturedImage != null) {
      // Safely pause camera before leaving to prevent crash
      try {
        if (_cameraController != null && _cameraController!.value.isInitialized) {
          await _cameraController!.pausePreview();
        }
      } catch (e) {
        print('Error pausing camera: $e');
      }

      if (_captionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please add a caption to continue'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (!mounted) return;

      Navigator.pop(context, {
        'image': _capturedImage,
        'position': _currentPosition,
        'caption': _captionController.text,
        'selectedOption': _selectedOption,
      });
    }
  }

  @override
  void dispose() {
    // Properly dispose camera controller
    _cameraController?.dispose().then((_) {
      print('Camera controller disposed successfully');
    }).catchError((error) {
      print('Error disposing camera: $error');
    });
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _capturedImage != null
            ? _buildPreviewScreen()
            : _buildCameraScreen(),
      ),
    );
  }

  Widget _buildCameraScreen() {
    if (_permissionStatus.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _permissionStatus,
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF667EEA),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text('Open Settings', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Go Back', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Center(
          child: AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),

        // Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Text(
                  'Attendance Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 48), // Balance the close button
              ],
            ),
          ),
        ),

        // Location Info
        if (_currentPosition != null)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
                      'Long: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Center(
              child: GestureDetector(
                onTap: _isCapturing ? null : _capturePhoto,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isCapturing ? Colors.grey : Colors.transparent,
                  ),
                  child: _isCapturing
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Container(
                          margin: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewScreen() {
    return Stack(
      children: [
        // Image Preview
        Center(
          child: Image.file(
            File(_capturedImage!.path),
            fit: BoxFit.contain,
          ),
        ),

        // Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Center(
              child: Text(
                'Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        // Location Info
        if (_currentPosition != null)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.greenAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Location Captured',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(2)}m',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

        // Caption and Option Selection
        Positioned(
          bottom: 120, // Check position relative to bottom controls
          left: 16,
          right: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Caption Input
                TextField(
                  controller: _captionController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add a caption (required)...',
                    hintStyle: TextStyle(color: Colors.white60),
                    border: InputBorder.none,
                    icon: Icon(Icons.edit, color: Colors.white70),
                  ),
                  maxLines: 1,
                ),
                SizedBox(height: 12),
                // Option Selection Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedOption,
                  dropdownColor: Colors.grey[800],
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Select an option',
                    hintStyle: TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    prefixIcon: Icon(Icons.list, color: Colors.white70),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Perjalanan Dinas',
                      child: Text('Perjalanan Dinas'),
                    ),
                    DropdownMenuItem(
                      value: 'Pekerjaan Rutin',
                      child: Text('Pekerjaan Rutin'),
                    ),
                    DropdownMenuItem(
                      value: 'Work from Home',
                      child: Text('Work from Home'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedOption = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Retake Button
                ElevatedButton.icon(
                  onPressed: _retakePhoto,
                  icon: Icon(Icons.refresh, color: Colors.white),
                  label: Text(
                    'Retake',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Confirm Button
                ElevatedButton.icon(
                  onPressed: _confirmPhoto,
                  icon: Icon(Icons.check, color: Colors.white),
                  label: Text(
                    'Confirm',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF667EEA),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
