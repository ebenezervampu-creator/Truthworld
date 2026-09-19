import 'package:flutter/material.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Direct links and stored artifact download panel.
class PipelineArtifactLinksPanel extends StatelessWidget {
  const PipelineArtifactLinksPanel({
    required this.video,
    super.key,
  });

  final Video video;

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    try {
      final url = Uri.parse(urlString);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'PipelineArtifactLinks._launchURL',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (video.transcriptionUrl.isNotEmpty)
              PipelineActionButton(
                icon: Icons.description_outlined,
                label: 'Transcript JSON',
                onPressed: () => _launchURL(video.transcriptionUrl),
              ),
            if (video.factCheckUrl.isNotEmpty)
              PipelineActionButton(
                icon: Icons.fact_check_outlined,
                label: 'Fact-Check Report',
                onPressed: () => _launchURL(video.factCheckUrl),
              ),
            if (video.mediaSubtitles.isNotEmpty)
              ...video.mediaSubtitles.entries.map((entry) {
                return PipelineActionButton(
                  icon: Icons.subtitles_outlined,
                  label: 'SRT/VTT (${entry.key.toUpperCase()})',
                  onPressed: () => _launchURL(entry.value),
                );
              }),
            if (video.audioTracks.isNotEmpty)
              ...video.audioTracks.entries.map((entry) {
                return PipelineActionButton(
                  icon: Icons.audiotrack_outlined,
                  label: 'Audio (${entry.key.toUpperCase()})',
                  onPressed: () => _launchURL(entry.value),
                );
              }),
            if (video.resolutions.isNotEmpty)
              ...video.adaptiveResolutions.map((res) {
                return PipelineActionButton(
                  icon: Icons.hd_outlined,
                  label: '${res.label} Direct Link',
                  onPressed: () => _launchURL(res.url),
                );
              }),
          ],
        ),
      ],
    );
  }
}

/// Action button for launching external pipeline URLs with standard styling.
class PipelineActionButton extends StatelessWidget {
  const PipelineActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.bgSurfaceHover,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(
            color: AppColors.bgDivider,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
