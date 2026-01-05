// lib/create_event_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'event_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  // ⚠️ 본인 API Key 확인
  final String googleMapsApiKey = "AIzaSyDGG3VLuEVtGPHdqBRSqFI3V0LI2YVCiLA"; 

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedLevel = 'Beginner';
  int _maxParticipants = 8;
  
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress; 
  
  List<dynamic> _placePredictions = [];
  final _uuid = const Uuid();
  String? _sessionToken;
  Timer? _debounce;

  bool _isProgrammaticChange = false;

  final EventService _eventService = EventService();
  bool _isLoading = false;
  static const LatLng _defaultLocation = LatLng(1.3521, 103.8198);

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15),
      );
    }
  }

  void _onSearchChanged() {
    if (_isProgrammaticChange) {
      _isProgrammaticChange = false;
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isEmpty) {
        setState(() => _placePredictions = []);
        return;
      }
      if (_sessionToken == null) {
        setState(() {
          _sessionToken = _uuid.v4();
        });
      }
      _getPlacePredictions(_searchController.text);
    });
  }

  Future<void> _getPlacePredictions(String input) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleMapsApiKey&sessiontoken=$_sessionToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _placePredictions = data['predictions'];
          });
        }
      }
    } catch (e) {
      print("Error fetching places: $e");
    }
  }

  Future<void> _moveToSearchResult(String placeId, String description) async {
    _debounce?.cancel();
    FocusScope.of(context).unfocus(); 

    _isProgrammaticChange = true;
    _searchController.text = description;

    setState(() {
      _placePredictions = [];
    });

    try {
      final String detailsUrl = 
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$googleMapsApiKey';
      
      final response = await http.get(Uri.parse(detailsUrl));
      final data = json.decode(response.body);
      
      if (data['status'] == 'OK') {
        final location = data['result']['geometry']['location'];
        final target = LatLng(location['lat'], location['lng']);

        _onMapTapped(target); 
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not move to location')));
    }
  }

  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      _placePredictions = [];
    });
    FocusScope.of(context).unfocus();

    _mapController?.animateCamera(CameraUpdate.newLatLng(position));

    try {
      final String url = 
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googleMapsApiKey';
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      String displayAddress = "";

      if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
        displayAddress = data['results'][0]['formatted_address'];
        if (displayAddress.startsWith("Singapore") && displayAddress.length < 15 && (data['results'] as List).length > 1) {
           displayAddress = data['results'][1]['formatted_address'];
        }
      } else {
        displayAddress = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
      }

      setState(() {
        _selectedLocation = position;
        _selectedAddress = displayAddress;
      });

    } catch (e) {
      setState(() {
        _selectedLocation = position;
        _selectedAddress = "Network Error (${position.latitude.toStringAsFixed(4)})";
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedLocation == null) {
      _showError('Please select a meeting spot on the map.');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showError('Please select date and time.');
      return;
    }

    setState(() => _isLoading = true);

    final DateTime combinedDateTime = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    // 💡 [핵심] 주소가 없으면 좌표라도 문자열로 변환
    final String finalAddress = _selectedAddress ?? 
        "Lat: ${_selectedLocation!.latitude}, Lng: ${_selectedLocation!.longitude}";

    try {
      await _eventService.createEvent(
        title: _titleController.text.trim(),
        dateTime: combinedDateTime,
        location: _selectedLocation!,
        address: finalAddress, // 💡 주소 전달!
        level: _selectedLevel,
        maxParticipants: _maxParticipants,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event Created Successfully! 🏃‍♂️')),
      );
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. 지도
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: _defaultLocation, zoom: 12.0),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTapped, 
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    )
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(bottom: 460, top: 40),
          ),

          // 2. 상단 검색창
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: "Search meeting spot...",
                            border: InputBorder.none,
                          ),
                          onTap: () {
                            if (_searchController.text.isNotEmpty) {
                              _isProgrammaticChange = false; 
                              _onSearchChanged();
                            }
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _placePredictions = []);
                            FocusScope.of(context).unfocus(); 
                          },
                        ),
                    ],
                  ),
                ),
                if (_placePredictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _placePredictions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _placePredictions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on, color: Colors.grey),
                          title: Text(item['description'], overflow: TextOverflow.ellipsis),
                          onTap: () => _moveToSearchResult(item['place_id'], item['description']),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. 하단 입력 폼
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 480,
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedAddress ?? "Tap map to pick location",
                                style: TextStyle(
                                  color: _selectedAddress == null ? Colors.grey : Colors.black87,
                                  fontWeight: _selectedAddress == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: "Event Title",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (val) => val!.isEmpty ? "Enter title" : null,
                      ),
                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                _selectedDate == null ? "Date" : DateFormat('MM/dd').format(_selectedDate!),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.access_time, size: 18),
                              label: Text(
                                _selectedTime == null ? "Time" : _selectedTime!.format(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedLevel,
                              decoration: InputDecoration(
                                labelText: "Level",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              ),
                              items: ['Beginner', 'Intermediate', 'Advanced']
                                  .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                                  .toList(),
                              onChanged: (val) => setState(() => _selectedLevel = val!),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("People: $_maxParticipants", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Slider(
                                  value: _maxParticipants.toDouble(),
                                  min: 2,
                                  max: 30,
                                  divisions: 28,
                                  activeColor: Colors.green,
                                  onChanged: (val) => setState(() => _maxParticipants = val.round()),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Create Event", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}