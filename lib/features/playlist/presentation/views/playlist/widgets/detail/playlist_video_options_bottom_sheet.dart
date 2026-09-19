import 'package:flutter/material.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_constants.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Modal bottom sheet providing video contextual actions (play next, add to queue, download, share).
class PlaylistVideoOptionsBottomSheet extends StatelessWidget {
  const PlaylistVideoOptionsBottomSheet({
    required this.video,
    super.key,
  });

  final Video video;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ytSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ytTextTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.play_arrow, color: Colors.white),
            title: const Text(
              'Play next',
              style: TextStyle(color: ytTextPrimary),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white),
            title: const Text(
              'Add to queue',
              style: TextStyle(color: ytTextPrimary),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.white),
            title: const Text(
              'Download',
              style: TextStyle(color: ytTextPrimary),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white),
            title: const Text(
              'Share',
              style: TextStyle(color: ytTextPrimary),
            ),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
}

void showPlaylistVideoOptions(BuildContext context, Video video) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ytSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (context) => PlaylistVideoOptionsBottomSheet(video: video),
  );
}
