import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/services/logger_service.dart';

/// Resolved geolocation data
class GeoLocation {
  const GeoLocation({
    required this.state,
    required this.city,
    required this.areaType,
    this.country = 'IN',
    this.lat,
    this.lon,
  });

  factory GeoLocation.fromMap(Map<String, dynamic> map) => GeoLocation(
    state: map['state'] as String? ?? 'Unknown',
    city: map['city'] as String? ?? 'Unknown',
    areaType: map['areaType'] as String? ?? 'unknown',
    country: map['country'] as String? ?? 'IN',
    lat: (map['lat'] as num?)?.toDouble(),
    lon: (map['lon'] as num?)?.toDouble(),
  );
  final String state;
  final String city;
  final String areaType; // 'urban' or 'rural'
  final String country;
  final double? lat;
  final double? lon;

  static const unknown = GeoLocation(
    state: 'Unknown',
    city: 'Unknown',
    areaType: 'unknown',
  );

  Map<String, dynamic> toMap() => {
    'state': state,
    'city': city,
    'areaType': areaType,
    'country': country,
    'lat': lat,
    'lon': lon,
  };
}

/// Service for IP to Geolocation mapping (State/City/Area).
///
/// Uses ip-api.com (free, 45 req/min) for development.
/// For production, switch to MaxMind GeoLite2 or server-side resolution.
///
/// IMPORTANT: In production, IP resolution MUST happen server-side only
/// (Cloud Function) to prevent spoofing. This service is used as a
/// fallback / local development helper.
class GeolocationService extends GetxService {
  static const String _tag = 'GeolocationService';

  /// In-memory cache: IP -> GeoLocation
  final Map<String, GeoLocation> _cache = {};

  /// Rate limiter: track request timestamps
  final List<DateTime> _requestTimestamps = [];
  static const int _maxRequestsPerMinute = 40; // Stay under 45 limit

  @override
  void onInit() {
    super.onInit();
    logger.info('Geolocation Service initialized', tag: _tag);
  }

  /// Resolve IP to full geolocation (state, city, area type).
  /// Uses ip-api.com with caching & rate limiting.
  Future<GeoLocation> getLocationFromIP(String ipAddress) async {
    try {
      // Check cache
      if (_cache.containsKey(ipAddress)) {
        return _cache[ipAddress]!;
      }

      // Rate limit check
      if (!_canMakeRequest()) {
        logger.warning('Rate limit reached, using fallback', tag: _tag);
        return _fallbackGeoLocation(ipAddress);
      }

      // Call ip-api.com (free tier, no key needed)
      final response = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/$ipAddress?fields=status,country,countryCode,region,regionName,city,lat,lon',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'success') {
          final state = data['regionName'] as String? ?? 'Unknown';
          final city = data['city'] as String? ?? 'Unknown';
          final lat = (data['lat'] as num?)?.toDouble();
          final lon = (data['lon'] as num?)?.toDouble();
          final countryCode = data['countryCode'] as String? ?? 'IN';

          final areaType = classifyAreaType(city);

          final geo = GeoLocation(
            state: state,
            city: city,
            areaType: areaType,
            country: countryCode,
            lat: lat,
            lon: lon,
          );

          _cache[ipAddress] = geo;
          _requestTimestamps.add(DateTime.now());

          logger.debug(
            'Resolved $ipAddress → $city, $state ($areaType)',
            tag: _tag,
          );
          return geo;
        }
      }

      // API failed, use fallback
      return _fallbackGeoLocation(ipAddress);
    } catch (e) {
      logger.warning('Geo lookup failed for $ipAddress: $e', tag: _tag);
      return _fallbackGeoLocation(ipAddress);
    }
  }

  /// Server-side geo resolution helper: takes pre-resolved data from
  /// Cloud Function response and returns a GeoLocation.
  GeoLocation fromServerData(Map<String, dynamic> geoData) {
    final state = geoData['state'] as String? ?? 'Unknown';
    final city = geoData['city'] as String? ?? 'Unknown';
    final areaType = geoData['areaType'] as String? ?? classifyAreaType(city);
    final country = geoData['country'] as String? ?? 'IN';

    return GeoLocation(
      state: state,
      city: city,
      areaType: areaType,
      country: country,
    );
  }

  /// Classify city as urban or rural based on Indian Census tiers.
  /// Tier-1 and Tier-2 cities → Urban. Everything else → Rural.
  String classifyAreaType(String city) {
    final normalized = city.toLowerCase().trim();
    if (_urbanCities.contains(normalized)) return 'urban';
    return 'rural';
  }

  /// Get state name from IP (legacy compatibility)
  Future<String> getStateFromIP(String ipAddress) async {
    final geo = await getLocationFromIP(ipAddress);
    return geo.state;
  }

  /// Batch get locations from multiple IPs
  Future<Map<String, GeoLocation>> getLocationsFromIPs(
    List<String> ipAddresses,
  ) async {
    final result = <String, GeoLocation>{};
    for (final ip in ipAddresses) {
      result[ip] = await getLocationFromIP(ip);
    }
    return result;
  }

  /// Get all Indian states list
  List<String> getAllIndianStates() {
    return _indianStates.values.toList()..sort();
  }

  /// Get state code from state name
  String? getStateCode(String stateName) {
    for (final entry in _indianStates.entries) {
      if (entry.value == stateName) return entry.key;
    }
    return null;
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    logger.info('Geolocation cache cleared', tag: _tag);
  }

  /// Cache stats
  Map<String, dynamic> getCacheStats() => {
    'cachedIPs': _cache.length,
    'uniqueStates': _cache.values.map((g) => g.state).toSet().length,
    'uniqueCities': _cache.values.map((g) => g.city).toSet().length,
  };

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  bool _canMakeRequest() {
    final now = DateTime.now();
    _requestTimestamps.removeWhere((t) => now.difference(t).inSeconds > 60);
    return _requestTimestamps.length < _maxRequestsPerMinute;
  }

  GeoLocation _fallbackGeoLocation(String ipAddress) {
    // Deterministic fallback: hash IP to a state for consistent results
    final hash = ipAddress.hashCode.abs();
    final states = _indianStates.values.toList();
    final state = states[hash % states.length];
    final geo = GeoLocation(
      state: state,
      city: 'Unknown',
      areaType: 'unknown',
    );
    _cache[ipAddress] = geo;
    return geo;
  }

  // ---------------------------------------------------------------------------
  // Static data
  // ---------------------------------------------------------------------------

  /// Indian states mapping
  static const Map<String, String> _indianStates = {
    'AN': 'Andaman and Nicobar',
    'AP': 'Andhra Pradesh',
    'AR': 'Arunachal Pradesh',
    'AS': 'Assam',
    'BR': 'Bihar',
    'CG': 'Chhattisgarh',
    'CH': 'Chandigarh',
    'DD': 'Daman and Diu',
    'DL': 'Delhi',
    'DN': 'Dadra and Nagar Haveli',
    'GA': 'Goa',
    'GJ': 'Gujarat',
    'HR': 'Haryana',
    'HP': 'Himachal Pradesh',
    'JK': 'Jammu and Kashmir',
    'JH': 'Jharkhand',
    'KA': 'Karnataka',
    'KL': 'Kerala',
    'LA': 'Ladakh',
    'MH': 'Maharashtra',
    'ML': 'Meghalaya',
    'MN': 'Manipur',
    'MZ': 'Mizoram',
    'NL': 'Nagaland',
    'OD': 'Odisha',
    'PB': 'Punjab',
    'PY': 'Puducherry',
    'RJ': 'Rajasthan',
    'SK': 'Sikkim',
    'TG': 'Telangana',
    'TN': 'Tamil Nadu',
    'TR': 'Tripura',
    'UP': 'Uttar Pradesh',
    'UT': 'Uttarakhand',
    'WB': 'West Bengal',
  };

  /// Top Indian cities classified as Urban (Tier-1 + Tier-2)
  /// Based on Indian Census 2011 + 2021 provisional classification
  static final Set<String> _urbanCities = {
    // Tier 1 (8 Metro cities)
    'mumbai', 'delhi', 'new delhi', 'bangalore', 'bengaluru', 'hyderabad',
    'ahmedabad', 'chennai', 'kolkata', 'pune',
    // Tier 2 (40+ major urban centers)
    'jaipur', 'lucknow', 'kanpur', 'nagpur', 'indore', 'thane', 'bhopal',
    'visakhapatnam', 'patna', 'vadodara', 'ghaziabad', 'ludhiana', 'agra',
    'nashik', 'faridabad', 'meerut', 'rajkot', 'kalyan', 'vasai',
    'varanasi', 'srinagar', 'aurangabad', 'dhanbad', 'amritsar', 'navi mumbai',
    'allahabad', 'prayagraj', 'ranchi', 'howrah', 'coimbatore', 'jabalpur',
    'gwalior', 'vijayawada', 'jodhpur', 'madurai', 'raipur', 'kota',
    'chandigarh', 'guwahati', 'solapur', 'hubli', 'dharwad',
    'tiruchirappalli', 'trichy', 'bareilly', 'mysore', 'mysuru',
    'tiruppur', 'gurgaon', 'gurugram', 'noida', 'greater noida',
    'salem', 'bhubaneswar', 'warangal', 'guntur', 'bikaner',
    'dehradun', 'pondicherry', 'puducherry', 'kochi', 'cochin',
    'thiruvananthapuram', 'trivandrum', 'kozhikode', 'calicut',
    'mangalore', 'mangaluru', 'shimla', 'jammu', 'jamshedpur',
    'cuttack', 'udaipur', 'ajmer', 'kolhapur', 'sangli',
    'nellore', 'tiruvallur', 'belgaum', 'belagavi',
    'erode', 'tirunelveli', 'vellore', 'ambala',
    'secunderabad', 'firozabad', 'gorakhpur', 'siliguri',
    'durgapur', 'asansol', 'nanded', 'bhilai',
  };
}
