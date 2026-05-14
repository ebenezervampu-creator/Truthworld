import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';

class DraftsScreen extends StatelessWidget {
  final String channelId;
  final bool isDarkMode;

  const DraftsScreen({
    super.key,
    required this.channelId,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("You must be logged in."));
    }

    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: AppTheme.colors.background,
              child: TabBar(
                indicatorColor: AppTheme.colors.textSecondary,
                labelColor: AppTheme.colors.textSecondary,
                unselectedLabelColor: AppTheme.colors.textSecondary,
                tabs: const [
                  Tab(text: 'Video Drafts'),
                  Tab(text: 'Community Drafts'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Center(
                    child: Text(
                      'Video drafts coming soon',
                      style: GoogleFonts.roboto(
                        color: AppTheme.colors.textSecondary,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Community drafts coming soon',
                      style: GoogleFonts.roboto(
                        color: AppTheme.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}





