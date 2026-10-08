/// Model for determining sidebar item visibility based on authentication status.
class HomeSidebarVisibility {
  const HomeSidebarVisibility._();

  static List<String> getVisibleEntries({required bool isAuthenticated}) {
    final publicEntries = <String>[
      'Home',
      'Discover Channel',
      'Explore Topics',
      'Help Center',
      'Feedback',
      'About Truthworld',
      'Privacy Policy',
      'Terms & Conditions',
      'Community Guidelines',
      'Truthworld Studio',
    ];

    if (!isAuthenticated) {
      return publicEntries;
    }

    return [
      ...publicEntries,
      'Settings',
      'Subscriptions',
      'Your channel',
      'History',
      'Playlists',
      'Following Topics',
      'Watch later',
      'Liked videos',
      'Your videos',
      'Your Clips',
      'Downloads',
      'Interacted Ads',
    ];
  }
}
