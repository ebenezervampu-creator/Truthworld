import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class GeographicMapController extends BaseController {
  final selectedMarker = Rx<MapMarker?>(null);

  void toggleMarker(MapMarker marker) {
    if (selectedMarker.value?.name == marker.name) {
      selectedMarker.value = null;
    } else {
      selectedMarker.value = marker;
    }
  }
}

class GeographicMapWidget extends StatelessWidget {
  const GeographicMapWidget({required this.controller, super.key});
  final CreatorAnalyticsController controller;

  // Enter Google Maps API key here if available
  static const String googleMapsApiKey = '';

  @override
  Widget build(BuildContext context) {
    final mapController = Get.find<GeographicMapController>();

    return Obx(() {
      final isStates = controller.selectedGeoTab.value == 'states';
      final markers = <MapMarker>[];

      if (isStates) {
        for (final state in controller.topStates) {
          final coords = controller.getCoordinates(state.stateName);
          if (coords != null && coords.length == 2) {
            markers.add(
              MapMarker(
                name: state.stateName,
                lat: coords[0],
                lon: coords[1],
                views: state.viewCount,
                percentage: state.percentage,
              ),
            );
          }
        }
      } else {
        for (final country in controller.topCountries) {
          final coords = controller.getCoordinates(country.countryName);
          if (coords != null && coords.length == 2) {
            markers.add(
              MapMarker(
                name: country.countryName,
                lat: coords[0],
                lon: coords[1],
                views: country.viewCount,
                percentage: country.percentage,
              ),
            );
          }
        }
      }

      final hasApiKey = googleMapsApiKey.isNotEmpty;

      return Container(
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isStates ? 'State Traffic Map' : 'Global Traffic Map',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasApiKey
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasApiKey ? 'Google Maps' : 'Satellite View',
                    style: TextStyle(
                      color: hasApiKey ? AppColors.success : AppColors.info,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: hasApiKey
                    ? _buildGoogleStaticMap(markers)
                    : _buildVectorMapFallback(markers, mapController),
              ),
            ),
            if (mapController.selectedMarker.value != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mapController.selectedMarker.value!.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${mapController.selectedMarker.value!.views} Views',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${mapController.selectedMarker.value!.percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildGoogleStaticMap(List<MapMarker> markers) {
    if (markers.isEmpty) {
      return const Center(
        child: Text(
          'No geographic points to plot',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
      );
    }

    const base = 'https://maps.googleapis.com/maps/api/staticmap';
    const size = '600x200';
    const maptype = 'roadmap';

    // Styled dark theme
    const style =
        'style=feature:all|element:geometry|color:0x212121&'
        'style=feature:all|element:labels.text.stroke|color:0x212121&'
        'style=feature:all|element:labels.text.fill|color:0x747474&'
        'style=feature:administrative|element:geometry|color:0x757575&'
        'style=feature:landscape|element:geometry|color:0x1e1e1e&'
        'style=feature:poi|element:geometry|color:0x1e1e1e&'
        'style=feature:road|element:geometry|color:0x2c2c2c&'
        'style=feature:water|element:geometry|color:0x000000';

    final markersParam = markers
        .map((m) {
          return 'markers=color:0xDC2626|label:${m.name.substring(0, 1).toUpperCase()}|${m.lat},${m.lon}';
        })
        .join('&');

    final url =
        '$base?size=$size&maptype=$maptype&key=$googleMapsApiKey&$style&$markersParam';

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => const ColoredBox(
        color: Colors.black26,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) =>
          _buildVectorMapFallback(markers, Get.find<GeographicMapController>()),
    );
  }

  Widget _buildVectorMapFallback(
    List<MapMarker> markers,
    GeographicMapController mapController,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          children: [
            // World Map Background Image
            Positioned.fill(
              child: Opacity(
                opacity: 0.85,
                child: Image.asset(
                  'assets/dark_world_map.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: Icon(
                          Icons.map_outlined,
                          color: AppColors.textDisabled,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Map markers overlay
            ...markers.map((marker) {
              final pos = _getMapPosition(
                marker.lat,
                marker.lon,
                width,
                height,
              );
              final isSelected =
                  mapController.selectedMarker.value?.name == marker.name;

              return Positioned(
                left: pos.dx - 12,
                top: pos.dy - 12,
                child: GestureDetector(
                  onTap: () {
                    mapController.toggleMarker(marker);
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing outer ring
                      Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(
                                0xFFDC2626,
                              ).withValues(alpha: isSelected ? 0.4 : 0.2),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .scale(
                            duration: const Duration(milliseconds: 1500),
                            begin: const Offset(0.7, 0.7),
                            end: const Offset(1.5, 1.5),
                            curve: Curves.easeOut,
                          )
                          .fade(
                            duration: const Duration(milliseconds: 1500),
                            begin: 1,
                            end: 0,
                            curve: Curves.easeOut,
                          ),

                      // Solid center pin
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.textPrimary
                              : const Color(0xFFDC2626),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFDC2626)
                                : AppColors.textPrimary,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFDC2626,
                              ).withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            if (markers.isEmpty)
              const Positioned.fill(
                child: Center(
                  child: Text(
                    'No traffic points to show',
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Offset _getMapPosition(double lat, double lon, double width, double height) {
    // Map longitude (-180 to 180) to X (0 to width)
    final x = ((lon + 180) / 360) * width;

    // Map latitude (-50 to 75) to Y (height to 0) to fit standard world maps
    const minLat = -50;
    const maxLat = 75;
    final latPercent = (lat - minLat) / (maxLat - minLat);
    final y = (1.0 - latPercent.clamp(0.0, 1.0)) * height;

    return Offset(x, y);
  }
}

class MapMarker {
  MapMarker({
    required this.name,
    required this.lat,
    required this.lon,
    required this.views,
    required this.percentage,
  });
  final String name;
  final double lat;
  final double lon;
  final int views;
  final double percentage;
}
