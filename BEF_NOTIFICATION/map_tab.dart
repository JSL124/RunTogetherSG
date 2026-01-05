// lib/map_tab.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; 
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'event_service.dart';
import 'event_model.dart';
import 'event_details_screen.dart';
import 'create_event_screen.dart'; 

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  // 🔑 API Key (본인 키 확인 필수)
  final String googleMapsApiKey = "AIzaSyDGG3VLuEVtGPHdqBRSqFI3V0LI2YVCiLA"; 

  final EventService _eventService = EventService();
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  
  late Stream<List<RunningEvent>> _eventsStream;
  String _searchQuery = '';
  
  List<dynamic> _placePredictions = []; 
  final _uuid = const Uuid();
  String? _sessionToken; 
  
  // 💡 [NEW] 자동완성 재검색 방지 플래그
  // (목록을 눌러서 텍스트가 바뀔 때는 검색 API를 호출하지 않게 막는 역할)
  bool _preventSearch = false;

  static const LatLng _defaultLocation = LatLng(1.3521, 103.8198);
  LatLng _currentCenter = _defaultLocation;

  @override
  void initState() {
    super.initState();
    _eventsStream = _eventService.getEvents();
    _determinePosition();
    _searchController.addListener(_onSearchChanged);

    // 💡 [추가] 앱 켤 때 24시간 지난 건 자동으로 완료 처리!
    _eventService.checkAutoCompletion();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // 💡 [수정] 플래그가 켜져 있으면 검색하지 않고 함수 종료!
    if (_preventSearch) return;

    if (_sessionToken == null) {
      setState(() {
        _sessionToken = _uuid.v4();
      });
    }
    _getPlacePredictions(_searchController.text);
  }

  Future<void> _getPlacePredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _placePredictions = [];
      });
      return;
    }

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

  Future<void> _moveToLocation({String? placeId, required String description}) async {
    // 1. 키보드 내리기
    FocusScope.of(context).unfocus();
    
    // 💡 [수정] 텍스트를 바꾸기 전에 "검색 방지 모드"를 켭니다.
    _preventSearch = true; 
    _searchController.text = description; // 이제 텍스트가 바껴도 API 호출 안 함
    _preventSearch = false; // 다시 해제

    // 2. 상태 업데이트 (목록 지우기)
    setState(() {
      _placePredictions = [];
      _sessionToken = null; 
      _searchQuery = ''; 
    });

    LatLng? targetCoordinates;

    try {
      if (placeId != null) {
        final String detailsUrl = 
            'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$googleMapsApiKey';
        
        final response = await http.get(Uri.parse(detailsUrl));
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          targetCoordinates = LatLng(location['lat'], location['lng']);
        }
      }

      if (targetCoordinates == null) {
        List<Location> locations = await locationFromAddress(description);
        if (locations.isNotEmpty) {
          final Location loc = locations.first;
          targetCoordinates = LatLng(loc.latitude, loc.longitude);
        }
      }

      if (targetCoordinates != null) {
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(targetCoordinates, 15.0),
          );
        }
        setState(() {
          _currentCenter = targetCoordinates!;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find location coordinates.')),
        );
      }

    } catch (e) {
      print("Move Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error moving to location.')),
      );
    }
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
    final target = LatLng(position.latitude, position.longitude);

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(target),
      );
    }
    
    setState(() {
      _currentCenter = target;
    });
  }

  void _onEventTapped(RunningEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
    );
  }
  
  void _onCreateEventTapped() async {
     await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEventScreen()),
    );
  }

  Set<Marker> _calculateMarkers(List<RunningEvent> events) {
    return events.map((event) => event.toMarker(onTap: _onEventTapped)).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, 
      body: StreamBuilder<List<RunningEvent>>( 
        stream: _eventsStream,
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          List<RunningEvent> allEvents = snapshot.data ?? [];
          
          List<RunningEvent> filteredEvents = allEvents.where((event) {
            final titleLower = event.title.toLowerCase();
            final queryLower = _searchQuery.toLowerCase();
            final matchesSearch = _searchQuery.isEmpty || titleLower.contains(queryLower);
            
            double distanceInMeters = Geolocator.distanceBetween(
              _currentCenter.latitude,
              _currentCenter.longitude,
              event.location.latitude,
              event.location.longitude,
            );

            final isNearby = distanceInMeters <= 10000; 

            return matchesSearch && isNearby;
          }).toList();

          final Set<Marker> currentMarkers = _calculateMarkers(filteredEvents);

          return Stack(
            children: <Widget>[
              // 1. 지도
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultLocation, 
                  zoom: 14.0,
                ),
                mapType: MapType.normal,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true, // 버튼으로 줌 가능
                markers: currentMarkers, 
                onMapCreated: (controller) {
                  _mapController = controller;
                  _determinePosition();
                },
                onCameraMove: (CameraPosition position) {
                  setState(() {
                    _currentCenter = position.target;
                  });
                },
                onTap: (_) {
                   setState(() {
                     _placePredictions = [];
                     FocusScope.of(context).unfocus();
                   });
                },
              ),

              // 2. 검색 바
               Positioned(
                top: 60, 
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search location (World wide)...',
                                border: InputBorder.none,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              onSubmitted: (value) {
                                if (_placePredictions.isNotEmpty) {
                                   final item = _placePredictions[0];
                                  _moveToLocation(
                                    placeId: item['place_id'], 
                                    description: item['description']
                                  );
                                } else {
                                  _moveToLocation(description: value);
                                }
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _placePredictions = [];
                                  _searchQuery = '';
                                });
                              },
                              child: const Icon(Icons.close, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    
                    if (_placePredictions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 10)
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _placePredictions.length > 4 ? 4 : _placePredictions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final prediction = _placePredictions[index];
                            final String description = prediction['description'] ?? '';
                            final String placeId = prediction['place_id'] ?? ''; 

                            final structured = prediction['structured_formatting'];
                            String mainText = description;
                            String secondaryText = '';
                            if (structured != null) {
                              mainText = structured['main_text'] ?? description;
                              secondaryText = structured['secondary_text'] ?? '';
                            }

                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on, color: Colors.blueGrey, size: 20),
                              title: Text(mainText, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: secondaryText.isNotEmpty ? Text(secondaryText) : null,
                              onTap: () => _moveToLocation(
                                placeId: placeId, 
                                description: description
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // 3. 내 위치 버튼
              Positioned(
                top: 130 + (_placePredictions.isNotEmpty ? 200 : 0),
                right: 20,
                child: FloatingActionButton.small(
                  heroTag: "gps_btn",
                  onPressed: _determinePosition,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.black87),
                ),
              ),

              // 4. 하단 이벤트 리스트
               Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 240, 
                child: Container(
                  padding: const EdgeInsets.only(top: 15, bottom: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
                    ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Events Nearby (10km)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${filteredEvents.length} found',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 15),
                          children: filteredEvents.isNotEmpty
                            ? filteredEvents.map((event) => _buildEventCard(event)).toList()
                            : [_buildEmptyCard()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 5. 생성 버튼
              Positioned(
                bottom: 260, 
                right: 20,
                child: FloatingActionButton(
                  heroTag: "add_btn",
                  onPressed: _onCreateEventTapped, 
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildEventCard(RunningEvent event) {
    final Duration diff = event.dateTime.difference(DateTime.now());
    String timeLeft;
    if (diff.isNegative) {
      timeLeft = 'Finished';
    } else {
      final int days = diff.inDays;
      final int hours = diff.inHours % 24;
      final int minutes = diff.inMinutes % 60;
      if (days > 0) timeLeft = '${days}d ${hours}h left'; 
      else if (hours > 0) timeLeft = '${hours}h ${minutes}m left'; 
      else timeLeft = '${minutes}m left';
    }
    
    bool isUrgent = timeLeft.contains('m left') && !timeLeft.contains('d'); 

    return GestureDetector(
      onTap: () => _onEventTapped(event),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8), 
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.level,
                        style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 10, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, h:mm a').format(event.dateTime), 
                            style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: isUrgent ? Colors.red : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      timeLeft,
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                        color: isUrgent ? Colors.red : Colors.grey[700]
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${event.participants.length}/${event.maxParticipants}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyCard() {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No events within 10km.\nMove map or create one!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}