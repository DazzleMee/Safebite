import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:safebite/components/NavBar.dart';

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
  String apiKey =
      "AIzaSyAAi8LGNdXJrGSdlZo6O5vzIfM74smSK1s"; // Replace with your actual key

  @override
  void initState() {
    super.initState();
    _determinePosition();
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
        // Handle error, e.g., show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching restaurants.')),
        );
      }
    } catch (e) {
      print('Error during search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching restaurants.')),
      );
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
              String amPm = hours < 12 || hours == 24
                  ? 'AM'
                  : 'PM'; // Handle midnight (24:00)
              hours = hours % 12; // Convert to 12-hour format
              hours = hours == 0 ? 12 : hours; // Handle midnight (00:00)
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

  Future<void> _getPlaceDetails(String placeId) async {
    String url =
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey&fields=name,formatted_address,formatted_phone_number,website,rating,review,photos,opening_hours"; // Add photos to the fields

    try {
      final response = await http.get(Uri.parse(url));
      print("sucess");
      final data = json.decode(response.body);
      print("sucess");
      final placeDetails = data['result'];
      print("sucess");

      print("Full JSON Response: ${response.body}");

      String? imageUrl;
      if (placeDetails['photos'] != null &&
          placeDetails['photos'] is List &&
          placeDetails['photos'].isNotEmpty) {
        final photos = placeDetails['photos'] as List;
        final firstPhoto = photos[0] as Map<String, dynamic>;
        if (firstPhoto['photo_reference'] != null) {
          final photoReference = firstPhoto['photo_reference'] as String;
          imageUrl =
              "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$apiKey";
          print("Image URL: $imageUrl");
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final placeDetails = data['result'];

        // Show the details in a dialog, bottom sheet, or other UI element
        _showPlaceDetailsCard(placeDetails, imageUrl);
      } else {
        print("Error getting place details: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching restaurant details.')),
        );
      }
    } catch (e) {
      print('Error getting place details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching restaurant details.')),
      );
    }
  }

  void _showPlaceDetailsCard(Map<String, dynamic> details, String? imageUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4, // Adjust as needed
          minChildSize: 0.4,
          maxChildSize: 0.8, // Adjust as needed
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
                        onPressed: () => Navigator.pop(context), // Close button
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
                      errorBuilder: (context, object, stackTrace) =>
                          Center(child: Icon(Icons.image_not_supported)),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),

                  SizedBox(height: 16),

                  _buildRatingStars(details['rating']), // Dynamic rating stars

                  SizedBox(height: 16),

                  Text("Allergen Friendliness",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  // Use Wrap to handle multiple tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(label: Text("Vegan")),
                      Chip(label: Text("Vegetarian")),
                      Chip(label: Text("Gluten Free")),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.location_on),
                      SizedBox(width: 8),
                      Expanded(
                        // Use Expanded to prevent overflow
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
                  if (details['review'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Reviews:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        for (var review in details['review'])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(review['author_name'],
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(review['text']),
                              ],
                            ),
                          ),
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

  void _showRatingDialog(String restaurantName) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Rate $restaurantName",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(Icons.star, color: Colors.amber),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "You rated $restaurantName ${index + 1} stars!")),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller; // Assign the controller
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavBar(selectedIndex: 2),
      appBar: AppBar(
        title: Center(child: Text("Find & Rate Restaurants")),
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
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: Colors.grey, borderRadius: BorderRadius.circular(8)),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search restaurants",
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () => _searchPlaces(_searchController.text),
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
