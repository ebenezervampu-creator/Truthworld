/// Configuration and permission evaluation for TruthWorld administrative roles.
class AdminRolesConfig {
  static const String ownerEmail = String.fromEnvironment(
    'ADMIN_OWNER_EMAIL',
    defaultValue: 'hello@truthworld.in',
  );

  static const List<String> authorizedOwnerEmails = [
    'hello@truthworld.in',
    'ebenezervampu4@gmail.com',
    'admin@truthworld.com',
    String.fromEnvironment('ADMIN_OWNER_EMAIL', defaultValue: 'hello@truthworld.in'),
    String.fromEnvironment('ADMIN_SECONDARY_EMAIL', defaultValue: 'hello@truthworld.in'),
  ];

  /// List of all 8 standard admin roles with their allowed tabs and descriptions
  static const List<Map<String, dynamic>> availableRoles = [
    {
      'name': 'Super Admin',
      'description': 'Full unrestricted master access to all tabs, queues, actions, and team management.',
      'tabs': [
        'dashboard',
        'videos',
        'topics',
        'images',
        'channels',
        'reports',
        'logs',
        'users',
        'team',
        'ads',
        'ad_reports',
        'analytics',
        'appeals',
        'feedbacks',
        'alerts',
        'security',
        'help',
      ],
    },
    {
      'name': 'Content Moderator',
      'description': 'Review and approve/reject Video Queue, Topics Queue, Image Posts, and Channel reviews.',
      'tabs': ['dashboard', 'videos', 'topics', 'images', 'channels'],
    },
    {
      'name': 'Trust & Safety Reviewer',
      'description': 'Process user-submitted Video Reports, User Appeals, and community Feedbacks.',
      'tabs': ['reports', 'appeals', 'feedbacks'],
    },
    {
      'name': 'User Manager',
      'description': 'Inspect registered user accounts, manage bans, suspensions, and safety profiles.',
      'tabs': ['users'],
    },
    {
      'name': 'Advertising Manager',
      'description': 'Review and moderate Advertiser Campaigns and dispute Reports.',
      'tabs': ['ads', 'ad_reports'],
    },
    {
      'name': 'Audit & Compliance Officer',
      'description': 'Review Quarantined Audit Logs, Security Lockdowns, and System Alerts.',
      'tabs': ['logs', 'security', 'alerts'],
    },
    {
      'name': 'Analytics & Performance',
      'description': 'View platform Analytics and Overview health dashboard metrics.',
      'tabs': ['dashboard', 'analytics'],
    },
    {
      'name': 'Team Manager',
      'description': 'Manage team members, create credentials, and assign access roles.',
      'tabs': ['team'],
    },
  ];

  static const List<String> allRoleNames = [
    'Super Admin',
    'Content Moderator',
    'Trust & Safety Reviewer',
    'User Manager',
    'Advertising Manager',
    'Audit & Compliance Officer',
    'Analytics & Performance',
    'Team Manager',
  ];

  /// Checks whether a given tab ID is allowed for the specified administrator
  static bool isTabAllowed({
    required String tabId,
    required bool isAdmin,
    required bool isPrimaryOwner,
    required String currentAdminEmail,
    required String currentAdminRole,
    required List<String> currentAdminRoles,
  }) {
    if (!isAdmin) return false;

    // Language requests queue is exclusively for the primary platform owner ("only me")
    if (tabId == 'language_requests') {
      return isPrimaryOwner;
    }

    // Help tab is universally accessible to any logged-in administrator
    if (tabId == 'help') return true;

    final email = currentAdminEmail.toLowerCase();
    // Primary authorized owners always have full access to everything
    if (authorizedOwnerEmails.contains(email)) return true;

    // Check if roles include Super Admin
    if (currentAdminRoles.any((r) => r.toLowerCase().contains('super') || r.toLowerCase().contains('owner'))) {
      return true;
    }
    if (currentAdminRole.toLowerCase().contains('super') || currentAdminRole.toLowerCase().contains('owner')) {
      return true;
    }

    final allowed = getAllowedTabs(
      isPrimaryOwner: isPrimaryOwner,
      currentAdminEmail: currentAdminEmail,
      currentAdminRole: currentAdminRole,
      currentAdminRoles: currentAdminRoles,
    );
    return allowed.contains(tabId);
  }

  /// Returns the set of all tab IDs allowed for the administrator
  static Set<String> getAllowedTabs({
    required bool isPrimaryOwner,
    required String currentAdminEmail,
    required String currentAdminRole,
    required List<String> currentAdminRoles,
  }) {
    final email = currentAdminEmail.toLowerCase();
    if (isPrimaryOwner) {
      return {
        'dashboard', 'videos', 'topics', 'images', 'channels', 'reports', 'logs',
        'users', 'team', 'ads', 'ad_reports', 'analytics', 'appeals', 'feedbacks',
        'alerts', 'security', 'help', 'language_requests',
      };
    }

    if (authorizedOwnerEmails.contains(email)) {
      return {
        'dashboard', 'videos', 'topics', 'images', 'channels', 'reports', 'logs',
        'users', 'team', 'ads', 'ad_reports', 'analytics', 'appeals', 'feedbacks',
        'alerts', 'security', 'help',
      };
    }

    if (currentAdminRoles.any((r) => r.toLowerCase().contains('super') || r.toLowerCase().contains('owner')) ||
        currentAdminRole.toLowerCase().contains('super') ||
        currentAdminRole.toLowerCase().contains('owner')) {
      return {
        'dashboard', 'videos', 'topics', 'images', 'channels', 'reports', 'logs',
        'users', 'team', 'ads', 'ad_reports', 'analytics', 'appeals', 'feedbacks',
        'alerts', 'security', 'help',
      };
    }

    final allowed = <String>{'help'};

    void addTabsForRole(String roleStr) {
      final r = roleStr.toLowerCase().trim();
      if (r.contains('super') || r.contains('owner')) {
        allowed.addAll([
          'dashboard', 'videos', 'topics', 'images', 'channels', 'reports', 'logs',
          'users', 'team', 'ads', 'ad_reports', 'analytics', 'appeals', 'feedbacks',
          'alerts', 'security', 'help'
        ]);
        return;
      }
      if (r.contains('content') || r.contains('moderator') || r.contains('queue')) {
        allowed.addAll(['dashboard', 'videos', 'topics', 'images', 'channels']);
      }
      if (r.contains('trust') || r.contains('safety') || r.contains('support') || r.contains('appeal')) {
        allowed.addAll(['reports', 'appeals', 'feedbacks']);
      }
      if (r.contains('user')) {
        allowed.add('users');
      }
      if (r.contains('ad') || r.contains('campaign')) {
        allowed.addAll(['ads', 'ad_reports']);
      }
      if (r.contains('audit') || r.contains('compliance') || r.contains('security') || r.contains('alert')) {
        allowed.addAll(['logs', 'security', 'alerts']);
      }
      if (r.contains('analytics') || r.contains('performance')) {
        allowed.addAll(['dashboard', 'analytics']);
      }
      if (r.contains('team')) {
        allowed.add('team');
      }
    }

    currentAdminRoles.forEach(addTabsForRole);
    if (currentAdminRole.isNotEmpty) {
      addTabsForRole(currentAdminRole);
    }

    if (allowed.isEmpty) {
      allowed.add('dashboard');
    }
    return allowed;
  }
}
