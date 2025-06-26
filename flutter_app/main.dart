import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const FallDetectionApp());
}

class FallDetectionApp extends StatelessWidget {
  const FallDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Detection!',
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showCamera = true;
  String? cameraUrl;
  String? deviceIp;
  String fallStatus = '';
  DateTime? fallTime;
  String? lastNotifiedStatus;
  Timer? _pollingTimer;

  // Camera specific variables
  String? cameraServerIp;
  String cameraFallStatus = '';
  DateTime? cameraFallTime;
  String? lastCameraNotifiedStatus;
  Timer? _cameraPollingTimer;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initializeNotification();
  }

  void _initializeNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'fall_channel',
      'Fall Detection Alerts',
      channelDescription: 'Notifications for fall detection',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Fall Detected',
      message,
      platformChannelSpecifics,
    );
  }

  Future<void> _playFallAlertSound() async {
    await audioPlayer.play(AssetSource('alert.mp3'));
  }

  void _showFallAlertPopup() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.red, width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 30),
              const SizedBox(width: 10),
              const Text(
                'FALL DETECTED!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A fall has been detected by the device.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Time: ${fallTime != null ? '${fallTime!.hour.toString().padLeft(2, '0')}:${fallTime!.minute.toString().padLeft(2, '0')}:${fallTime!.second.toString().padLeft(2, '0')}' : 'Unknown'}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                'Device IP: ${deviceIp ?? 'Unknown'}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                audioPlayer.stop(); // Stop the alert sound
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('ACKNOWLEDGE'),
            ),
          ],
        );
      },
    );
  }

  void _showCameraFallAlertPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.red, width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.videocam, color: Colors.red, size: 30),
              const SizedBox(width: 10),
              const Text(
                'CAMERA FALL DETECTED!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Screenshot container
              Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    'http://$cameraServerIp:5000/fall_screenshot',
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              Text('Screenshot\nUnavailable',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Fall detected by camera system',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 5),
                        Text(
                          'Time: ${cameraFallTime != null ? '${cameraFallTime!.hour.toString().padLeft(2, '0')}:${cameraFallTime!.minute.toString().padLeft(2, '0')}:${cameraFallTime!.second.toString().padLeft(2, '0')}' : 'Unknown'}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 5),
                        Text(
                          'Date: ${cameraFallTime != null ? '${cameraFallTime!.day.toString().padLeft(2, '0')}/${cameraFallTime!.month.toString().padLeft(2, '0')}/${cameraFallTime!.year}' : 'Unknown'}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                audioPlayer.stop();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('ACKNOWLEDGE'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cameraPollingTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = showCamera ? Colors.blue : Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        backgroundColor: themeColor,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: themeColor),
              child: const Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log Out'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Camera', style: TextStyle(color: showCamera ? themeColor : Colors.grey)),
                Switch(
                  activeColor: themeColor,
                  value: !showCamera,
                  onChanged: (v) {
                    setState(() {
                      showCamera = !v;
                    });
                  },
                ),
                Text('Device', style: TextStyle(color: !showCamera ? themeColor : Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: showCamera ? _buildCameraPanel(themeColor) : _buildDevicePanel(themeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPanel(Color themeColor) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (cameraServerIp?.isNotEmpty == true)
                Column(
                  children: [
                    Icon(Icons.videocam, size: 60, color: themeColor),
                    SizedBox(height: 10),
                    Text(
                      'Camera System Connected',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Flask Server: $cameraServerIp:5000',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getCameraStatusColor(),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Status: ${_getCameraStatusText()}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Icon(Icons.videocam_off, size: 60, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'Camera System Disconnected',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Connect to Flask server for fall detection',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton(
            backgroundColor: themeColor,
            mini: true,
            onPressed: _addCameraSystem,
            child: const Icon(Icons.add),
          ),
        ),
        if (cameraServerIp != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              mini: true,
              onPressed: _disconnectCameraSystem,
              child: const Icon(Icons.link_off),
            ),
          ),
      ],
    );
  }

  Color _getCameraStatusColor() {
    if (cameraFallStatus.contains('FALL_CONFIRMED')) return Colors.red;
    if (cameraFallStatus.contains('FALL_DETECTED_MONITORING')) return Colors.orange;
    if (cameraFallStatus.contains('NO_FALL')) return Colors.green;
    return Colors.grey;
  }

  String _getCameraStatusText() {
    if (cameraFallStatus.contains('FALL_CONFIRMED')) return 'FALL CONFIRMED';
    if (cameraFallStatus.contains('FALL_DETECTED_MONITORING')) return 'MONITORING FALL';
    if (cameraFallStatus.contains('NO_FALL')) return 'MONITORING';
    if (cameraFallStatus.contains('CAMERA_ERROR')) return 'CAMERA ERROR';
    return cameraFallStatus.isEmpty ? 'CONNECTING...' : cameraFallStatus;
  }

  Widget _buildDevicePanel(Color themeColor) {
    final elapsedTime = fallTime != null ? DateTime.now().difference(fallTime!) : null;

    return Stack(
      children: [
        Center(
          child: Text(
            deviceIp?.isNotEmpty == true
                ? 'Device IP: $deviceIp\nStatus: $fallStatus'
                '${(fallStatus == 'FALL DETECTED' && elapsedTime != null) ? '\nTime since fall: ${elapsedTime.inSeconds}s' : ''}'
                : 'Your Device will be visible here!',
            textAlign: TextAlign.center,
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton(
            backgroundColor: themeColor,
            mini: true,
            onPressed: _addDevice,
            child: const Icon(Icons.add),
          ),
        ),
        if (deviceIp != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              mini: true,
              onPressed: _disconnectDevice,
              child: const Icon(Icons.link_off),
            ),
          ),
      ],
    );
  }

  void _addCameraSystem() {
    String input = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.videocam, color: Colors.blue),
            SizedBox(width: 10),
            Text('Connect to Camera System'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Flask Server IP Address:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '192.168.18.17',
                prefixText: 'http://',
                suffixText: ':5000',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => input = v,
            ),
            SizedBox(height: 10),
            Text(
              'This should be your laptop\'s IP address where Flask server is running.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (input.isNotEmpty) {
                setState(() {
                  cameraServerIp = input;
                  cameraFallStatus = 'Connecting...';
                  cameraFallTime = null;
                  lastCameraNotifiedStatus = null;
                });
                _startCameraPolling();
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _startCameraPolling() {
    _cameraPollingTimer?.cancel();
    _cameraPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (cameraServerIp == null) return;
      final url = Uri.parse('http://$cameraServerIp:5000/fall_status');
      try {
        final response = await http.get(url).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          final newStatus = jsonData['status'];
          final timestamp = jsonData['timestamp'];

          setState(() {
            cameraFallStatus = newStatus;
            if (newStatus == 'FALL_CONFIRMED' && lastCameraNotifiedStatus != 'camera_fall') {
              cameraFallTime = DateTime.now();
              lastCameraNotifiedStatus = 'camera_fall';
              _showNotification('CAMERA FALL DETECTED at ${cameraFallTime!.hour}:${cameraFallTime!.minute}:${cameraFallTime!.second}');
              _playFallAlertSound();
              _showCameraFallAlertPopup();
            } else if (newStatus != 'FALL_CONFIRMED') {
              lastCameraNotifiedStatus = 'camera_no_fall';
            }
          });
        } else {
          setState(() => cameraFallStatus = 'Server Error: ${response.statusCode}');
        }
      } catch (e) {
        setState(() => cameraFallStatus = 'Connection Failed');
      }
    });
  }

  void _disconnectCameraSystem() {
    _cameraPollingTimer?.cancel();
    setState(() {
      cameraServerIp = null;
      cameraFallStatus = '';
      cameraFallTime = null;
      lastCameraNotifiedStatus = null;
    });
  }

  void _addCamera() {
    String input = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Camera URL'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'rtsp://...'),
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (input.isNotEmpty) {
                setState(() => cameraUrl = input);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConnectionDetailScreen(
                      title: 'Camera Details',
                      details: 'IP: $cameraUrl\nConnected at: ${DateTime.now()}',
                    ),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addDevice() async {
    String input = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Device IP'),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '192.168.0.xxx'),
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (input.isNotEmpty) {
                setState(() {
                  deviceIp = input;
                  fallStatus = 'Checking...';
                  fallTime = null;
                  lastNotifiedStatus = null;
                });
                _startPolling();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (deviceIp == null) return;
      final url = Uri.parse('http://$deviceIp/fall_status');
      try {
        final response = await http.get(url).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final newStatus = response.body.trim();
          setState(() {
            fallStatus = response.body;
            if (newStatus == 'FALL DETECTED' && lastNotifiedStatus != 'fall') {
              fallTime = DateTime.now();
              lastNotifiedStatus = 'fall';
              _showNotification('FALL DETECTED at ${fallTime!.hour}:${fallTime!.minute}:${fallTime!.second}');
              _playFallAlertSound();
              _showFallAlertPopup(); // Show the pop-up alert
            } else if (newStatus != 'FALL DETECTED') {
              lastNotifiedStatus = 'no_fall';
            }
          });
        } else {
          setState(() => fallStatus = 'Error: ${response.statusCode}');
        }
      } catch (_) {
        setState(() => fallStatus = 'Request failed');
      }
    });
  }

  void _disconnectDevice() {
    _pollingTimer?.cancel();
    setState(() {
      deviceIp = null;
      fallStatus = '';
      fallTime = null;
      lastNotifiedStatus = null;
    });
  }
}

class ConnectionDetailScreen extends StatelessWidget {
  final String title;
  final String details;

  const ConnectionDetailScreen({super.key, required this.title, required this.details});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(details),
      ),
    );
  }
}