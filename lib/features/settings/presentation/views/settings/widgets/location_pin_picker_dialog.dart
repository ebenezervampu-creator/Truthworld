import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/location/location_lookup_service.dart';
import 'package:truthworld/core/services/location/verified_location.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Pure Mercator projection calculations for slippy map tiles.
class MapMercatorProjection {
  static const double tileSize = 256.0;

  static double lonToX(double lon, int zoom) {
    final scale = tileSize * math.pow(2, zoom);
    return (lon + 180.0) / 360.0 * scale;
  }

  static double latToY(double lat, int zoom) {
    final scale = tileSize * math.pow(2, zoom);
    final sinLat = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
    final y = 0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi);
    return y * scale;
  }

  static double xToLon(double x, int zoom) {
    final scale = tileSize * math.pow(2, zoom);
    return (x / scale) * 360.0 - 180.0;
  }

  static double yToLat(double y, int zoom) {
    final scale = tileSize * math.pow(2, zoom);
    final n = math.pi - 2.0 * math.pi * (y / scale);
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }
}

/// Controller managing map center coordinates, zooming, dragging, and reverse-geocoding.
class LocationPinPickerController extends BaseController {
  LocationPinPickerController({
    double? initialLat,
    double? initialLon,
    VerifiedLocation? initialLocation,
  }) {
    if (initialLocation != null) {
      currentLocality.value = initialLocation;
      latitude.value = initialLocation.latitude;
      longitude.value = initialLocation.longitude;
      isEligibleSettlement.value = true;
    } else if (initialLat != null && initialLon != null) {
      latitude.value = initialLat;
      longitude.value = initialLon;
    }
  }

  final RxDouble latitude = 20.5937.obs; // Default to India center or global
  final RxDouble longitude = 78.9629.obs;
  final RxInt zoom = 12.obs;

  final Rx<VerifiedLocation?> currentLocality = Rx<VerifiedLocation?>(null);
  final RxBool isResolving = false.obs;
  final RxBool isEligibleSettlement = false.obs;
  final RxString resolveError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Reverse geocode whenever latitude or longitude changes, debounced
    debounce<double>(
      latitude,
      (_) => _reverseGeocodeCurrentPin(),
      time: const Duration(milliseconds: 400),
    );
    debounce<double>(
      longitude,
      (_) => _reverseGeocodeCurrentPin(),
      time: const Duration(milliseconds: 400),
    );

    // Initial lookup if not provided
    if (currentLocality.value == null) {
      _reverseGeocodeCurrentPin();
    }
  }

  Future<void> _reverseGeocodeCurrentPin() async {
    isResolving.value = true;
    resolveError.value = '';

    try {
      final loc = await LocationLookupService.reverseGeocode(
        latitude.value,
        longitude.value,
      );

      if (loc != null && loc.name.isNotEmpty && loc.country.isNotEmpty) {
        currentLocality.value = loc;
        isEligibleSettlement.value = true;
      } else {
        currentLocality.value = null;
        isEligibleSettlement.value = false;
        resolveError.value =
            'No town, city, or village found near this pin. Please move the pin closer to a residential locality.';
      }
    } catch (_) {
      isEligibleSettlement.value = false;
      resolveError.value = 'Unable to resolve nearby location. Please try panning closer.';
    } finally {
      isResolving.value = false;
    }
  }

  void pan(double deltaX, double deltaY) {
    final currentZ = zoom.value;
    final currentCenterX = MapMercatorProjection.lonToX(longitude.value, currentZ);
    final currentCenterY = MapMercatorProjection.latToY(latitude.value, currentZ);

    final newCenterX = currentCenterX - deltaX;
    final newCenterY = currentCenterY - deltaY;

    final newLon = MapMercatorProjection.xToLon(newCenterX, currentZ).clamp(-180.0, 180.0);
    final newLat = MapMercatorProjection.yToLat(newCenterY, currentZ).clamp(-85.0, 85.0);

    latitude.value = newLat;
    longitude.value = newLon;
  }

  void zoomIn() {
    if (zoom.value < 18) {
      zoom.value++;
    }
  }

  void zoomOut() {
    if (zoom.value > 3) {
      zoom.value--;
    }
  }

  Future<void> centerOnUserLocation() async {
    isResolving.value = true;
    try {
      final loc = await LocationLookupService.detectCurrentLocation();
      if (loc != null) {
        latitude.value = loc.latitude;
        longitude.value = loc.longitude;
        currentLocality.value = loc;
        isEligibleSettlement.value = true;
        zoom.value = 13;
      }
    } catch (_) {
      resolveError.value = 'Could not detect current location.';
    } finally {
      isResolving.value = false;
    }
  }
}

/// Interactive dialog for pinning a location on a map with real-time settlement verification.
class LocationPinPickerDialog extends StatelessWidget {
  const LocationPinPickerDialog({
    super.key,
    this.initialLat,
    this.initialLon,
    this.initialLocation,
  });

  final double? initialLat;
  final double? initialLon;
  final VerifiedLocation? initialLocation;

  static Future<VerifiedLocation?> show(
    BuildContext context, {
    double? initialLat,
    double? initialLon,
    VerifiedLocation? initialLocation,
  }) async {
    return Get.dialog<VerifiedLocation?>(
      LocationPinPickerDialog(
        initialLat: initialLat,
        initialLon: initialLon,
        initialLocation: initialLocation,
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tag = 'pin_picker_${DateTime.now().microsecondsSinceEpoch}';
    final controller = Get.put(
      LocationPinPickerController(
        initialLat: initialLat,
        initialLon: initialLon,
        initialLocation: initialLocation,
      ),
      tag: tag,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: context.colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pin_drop,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pin Location on Map',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      onPressed: () {
                        Get.delete<LocationPinPickerController>(tag: tag);
                        Get.back();
                      },
                    ),
                  ],
                ),
              ),

              // Interactive Map View
              SizedBox(
                height: 320,
                child: Stack(
                  children: [
                    // Slippy Map Tiles Layer
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Obx(() {
                            final lat = controller.latitude.value;
                            final lon = controller.longitude.value;
                            final z = controller.zoom.value;

                            final w = constraints.maxWidth;
                            final h = constraints.maxHeight;

                            final centerX = MapMercatorProjection.lonToX(lon, z);
                            final centerY = MapMercatorProjection.latToY(lat, z);

                            final tlX = centerX - w / 2;
                            final tlY = centerY - h / 2;

                            final minTileX = (tlX / MapMercatorProjection.tileSize).floor();
                            final maxTileX = ((tlX + w) / MapMercatorProjection.tileSize).floor();
                            final minTileY = (tlY / MapMercatorProjection.tileSize).floor();
                            final maxTileY = ((tlY + h) / MapMercatorProjection.tileSize).floor();

                            final numTiles = 1 << z;
                            final tiles = <Widget>[];

                            for (var tx = minTileX; tx <= maxTileX; tx++) {
                              for (var ty = minTileY; ty <= maxTileY; ty++) {
                                if (ty < 0 || ty >= numTiles) continue;
                                final wrappedTx = ((tx % numTiles) + numTiles) % numTiles;

                                final left = tx * MapMercatorProjection.tileSize - tlX;
                                final top = ty * MapMercatorProjection.tileSize - tlY;

                                final tileUrl = isDark
                                    ? 'https://a.basemaps.cartocdn.com/dark_all/$z/$wrappedTx/$ty.png'
                                    : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/$z/$wrappedTx/$ty.png';

                                tiles.add(
                                  Positioned(
                                    left: left,
                                    top: top,
                                    width: MapMercatorProjection.tileSize,
                                    height: MapMercatorProjection.tileSize,
                                    child: CachedNetworkImage(
                                      imageUrl: tileUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                                      ),
                                      errorWidget: (context, url, err) => Container(
                                        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[300],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }

                            return GestureDetector(
                              onPanUpdate: (details) {
                                controller.pan(details.delta.dx, details.delta.dy);
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    color: isDark ? const Color(0xFF121212) : Colors.grey[100],
                                    child: Stack(children: tiles),
                                  ),
                                ],
                              ),
                            );
                          });
                        },
                      ),
                    ),

                    // Center Map Pin Marker
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0), // Pin tip at exact center
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 42,
                              color: Color(0xFFEF4444),
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            Container(
                              width: 8,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Map Zoom & GPS Floating Buttons
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMapIconButton(
                            icon: Icons.add,
                            tooltip: 'Zoom In',
                            onTap: controller.zoomIn,
                          ),
                          const SizedBox(height: 6),
                          _buildMapIconButton(
                            icon: Icons.remove,
                            tooltip: 'Zoom Out',
                            onTap: controller.zoomOut,
                          ),
                          const SizedBox(height: 10),
                          _buildMapIconButton(
                            icon: Icons.my_location,
                            tooltip: 'My Location',
                            onTap: controller.centerOnUserLocation,
                          ),
                        ],
                      ),
                    ),

                    // Attribution
                    Positioned(
                      bottom: 4,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '© CARTO © OpenStreetMap',
                          style: TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Pin Resolution Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.bgDivider),
                    bottom: BorderSide(color: AppColors.bgDivider),
                  ),
                ),
                child: Obx(() {
                  if (controller.isResolving.value) {
                    return Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Locating nearest town, city, or village...',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }

                  if (controller.isEligibleSettlement.value &&
                      controller.currentLocality.value != null) {
                    final loc = controller.currentLocality.value!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                loc.typeLabel,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.formattedAddress,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${controller.latitude.value.toStringAsFixed(4)}°, ${controller.longitude.value.toStringAsFixed(4)}°',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          controller.resolveError.value.isNotEmpty
                              ? controller.resolveError.value
                              : 'No town, city, or village found near this pin. Please pan closer to an inhabited locality.',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.amber[200],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Get.delete<LocationPinPickerController>(tag: tag);
                        Get.back();
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.roboto(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Obx(() {
                      final canConfirm = controller.isEligibleSettlement.value &&
                          controller.currentLocality.value != null &&
                          !controller.isResolving.value;

                      return ElevatedButton(
                        onPressed: canConfirm
                            ? () {
                                final loc = controller.currentLocality.value!;
                                Get.delete<LocationPinPickerController>(tag: tag);
                                Get.back(result: loc);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black, // Rule: Black on white surface
                          disabledBackgroundColor: Colors.white24,
                          disabledForegroundColor: Colors.white38,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Confirm & Pin Location',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: canConfirm ? Colors.black : Colors.white38,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}
