import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrashRestoreScreen extends StatefulWidget {
  final String channelId;
  final bool isDarkMode;

  const TrashRestoreScreen({
    super.key,
    required this.channelId,
    required this.isDarkMode,
  });

  @override
  State<TrashRestoreScreen> createState() => _TrashRestoreScreenState();
}

class _TrashRestoreScreenState extends State<TrashRestoreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter =
      'All'; // 'All', 'Channel', 'Video', 'Topic', 'Playlist'
  bool _isLoading = false;

  // Local lists of deleted items
  List<Map<String, dynamic>> _trashItems = [];

  @override
  void initState() {
    super.initState();
    _loadTrashItems();
  }

  Future<void> _loadTrashItems() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<Map<String, dynamic>> loadedItems = [];

      // 1. Check if the current channel itself is deletion_pending
      if (widget.channelId.isNotEmpty) {
        final channelSnap = await _firestore
            .collection('channels')
            .doc(widget.channelId)
            .get();
        if (channelSnap.exists) {
          final data = channelSnap.data();
          if (data != null && data['status'] == 'deletion_pending') {
            loadedItems.add({
              'id': channelSnap.id,
              'type': 'Channel',
              'title':
                  data['channelName'] ?? data['name'] ?? 'Untitled Channel',
              'imageUrl': data['avatarUrl'] ?? '',
              'deletedAt':
                  (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              'ref': channelSnap.reference,
            });
          }
        }
      }

      // 2. Fetch deleted videos belonging to this channel
      if (widget.channelId.isNotEmpty) {
        final videosSnap = await _firestore
            .collection('videos')
            .where('channelId', isEqualTo: widget.channelId)
            .where('status', isEqualTo: 'deletion_pending')
            .get();

        for (var doc in videosSnap.docs) {
          final data = doc.data();
          loadedItems.add({
            'id': doc.id,
            'type': 'Video',
            'title': data['title'] ?? 'Untitled Video',
            'imageUrl': data['thumbnailUrl'] ?? '',
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // 3. Fetch deleted topics belonging to this channel
      if (widget.channelId.isNotEmpty) {
        final topicsSnap = await _firestore
            .collection('topics')
            .where('channelId', isEqualTo: widget.channelId)
            .where('status', isEqualTo: 'deletion_pending')
            .get();

        for (var doc in topicsSnap.docs) {
          final data = doc.data();
          loadedItems.add({
            'id': doc.id,
            'type': 'Topic',
            'title': data['title'] ?? 'Untitled Topic',
            'imageUrl': data['thumbnailUrl'] ?? '',
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // 4. Fetch deleted playlists belonging to this channel
      if (widget.channelId.isNotEmpty) {
        final playlistsSnap = await _firestore
            .collection('playlists')
            .where('channelId', isEqualTo: widget.channelId)
            .where('status', isEqualTo: 'deletion_pending')
            .get();

        for (var doc in playlistsSnap.docs) {
          final data = doc.data();
          loadedItems.add({
            'id': doc.id,
            'type': 'Playlist',
            'title': data['name'] ?? 'Untitled Playlist',
            'imageUrl': data['thumbnailUrl'] ?? '',
            'deletedAt':
                (data['deletionRequestedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            'ref': doc.reference,
          });
        }
      }

      // Sort by deletion requested time (newest deleted first)
      loadedItems.sort(
        (a, b) =>
            (b['deletedAt'] as DateTime).compareTo(a['deletedAt'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _trashItems = loadedItems;
        });
      }
    } catch (e) {
      debugPrint('Error loading trash items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreItem(Map<String, dynamic> item) async {
    final docRef = item['ref'] as DocumentReference;
    final type = item['type'] as String;

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      barrierDismissible: false,
    );

    try {
      final Map<String, dynamic> updateFields = {
        'deletionRequestedAt': FieldValue.delete(),
      };

      if (type == 'Channel') {
        updateFields['status'] = 'active';
      } else if (type == 'Video') {
        updateFields['status'] = 'ready';
      } else if (type == 'Topic') {
        updateFields['status'] = 'active';
        updateFields['visibilityType'] = 'public';
      } else if (type == 'Playlist') {
        updateFields['status'] = 'active';
      }

      await docRef.update(updateFields);

      // Close loading dialog
      Get.back();

      AppSnackbar.show(
        'Item Restored',
        '${item['title']} has been successfully restored.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Reload list
      _loadTrashItems();
    } catch (e) {
      Get.back(); // Close loading dialog
      AppSnackbar.show(
        'Restoration Failed',
        'Failed to restore item: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  int _getRemainingDays(DateTime deletedAt) {
    final difference = DateTime.now().difference(deletedAt);
    final remaining = 30 - difference.inDays;
    return remaining.clamp(0, 30);
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _trashItems.where((item) {
      if (_selectedFilter == 'All') return true;
      return item['type'] == _selectedFilter;
    }).toList();

    return Container(
      color: widget.isDarkMode ? AppColors.bgPage : AppColors.bgPage,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trash & Restoration',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deleted channels, videos, topics, and playlists are retained for 30 days before permanent deletion.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: widget.isDarkMode
                          ? Colors.white60
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: _loadTrashItems,
                tooltip: 'Refresh Trash Bin',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters Row
          _buildFiltersRow(),
          const SizedBox(height: 16),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  )
                : filteredList.isEmpty
                ? _buildEmptyState()
                : _buildTrashItemsList(filteredList),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    final filters = ['All', 'Channel', 'Video', 'Topic', 'Playlist'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                }
              },
              selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected ? const Color(0xFF6366F1) : Colors.white24,
                width: 1,
              ),
              backgroundColor: Colors.transparent,
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                color: isSelected ? const Color(0xFF818CF8) : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 72,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Trash is Empty',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No recently deleted items match the selected filter.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashItemsList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final type = item['type'] as String;
        final title = item['title'] as String;
        final imageUrl = item['imageUrl'] as String;
        final deletedAt = item['deletedAt'] as DateTime;
        final remainingDays = _getRemainingDays(deletedAt);

        // Icon based on type
        IconData typeIcon = Icons.video_library_rounded;
        Color typeColor = Colors.teal;
        if (type == 'Channel') {
          typeIcon = Icons.account_box_rounded;
          typeColor = Colors.indigo;
        } else if (type == 'Topic') {
          typeIcon = Icons.topic_rounded;
          typeColor = Colors.amber;
        } else if (type == 'Playlist') {
          typeIcon = Icons.playlist_play_rounded;
          typeColor = Colors.purple;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDarkMode ? Colors.white12 : Colors.black12,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Image / Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 48,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.white12),
                          errorWidget: (context, url, error) => Container(
                            color: typeColor.withValues(alpha: 0.1),
                            child: Icon(typeIcon, color: typeColor, size: 24),
                          ),
                        )
                      : Container(
                          color: typeColor.withValues(alpha: 0.1),
                          child: Icon(typeIcon, color: typeColor, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Title and Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Deleted on ${DateFormat('MMM d, yyyy').format(deletedAt)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: widget.isDarkMode
                                ? Colors.white38
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$remainingDays days left before permanent deletion',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: remainingDays <= 5
                            ? Colors.redAccent
                            : Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Restore Button
              TextButton.icon(
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Restore'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF818CF8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF6366F1), width: 1),
                  ),
                ),
                onPressed: () => _restoreItem(item),
              ),
            ],
          ),
        );
      },
    );
  }
}
