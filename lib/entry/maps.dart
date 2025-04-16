import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:safebite/components/NavBar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safebite/entry/useraccountsearched.dart';
import 'dart:math';

class GoogleMapsScreen extends StatefulWidget {
  static const String id = "map_screen";
  @override
  _GoogleMapsScreenState createState() => _GoogleMapsScreenState();
}

class _GoogleMapsScreenState extends State<GoogleMapsScreen> {
  late GoogleMapController? _mapController; // Make nullable
  LatLng _currentLocation = const LatLng(37.7749, -122.4194);
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};
  String apiKey = "AIzaSyAAi8LGNdXJrGSdlZo6O5vzIfM74smSK1s";
  User? currentUser = FirebaseAuth.instance.currentUser;
  List<String> userAllergens = [];
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = false;
  List<Map<String, dynamic>> _recommendedRestaurants = [];
  bool _showRecommendedCard = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchUserAllergens();

    // Remove the listener from _searchFocusNode
  }

  Future<void> _determinePosition() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      if (_mapController != null) {
        _moveCameraToPosition(_currentLocation);
        debugNearbyRestaurants(position.latitude, position.longitude);
      }
    } else {
      print("Location permission denied.");
    }
  }

  void _moveCameraToPosition(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: position, zoom: 14.0),
    ));
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of Earth in KM
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in KM
  }

  Future<List<Map<String, dynamic>>> fetchNearbyRestaurants(
      double userLat, double userLon) async {
    CollectionReference reps = FirebaseFirestore.instance.collection('rep');
    QuerySnapshot snapshot = await reps.get();

    List<Map<String, dynamic>> nearbyRestaurants = [];

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;

      if (data.containsKey('business_location') &&
          data['business_location'] != null) {
        GeoPoint location = data['business_location'];
        double restaurantLat = location.latitude;
        double restaurantLon = location.longitude;

        double distance =
            calculateDistance(userLat, userLon, restaurantLat, restaurantLon);

        Map<String, dynamic> allergenData = await _fetchAllergenFriendliness(
            LatLng(restaurantLat, restaurantLon));
        List<String> restaurantTags =
            List<String>.from(allergenData['allergens'] ?? []);

        bool matchesUserAllergens =
            restaurantTags.any((tag) => userAllergens.contains(tag));

        print("${data['business_name']} Distance: $distance km");
        print("Restaurant: ${data['business_name']} Tags: $restaurantTags");
        print("User Allergens: $userAllergens");
        print(
            "Match: ${restaurantTags.any((tag) => userAllergens.contains(tag))}");

        if (distance <= 10 && matchesUserAllergens) {
          String? placeId =
              data.containsKey('place_id') && data['place_id'] is String
                  ? data['place_id']
                  : doc.id; // Use Firestore doc ID as a fallback

          nearbyRestaurants.add({
            'name': data['business_name'],
            'latitude': restaurantLat,
            'longitude': restaurantLon,
            'distance': distance,
            'tags': restaurantTags,
            'place_id': placeId, // Ensure `place_id` is always a String
          });

          print(
              "Restaurant Added: ${data['business_name']} with place_id: $placeId"); // Add this line
        }
      }
    }
    return nearbyRestaurants;
  }

  Future<void> debugNearbyRestaurants(double userLat, double userLon) async {
    List<Map<String, dynamic>> restaurants =
        await fetchNearbyRestaurants(userLat, userLon);

    if (restaurants.isEmpty) {
      print("No nearby restaurants found within 10km.");
      return;
    }

    print("Nearby Restaurants within 10km:");
    for (var restaurant in restaurants) {
      print("🏠 Name: ${restaurant['name']}");
      print("📍 Distance: ${restaurant['distance'].toStringAsFixed(2)} km");
      print("🍽️ Allergen-Friendly Tags: ${restaurant['tags']}");
      print("--------------------------------------");
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (_mapController == null) return;

    String url =
        "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query+restaurants&location=${_currentLocation.latitude},${_currentLocation.longitude}&radius=5000&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['results'];

        setState(() {
          _markers.clear();
          if (places != null && places is List) {
            for (var place in places) {
              if (place != null &&
                  place is Map<String, dynamic> &&
                  place['geometry'] != null &&
                  place['geometry']['location'] != null) {
                final location = place['geometry']['location'];
                final latLng = LatLng(location['lat'], location['lng']);

                final marker = Marker(
                  markerId: MarkerId(place['place_id']),
                  position: latLng,
                  infoWindow: InfoWindow(
                    title: place['name'],
                    snippet: "Tap for details",
                    onTap: () => _getPlaceDetails(place['place_id']),
                  ),
                );
                _markers.add(marker);
                print("ITS HEREEEEE");
                print(place['place_id']);

                if (_markers.isNotEmpty) {
                  _mapController?.animateCamera(CameraUpdate.newCameraPosition(
                    CameraPosition(target: latLng, zoom: 18.0),
                  ));
                }
              } else {
                print('Invalid place data: $place');
              }
            }
          } else {
            print("Invalid places data");
          }
        });
      } else {
        print("Error searching places: ${response.statusCode}");
      }
    } catch (e) {
      print('Error during search: $e');
    }
  }

  void _showRecommendedRestaurants() async {
    List<Map<String, dynamic>> nearbyRestaurants = await fetchNearbyRestaurants(
        _currentLocation.latitude, _currentLocation.longitude);

    if (nearbyRestaurants.isEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            color: Colors.black,
            padding: EdgeInsets.all(16),
            child: Text(
              "No recommended restaurants available.",
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      )..whenComplete(() {
          setState(() {
            _showRecommendedCard = false;
          });
        });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.6,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView.separated(
                controller: scrollController,
                itemCount: nearbyRestaurants.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final Map<String, dynamic> restaurant =
                      nearbyRestaurants[index];
                  return ListTile(
                    title: Text(
                      restaurant['name'] ?? 'Unknown',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Distance: ${restaurant['distance'].toStringAsFixed(2)} km",
                          style: TextStyle(color: Colors.white),
                        ),
                        if (restaurant['tags'] != null &&
                            restaurant['tags'].isNotEmpty)
                          Wrap(
                            spacing: 4,
                            children: (restaurant['tags'] as List<String>)
                                .map((tag) => Chip(
                                      label: Text(tag,
                                          style:
                                              TextStyle(color: Colors.black)),
                                      backgroundColor: Colors.white,
                                    ))
                                .toList(),
                          )
                        else
                          Text(
                            "No allergen info available",
                            style: TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.place,
                      color: Colors.white,
                    ),
                    onTap: () async {
                      if (_mapController != null) {
                        LatLng restaurantLocation = LatLng(
                          restaurant['latitude'],
                          restaurant['longitude'],
                        );
                        _mapController?.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: restaurantLocation,
                              zoom: 18.0,
                            ),
                          ),
                        );

                        setState(() {
                          _markers.clear();
                          _markers.add(
                            Marker(
                              markerId: MarkerId(
                                  restaurant['place_id'] is String
                                      ? restaurant['place_id']
                                      : restaurant['name']),
                              position: restaurantLocation,
                              infoWindow: InfoWindow(
                                title: restaurant['name'],
                                snippet: "Tap for details",
                                onTap: () {
                                  _searchPlaceDetailsByName(
                                      restaurant['name'], restaurantLocation);
                                },
                              ),
                            ),
                          );
                          print(
                              "Restaurant Place ID: ${restaurant['place_id']}");
                        });
                      }
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            );
          },
        );
      },
    )..whenComplete(() {
        setState(() {
          _showRecommendedCard = false;
        });
      });
  }

  Future<void> _searchPlaceDetailsByName(
      String restaurantName, LatLng location) async {
    String query = "$restaurantName restaurants";
    String url =
        "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&location=${location.latitude},${location.longitude}&radius=5000&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['results'];

        if (places != null && places is List && places.isNotEmpty) {
          String placeId = places[0]['place_id'];
          _getPlaceDetails(placeId);
        } else {
          print("No matching place found for $restaurantName");
        }
      } else {
        print("Error searching place: ${response.statusCode}");
      }
    } catch (e) {
      print("Error searching place: $e");
    }
  }

  String getOpeningStatusAndTime(Map<String, dynamic> details) {
    if (details['opening_hours'] != null &&
        details['opening_hours']['periods'] != null &&
        details['opening_hours']['periods'] is List &&
        details['opening_hours']['periods'].isNotEmpty) {
      final periods = details['opening_hours']['periods'] as List;
      int currentDay = DateTime.now().weekday - 1;

      for (var period in periods) {
        if (period['open'] != null && period['open']['day'] == currentDay) {
          if (period['close'] != null && period['close']['time'] != null) {
            String time = period['close']['time'] as String;
            String formattedTime = time;

            if (time.length == 4) {
              int hours = int.parse(time.substring(0, 2));
              int minutes = int.parse(time.substring(2));
              String amPm = hours < 12 || hours == 24 ? 'AM' : 'PM';
              hours = hours % 12;
              hours = hours == 0 ? 12 : hours;
              formattedTime =
                  "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $amPm";
            }
            return "Closes at $formattedTime";
          } else {
            return "Status: Open"; // No close time, assume open
          }
        }
      }

      return "Status: Closed"; // No period found for today, assume closed
    } else {
      return "Opening hours not available"; // No opening_hours info
    }
  }

  Future<void> _fetchUserAllergens() async {
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    setState(() {
      userAllergens = (userDoc.data()?['allergens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      print(userAllergens);
    });
  }

  Future<void> _getPlaceDetails(String placeId) async {
    String url =
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey&fields=name,geometry,formatted_address,opening_hours,rating,photos";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final placeDetails = data['result'];

        if (placeDetails['geometry'] != null &&
            placeDetails['geometry']['location'] != null) {
          final location = placeDetails['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);

          print(
              "Selected Place LatLng: ${latLng.latitude}, ${latLng.longitude}");

          Map<String, dynamic> allergenData =
              await _fetchAllergenFriendliness(latLng);
          List<String> allergenTags =
              List<String>.from(allergenData['allergens'] ?? []);

          String? imageUrl;
          if (placeDetails['photos'] != null &&
              (placeDetails['photos'] as List).isNotEmpty) {
            String photoReference =
                placeDetails['photos'][0]['photo_reference'];
            imageUrl =
                "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$apiKey";
          }

          _showPlaceDetailsCard(
              placeDetails, imageUrl, allergenTags, allergenData);
        }
      } else {
        print("Error getting place details: ${response.statusCode}");
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchAllergenFriendliness(LatLng latLng) async {
    try {
      double lat = latLng.latitude;
      double lng = latLng.longitude;
      double range = 0.001;

      QuerySnapshot repSnapshot =
          await FirebaseFirestore.instance.collection('rep').get();

      List<QueryDocumentSnapshot> matchingReps = repSnapshot.docs.where((doc) {
        GeoPoint geoPoint = doc['business_location']; // GeoPoint object
        double docLat = geoPoint.latitude;
        double docLng = geoPoint.longitude;

        return (docLat >= lat - range && docLat <= lat + range) &&
            (docLng >= lng - range && docLng <= lng + range);
      }).toList();

      if (matchingReps.isNotEmpty) {
        String businessName = matchingReps.first['business_name'];
        String businessEmail = matchingReps.first['email'];

        QuerySnapshot postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('business_name', isEqualTo: businessName)
            .get();

        Set<String> allergens = {};
        for (var post in postsSnapshot.docs) {
          allergens.addAll(List<String>.from(post['tags'] ?? []));
        }

        return {
          'allergens': allergens.toSet().toList(),
          'hasProfile': true,
          'businessName': businessName,
          'email': businessEmail,
        };
      }
    } catch (e) {
      print("Error fetching allergen friendliness: $e");
    }
    return {'allergens': [], 'hasProfile': false};
  }

  void _showPlaceDetailsCard(Map<String, dynamic> details, String? imageUrl,
      List<String> allergenTags, Map<String, dynamic> allergenData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: ListView(
                controller: scrollController,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(details['name'] ?? "Restaurant Details",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
                  SizedBox(height: 16),
                  _buildRatingStars(details['rating']),
                  if (allergenTags.isNotEmpty)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(80, 10),
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          textStyle: TextStyle(fontSize: 17)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserAccountSearched(
                              businessAccountEmail: allergenData['email'],
                            ),
                          ),
                        );
                      },
                      child: Text("View Profile"),
                    ),
                  SizedBox(height: 16),
                  Text("Allergen Friendliness",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: allergenTags.isNotEmpty
                        ? allergenTags
                            .map((tag) => Chip(label: Text(tag)))
                            .toList()
                        : [Chip(label: Text("No allergen data available"))],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.location_on),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(details['formatted_address'] ?? "N/A"),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.access_time),
                      SizedBox(width: 8),
                      Text(getOpeningStatusAndTime(details)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRatingStars(double? rating) {
    if (rating == null) {
      return Text("No rating available");
    }

    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    List<Widget> stars = [];
    for (int i = 0; i < fullStars; i++) {
      stars.add(Icon(Icons.star, color: Colors.amber));
    }
    if (hasHalfStar) {
      stars.add(Icon(Icons.star_half, color: Colors.amber));
    }
    for (int i = stars.length; i < 5; i++) {
      stars.add(Icon(Icons.star_border, color: Colors.amber));
    }

    return Row(children: stars);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavBar(selectedIndex: 2),
      appBar: AppBar(
        title: Center(child: Text("Find Restaurants")),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition:
                CameraPosition(target: _currentLocation, zoom: 14.0),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900], // Match the background color
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search accounts",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none, // Removes default border
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search, color: Colors.white),
                        onPressed: () => _searchPlaces(_searchController.text),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _showRecommendedCard = true;
                      });
                    },
                  ),
                ),
                Visibility(
                  visible: _showRecommendedCard,
                  child: Card(
                    child: ListTile(
                      title: Text("Recommended"),
                      onTap: () {
                        setState(() {
                          _showRecommendedCard = false;
                        });
                        _showRecommendedRestaurants();
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
