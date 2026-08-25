import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// A simple class to hold our parsed policy sections
class PolicySection {
  PolicySection({
    required this.title,
    required this.content,
    required this.key,
  });
  final String title;
  final String content;
  final GlobalKey key;
}

class PrivacyPolicyScreen extends StatelessWidget {
  PrivacyPolicyScreen({super.key, this.isDashboard = false}) {
    _parsePolicyText();
  }
  final bool isDashboard;

  final ScrollController _scrollController = ScrollController();
  final RxList<PolicySection> _sections = <PolicySection>[].obs;
  final RxString _introContent = ''.obs;

  /// Parses the giant text string into a structured list of sections.
  /// This allows us to build the nav menu and content separately.
  void _parsePolicyText() {
    // Regex to find headings like "1. INTRODUCTION" or "10. CHILDREN'S PRIVACY"
    final regex = RegExp(r'\n(\d{1,2}\. [A-Z_ ]+)\n', multiLine: true);
    final matches = regex.allMatches(_privacyPolicyText).toList();

    if (matches.isEmpty) {
      _introContent.value = _privacyPolicyText;
      return;
    }

    // Get the intro text before the first heading
    final firstMatch = matches.first;
    final introContent = _privacyPolicyText
        .substring(0, firstMatch.start)
        .trim();

    // Loop through all matches to create sections
    final tempSections = <PolicySection>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final title = match
          .group(1)!
          .trim(); // The heading, e.g., "1. INTRODUCTION"

      // Get the content between this heading and the next one
      final contentStart = match.end;
      final contentEnd = (i + 1 < matches.length)
          ? matches[i + 1].start
          : _privacyPolicyText.length;

      final content = _privacyPolicyText
          .substring(contentStart, contentEnd)
          .trim();

      tempSections.add(
        PolicySection(title: title, content: content, key: GlobalKey()),
      );
    }

    _introContent.value = introContent;
    _sections.value = tempSections;
  }

  /// Scrolls the view to the widget associated with the given GlobalKey
  void _scrollToSection(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Builds the left-hand navigation menu
  Widget _buildNavigationMenu(BuildContext context, {bool isDrawer = false}) {
    return Container(
      width: 280, // Fixed width for the nav menu
      // Use theme's scaffoldBackgroundColor or surface color for the menu
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          children: [
            ..._sections.map((section) {
              return ListTile(
                title: Text(
                  section.title,
                  style: const TextStyle(fontSize: 14),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                dense: true,
                onTap: () {
                  _scrollToSection(section.key);
                  if (isDrawer) {
                    Navigator.pop(context); // Close the drawer if it's a drawer
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Builds the main content area that displays the policy text
  Widget _buildContentArea(BuildContext context) {
    final bodyTextStyle = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: Theme.of(context).textTheme.bodyMedium?.color,
    );
    final headingTextStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).textTheme.titleLarge?.color,
    );

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Render the introductory text first
            SelectableText(_introContent.value, style: bodyTextStyle),
            const SizedBox(height: 24),
            // Then render all the numbered sections
            ..._sections.map((section) {
              // Each section is wrapped in a KeyedSubtree so we can scroll to it
              return Padding(
                key: section.key, // This key is crucial for scrolling
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(section.title, style: headingTextStyle),
                    const SizedBox(height: 12),
                    SelectableText(section.content, style: bodyTextStyle),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a breakpoint to decide which layout to show
        const breakpoint = 700;
        final isDesktop = constraints.maxWidth >= breakpoint;

        return Scaffold(
          appBar: AppBar(
            // Use theme-aware colors for a clean look
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 1,
            shadowColor: AppColors.bgPage.withValues(alpha: 0.1),
            leading: (isDashboard || isDesktop)
                ? IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () {
                      if (isDashboard) {
                        Get.find<HomeController>().sideNavSelectedIndex.value =
                            HomeController.indexSettings;
                      } else {
                        Get.back();
                      }
                    },
                  )
                : null,
            title: Text(
              'Privacy Policy | Truthworld',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.toNamed('/terms');
                },
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          // Show the drawer ONLY on mobile
          drawer: isDesktop
              ? null
              : Drawer(child: _buildNavigationMenu(context, isDrawer: true)),
          body: isDesktop
              ? Row(
                  // Desktop Layout (like the image)
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNavigationMenu(context),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: _buildContentArea(context)),
                  ],
                )
              : _buildContentArea(context), // Mobile Layout (just content)
        );
      },
    );
  }

  // Original policy text (unchanged)
  static const String _privacyPolicyText = """
PRIVACY POLICY

Last Updated: April 04, 2026
Effective Date: April 04, 2026

1. INTRODUCTION

Welcome to Truthworld ("we," "our," "us," or the "Platform"). We are committed to protecting your privacy and ensuring transparency about how we collect, use, store, and share your personal information.

This Privacy Policy applies to all users and visitors of our video-sharing platform, including content creators, viewers, and anyone who interacts with our services through our website, mobile applications, and associated platforms.

By using Truthworld, you agree to the collection and use of information in accordance with this Privacy Policy. If you do not agree with our policies and practices, please do not use our services.

2. INFORMATION WE COLLECT

We collect several types of information to provide and improve our services:

2.1 Personal Information You Provide

When you create an account or use our services, we may collect:
• Full name and username
• Email address
• Phone number (optional)
• Age group and gender preferences (optional)
• Displayed location (city, state, country - optional)
• Password (encrypted)
• Profile picture and cover photo
• Payment information (credit card, billing address) when you make purchases
• Communication preferences and notification settings

2.2 User-Generated Content

When you upload, share, or interact with content on our Platform:
• Videos, images, audio files, and other media you upload
• Comments, likes, and other interactions on videos
• Descriptions, titles, tags, and metadata associated with your content
• Messages sent through our platform
• Community posts and forum contributions
• Live stream content and chat messages

Please note: Content you share publicly may be viewed, copied, and redistributed by other users and third parties.

2.3 Automatically Collected & Approximate Location Information

We automatically collect certain information when you use our Platform:
• IP address and approximate location information (city, state, country) derived via IP lookup or Google account integration. We treat IP-based location strictly as approximate, as network geolocations can be imprecise.
• Device type, operating system, and browser type
• Unique device identifiers
• Viewing history and watch time
• Search queries and browsing behavior
• Click patterns and feature usage
• Network connection type
• Performance data and crash reports
• Referral URLs and page interactions

2.4 Google Sign-In & Integration Scopes

When you sign in using Google, we request only minimal, necessary OAuth permissions:
• Email and Profile info (`userinfo.email`, `userinfo.profile`): To create and authenticate your account.
• Addresses/Location scope (`user.addresses.read`): Requested solely to pre-fill your approximate city and country during sign-in so you do not have to enter it manually. 

Why We Request Location: We use approximate location to personalize video recommendations, display relevant local content, and improve platform performance. We do NOT track precise GPS coordinates, nor do we request broader Google scopes than necessary.

User Location Control: You have complete control over your displayed location. You can view, edit, or completely remove your location at any time directly in your account Settings under "Edit Profile."

2.5 Cookies and Tracking Technologies

We use cookies, web beacons, pixels, and similar technologies to:
• Maintain your login session
• Remember your preferences
• Analyze usage patterns and trends
• Deliver personalized content and advertisements
• Measure the effectiveness of our services

For more details, see Section 8 (Cookies and Tracking).

3. HOW WE USE YOUR INFORMATION

We use collected information for the following purposes:

3.1 Service Provision and Improvement
• Create and manage your account
• Deliver requested content and features
• Personalize your experience and recommendations
• Improve Platform functionality and user interface
• Develop new features and services
• Conduct research and analytics

3.2 Communication
• Send transactional emails (account verification, password resets)
• Provide customer support and respond to inquiries
• Send notifications about your account activity
• Deliver promotional messages (with your consent)
• Share updates about policy changes and new features

3.3 Content Moderation and Safety
• Monitor compliance with our Terms of Service and Community Guidelines
• Detect and prevent fraud, abuse, and illegal activities
• Enforce intellectual property rights
• Respond to reports of inappropriate content

3.4 Advertising and Marketing
• Display targeted advertisements based on your interests
• Measure advertising effectiveness
• Conduct market research
• Promote our services and partnerships

3.5 Legal Compliance
• Comply with legal obligations and court orders
• Protect our legal rights and interests
• Enforce our agreements and policies

4. SHARING OF INFORMATION

We may share your information in the following circumstances:

4.1 Third-Party Service Providers

We share data with trusted vendors who provide services on our behalf:
• Cloud storage providers (AWS, Google Cloud, Firebase)
• Payment processors (Stripe, PayPal)
• Analytics services (Google Analytics, Firebase Analytics)
• Content delivery networks (CDNs)
• Email service providers
• Customer support platforms

These providers are contractually obligated to protect your information and use it only for specified purposes.

4.2 Advertisers and Marketing Partners

With your consent, we may share:
• Aggregated and anonymized usage statistics
• Demographic information for targeted advertising
• Cookie identifiers for ad personalization

We do not sell personally identifiable information to advertisers without explicit consent.

4.3 Legal Requirements

We may disclose information when required to:
• Comply with legal processes (subpoenas, court orders)
• Respond to government requests
• Enforce our Terms of Service
• Protect the rights, property, or safety of Truthworld, users, or the public
• Prevent fraud or security threats

4.4 Business Transfers

If Truthworld is involved in a merger, acquisition, bankruptcy, or sale of assets, your information may be transferred to the acquiring entity. We will notify you before your information is transferred and becomes subject to a different privacy policy.

4.5 Public Information

Content you choose to share publicly (videos, comments, profile information) may be:
• Viewed by any user or visitor
• Indexed by search engines
• Shared or embedded on other websites
• Used by third parties in accordance with our Terms of Service

4.6 With Your Consent

We may share information for purposes not described in this policy with your explicit consent.

5. USER-GENERATED CONTENT

5.1 Content Ownership and Rights

When you upload content to Truthworld:
• You retain all ownership rights to your content
• You grant us a worldwide, non-exclusive, royalty-free license to use, reproduce, distribute, and display your content for the purpose of operating and promoting our Platform
• You represent that you have all necessary rights to upload the content
• **Content creators must accurately categorize content with appropriate age ratings** to ensure children only access suitable material

5.2 Public Visibility and Age-Appropriate Access

Content you upload is subject to age-based visibility controls:
• **Age-Restricted Content:** Content marked for general audiences is automatically filtered from children's accounts
• **Children's Content:** Content designated as child-friendly is accessible to all users, including children
• **Account-Based Filtering:** The platform automatically restricts content visibility based on the user's age
• You can set videos to Public (with age restrictions applied automatically), Unlisted, or Private
• Control who can comment on your videos
• Remove or edit content at any time

**Content Creator Responsibility:**
• Properly categorize your content with accurate age ratings
• Failure to correctly label content may result in content removal or account restrictions

5.3 Content Moderation

We reserve the right to:
• Review and remove content that violates our Community Guidelines
• Disable accounts that repeatedly violate policies
• Cooperate with law enforcement regarding illegal content

5.4 Reporting and Removal

Users can report inappropriate content. We will:
• Review reported content promptly
• Take appropriate action (remove content, warn users, suspend accounts)
• Notify affected parties of our decision (where appropriate)

6. YOUR PRIVACY RIGHTS

Depending on your location, you may have the following rights:

6.1 GDPR Rights (European Economic Area Users)

Under the General DataProtection Regulation (GDPR), you have the right to:
• Access: Request a copy of your personal data
• Rectification: Correct inaccurate or incomplete data
• Erasure: Request deletion of your personal data ("right to be forgotten")
• Restriction: Limit how we process your data
• Portability: Receive your data in a structured, commonly used format
• Objection: Object to processing based on legitimate interests
• Withdraw Consent: Withdraw consent for data processing at any time
• Lodge Complaints: File complaints with your local data protection authority

6.2 CCPA Rights (California Residents)

Under the California Consumer Privacy Act (CCPA), you have the right to:
• Know what personal information is collected, used, shared, or sold
• Delete personal information held by businesses
• Opt-out of the sale of personal information
• Non-discrimination for exercising your privacy rights

We do not sell personal information to third parties for monetary consideration. However, some data sharing for advertising purposes may be considered a "sale" under CCPA. You can opt-out using our privacy settings.

6.3 Other Jurisdictions

Users in other regions may have similar rights under local privacy laws. We will honor rights requests in accordance with applicable law.

6.4 Exercising Your Rights

To exercise any of these rights:
• Email us at: privacy@Truthworld.com
• Use the privacy settings in your account
• Submit a request through our Help Center

We will respond to verified requests within 30 days (or as required by law).

7. DATA RETENTION

We retain your information for as long as necessary to provide our services and fulfill the purposes described in this policy:

• Account Information: Retained while your account is active and for up to 90 days after deletion
• Content: Videos remain available until you delete them; deleted content may persist in backups for up to 90 days
• Analytics Data: Aggregated data may be retained indefinitely
• Legal Obligations: Some data may be retained longer to comply with legal requirements

8. COOKIES AND TRACKING TECHNOLOGIES

8.1 Types of Cookies We Use

• Essential Cookies: Required for basic Platform functionality (login, security)
• Preference Cookies: Remember your settings and preferences
• Analytics Cookies: Help us understand how users interact with our Platform
• Advertising Cookies: Deliver relevant ads based on your interests

8.2 Third-Party Cookies

We use third-party services that may set their own cookies:
• Google Analytics
• Google Ads
• Facebook Pixel
• Third-party advertising networks

8.3 Cookie Controls

You can control cookies through:
• Browser settings: Most browsers allow you to block or delete cookies
• Cookie preference center: Available in your account settings
• Opt-out tools: NAI opt-out tool (http://optout.networkadvertising.org), DAA opt-out tool (http://optout.aboutads.info)

Note: Disabling essential cookies may affect Platform functionality.

9. DATA SECURITY

We implement industry-standard security measures to protect your information:

• Encryption: Data is encrypted in transit (TLS/SSL) and at rest
• Access Controls: Limited employee access on a need-to-know basis
• Authentication: Multi-factor authentication options available
• Regular Audits: Security assessments and vulnerability testing
• Incident Response: Procedures to respond to data breaches

Despite our efforts, no system is completely secure. We cannot guarantee absolute security of your information.

10. CHILDREN'S PRIVACY

Truthworld welcomes users of all ages and is committed to providing a safe, age-appropriate experience for everyone, including children.

**Age-Appropriate Content Protection:**
- Our platform implements content filtering to ensure children can only access content marked as suitable for their age group
- Children's accounts are automatically restricted from viewing content intended for general audiences
- Content creators must properly categorize their content to ensure appropriate age-based restrictions
- Parents and guardians can monitor and control their children's viewing experience through parental control features

**Parental Consent and Control:**
For users under 18 years of age (as per the Digital Personal Data Protection Act, 2023 for Indian users):
- We obtain verifiable parental or guardian consent before collecting personal information
- Parents/guardians can manage their child's account settings, privacy preferences, and content access
- Parents/guardians can review, modify, or request deletion of their child's personal information at any time

**Data Collection from Children:**
When we collect information from children with parental consent:
- We collect only the minimum information necessary to provide our services
- Children's data is subject to the same security protections as all user data
- We do not use children's personal information for targeted advertising
- We do not share children's personal information with third parties except as necessary to provide our services

**Parental Rights:**
If you are a parent or guardian, you have the right to:
- Review the personal information we have collected from your child
- Request correction or deletion of your child's personal information
- Refuse further collection or use of your child's information
- Withdraw consent at any time

To exercise these rights or if you have concerns about your child's privacy, please contact us at: privacy@Truthworld.com or grievance@Truthworld.com.

**Compliance:**
We comply with the Children's Online Privacy Protection Act (COPPA) for U.S. users and the Digital Personal Data Protection Act (DPDPA), 2023 for Indian users, along with other applicable children's privacy laws worldwide.

11. INTERNATIONAL DATA TRANSFERS

Truthworld operates globally. Your information may be transferred to and processed in countries other than your country of residence. For Indian users, we primarily store data within India to comply with data localization requirements under applicable Indian laws.

For data transferred outside India, we ensure appropriate safeguards are in place, such as:
• Standard Contractual Clauses approved by the European Commission
• Privacy Shield certification (where applicable)
• Consent for specific transfers

By using our Platform, you consent to the transfer of your information internationally.

12. CHANGES TO THIS PRIVACY POLICY

We may update this Privacy Policy periodically to reflect changes in our practices, technology, legal requirements, or other factors.

When we make changes:
• We will update the "Last Updated" date at the top of this policy
• For material changes, we will provide prominent notice through:
  - Email notification
  - In-app notification
  - Banner on our homepage

Your continued use of the Platform after changes take effect constitutes acceptance of the updated policy.

13. THIRD-PARTY LINKS AND SERVICES

Our Platform may contain links to third-party websites, applications, or services. We are not responsible for the privacy practices of these third parties. We encourage you to review their privacy policies.

Third-party services we integrate with:
• Google Sign-In: https://policies.google.com/privacy
• Firebase: https://firebase.google.com/support/privacy
• Payment Processors: Subject to their own privacy policies

14. DO NOT TRACK SIGNALS

Some browsers transmit "Do Not Track" (DNT) signals. Our Platform does not currently respond to DNT signals, as there is no industry standard for how to interpret them. We will update this policy if we adopt a DNT standard.

15. CONTACT INFORMATION

For privacy-related questions, concerns, or rights requests, please contact us:

Truthworld Privacy Team
Email: privacy@Truthworld.com
Support Email: ebenezervampu@Truthworld.com

Mailing Address:
Truthworld Privacy Team
Uppal Kalan, Telangana
India

Data Protection Officer (EU):
dpo@Truthworld.com

India Privacy Officer:
privacy@Truthworld.com

We will respond to your inquiries within 30 days.

16. JURISDICTION-SPECIFIC NOTICES

16.1 European Economic Area (EEA)

Legal Basis for Processing:
• Consent: When you provide explicit consent
• Contract: To fulfill our Terms of Service
• Legitimate Interests: To improve our services and prevent fraud
• Legal Compliance: To meet legal obligations

Data Controller: Truthworld is the data controller for your personal information.

16.2 California Residents

Categories of Information Collected: See Section 2
Business Purposes: See Section 3
Third-Party Sharing: See Section 4

California residents can request a list of third parties to whom we have disclosed personal information for direct marketing purposes.

16.3 Australia

We comply with the Australian Privacy Principles (APPs) under the Privacy Act 1988. Australian users can lodge complaints with the Office of the Australian Information Commissioner (OAIC).

16.4 Brazil

We comply with the Lei Geral de Proteção de Dados (LGPD). Brazilian users have rights similar to GDPR users, including the right to access, correct, and delete personal data.

16.5 India

As an Indian company, we comply with the Digital Personal Data Protection Act (DPDPA), 2023 and Information Technology Act, 2000 (as amended).

Indian Users' Rights:
• Right to access personal data
• Right to correction of inaccurate data
• Right to erasure of personal data
• Right to grievance redressal
• Right to nominate a legal representative

Data Localization: Certain categories of sensitive personal data may be stored and processed on servers located in India in compliance with applicable Indian laws.

Grievance Officer:
Name: [Grievance Officer Name]
Email: grievance@Truthworld.com
Response Time: We will acknowledge complaints within 24 hours and resolve within 30 days as per DPDPA requirements.

Data Fiduciary: Truthworld acts as a Data Fiduciary under the DPDPA, 2023.

Consent: By using our Services, you provide consent for the processing of your personal data as described in this Privacy Policy. You may withdraw consent at any time by contacting us.

Cross-Border Transfer: If your data is transferred outside India, we ensure adequate safeguards are in place as required under Indian law.

---

BY USING Truthworld, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THIS PRIVACY POLICY.
""";
}
