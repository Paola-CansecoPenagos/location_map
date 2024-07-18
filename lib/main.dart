import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pruebamaps/firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@override
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Location Example',
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
// const _LocationScreenState({super.key});
  LatLng _currentLocation = LatLng(51.509364, -0.128928);
  LatLng? _lastRecordedLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchLastRecordedLocation();
  }

  void _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    } 

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    _saveLocationToFirestore(position);
  }

  Future<void> _fetchLastRecordedLocation() async {
    var snapshot = await FirebaseFirestore.instance.collection('locations')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .get();
    if (snapshot.docs.isNotEmpty) {
      var data = snapshot.docs.first.data();
      setState(() {
        _lastRecordedLocation = LatLng(data['latitude'], data['longitude']);
      });
    }
  }

  Future<void> _saveLocationToFirestore(Position position) async {
    await FirebaseFirestore.instance.collection('locations').add({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter:  _currentLocation,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 80.0,
              height: 80.0,
              point: _currentLocation,
              child: Icon(
                Icons.location_pin,
                color: Colors.red,
                size: 60,
              ),
            ),
            if (_lastRecordedLocation != null)
              Marker(
                width: 80.0,
                height: 80.0,
                point: _lastRecordedLocation!,
                child: Icon(
                  Icons.location_pin,
                  color: Colors.blue,
                  size: 60,
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () =>
                  launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
      ],
    );
  }
}