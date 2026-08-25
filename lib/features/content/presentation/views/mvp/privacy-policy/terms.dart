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

class TermsAndConditionsPage extends StatelessWidget {
  TermsAndConditionsPage({super.key, this.isDashboard = false}) {
    _parsePolicyText();
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 40) {
        _hasScrolledToBottom.value = true;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 20) {
        _hasScrolledToBottom.value = true;
      }
    });
  }

  final bool isDashboard;

  final ScrollController _scrollController = ScrollController();
  final RxList<PolicySection> _sections = <PolicySection>[].obs;
  final RxString _introContent = ''.obs;
  final RxBool _hasScrolledToBottom = false.obs;

  /// Parses the giant text string into a structured list of sections.
  void _parsePolicyText() {
    // Regex to find headings like "1. INTRODUCTION..." or "10. DISCLAIMERS..."
    final regex = RegExp(r'\n(\d{1,2}\. [A-Z_ ]+)\n', multiLine: true);
    final matches = regex.allMatches(_termsText).toList();

    if (matches.isEmpty) {
      _introContent.value = _termsText;
      return;
    }

    // Get the intro text before the first heading
    final firstMatch = matches.first;
    final introContent = _termsText.substring(0, firstMatch.start).trim();

    // Loop through all matches to create sections
    final tempSections = <PolicySection>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final title = match
          .group(1)!
          .trim(); // The heading, e.g., "1. INTRODUCTION..."

      // Get the content between this heading and the next one
      final contentStart = match.end;
      final contentEnd = (i + 1 < matches.length)
          ? matches[i + 1].start
          : _termsText.length;

      final content = _termsText.substring(contentStart, contentEnd).trim();

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
      child: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          children: [
            ..._sections.map((section) {
              return Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ListTile(
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
                ),
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
              'Terms and Conditions | Truthworld',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                // Use theme-aware color
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.toNamed('/privacy');
                },
                child: Text(
                  'Privacy Policy',
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
          bottomNavigationBar: Obx(() {
            final args = Get.arguments as Map<String, dynamic>?;
            final requireAgreement = args?['requireAgreement'] == true;
            if (!requireAgreement) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: SafeArea(
                child: _hasScrolledToBottom.value
                    ? SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Get.back(result: true);
                          },
                          icon: const Icon(Icons.check_circle_outline, color: Colors.black, size: 20),
                          label: const Text(
                            'I Have Read & Accept Terms and Conditions',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward, color: Theme.of(context).textTheme.bodySmall?.color, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Please scroll to the bottom to accept Terms and Conditions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            );
          }),
        );
      },
    );
  }

  // Original policy text (unchanged)
  static const String _termsText = """
TERMS AND CONDITIONS

Last Updated: April 04, 2026
Effective Date: April 04, 2026

1. INTRODUCTION AND ACCEPTANCE OF TERMS

Welcome to Truthworld ("we," "our," "us," or the "Platform"). These Terms and Conditions ("Terms," "Terms of Service," or "Agreement") constitute a legally binding agreement between you ("you," "your," or "User") and Truthworld governing your access to and use of our video-sharing platform, including our website, mobile applications, and all related services (collectively, the "Services").

By accessing, browsing, or using any part of our Services, you acknowledge that you have read, understood, and agree to be bound by these Terms, our Privacy Policy, and our Community Guidelines. If you do not agree to these Terms, you must not access or use our Services.

**Important Notice:**
- These Terms apply to all users, including viewers, content creators, advertisers, and partners
- You must be of legal age to form a binding contract in your jurisdiction, or have parental/guardian consent
- We reserve the right to modify these Terms at any time
- Your continued use after changes constitutes acceptance

2. ELIGIBILITY AND ACCOUNT REGISTRATION

2.1 Age Requirements and Parental Consent

Truthworld welcomes users of all ages with appropriate safeguards:

**For Users of All Ages:**
- Users of any age may access age-appropriate content on our Platform
- Children's accounts are automatically filtered to show only content marked as suitable for their age

**For Users Under 18 (Indian Law):**
- Must obtain verifiable parental or guardian consent before creating an account
- Parents/guardians are responsible for supervising their child's use of the Platform
- Parents/guardians may control privacy settings and content access for minor accounts

**For Users 18 and Over:**
- May create accounts independently without parental consent
- Have full access to all age-appropriate features

2.2 Account Creation and Registration

To access certain features of our Platform, you must create an account:

**Account Requirements:**
- Provide accurate, current, and complete information during registration
- Maintain and promptly update your account information
- Provide a valid email address for account verification
- Choose a unique username that does not violate our Community Guidelines
- Create a secure password and keep it confidential

**Account Security:**
- You are solely responsible for all activity under your account
- Do not share your account credentials with others
- Notify us immediately of any unauthorized access or security breach
- We are not liable for losses resulting from unauthorized use of your account

**One Account Per User:**
- Each user may maintain only one primary account
- Creating multiple accounts to evade bans or restrictions is prohibited
- Channel-specific accounts for organizations may be permitted with approval

2.3 Account Verification

We may require additional verification for certain accounts:
- Identity verification for monetization eligibility
- Age verification for users under 18
- Business verification for commercial accounts
- Enhanced verification for high-profile or official accounts

3. USER-GENERATED CONTENT

3.1 Content Ownership and Rights

**Your Content Ownership:**
- You retain all ownership rights to the content you upload, including videos, images, audio, comments, and other materials ("Your Content")
- Truthworld does not claim ownership of Your Content

**License Grant to Truthworld:**
By uploading Your Content to our Platform, you grant Truthworld a:
- Worldwide, non-exclusive, royalty-free, transferable, and sublicensable license
- To use, reproduce, distribute, prepare derivative works, display, and perform Your Content
- In connection with operating, promoting, and improving our Services
- Through any media channels, including third-party platforms
- For the duration that Your Content remains on our Platform

This license allows us to:
- Store and display Your Content to other users
- Create thumbnails, previews, and promotional materials
- Distribute Your Content through our CDN and partner networks
- Make Your Content available for embedding on third-party websites
- Use Your Content for marketing and promotional purposes

**License Termination:**
- The license terminates when you delete Your Content from our Platform
- Backup copies may remain in our systems for up to 90 days
- Content shared by other users may continue to exist

3.2 Content Representations and Warranties

By uploading Your Content, you represent and warrant that:
- You own or have obtained all necessary rights, licenses, and permissions for Your Content
- Your Content does not infringe on any intellectual property rights, privacy rights, or other rights of third parties
- Your Content complies with all applicable laws and regulations
- You have obtained necessary consent from any individuals featured in Your Content
- Your Content is accurately categorized with appropriate age ratings

**Consequences of False Representations:**
- Violation may result in content removal, account suspension, or termination
- You may be held liable for damages resulting from false representations
- We may report violations to appropriate authorities

3.3 Age-Appropriate Content Categorization

**Mandatory Content Rating:**
All content creators must accurately categorize their content:

**Content Categories:**
- **Kids Content:** Suitable for children under 13
- **Teen Content:** Suitable for ages 13-17
- **General Audience:** Suitable for ages 18 and over
- **Mature Content:** May contain adult themes (18+ only)

**Automatic Content Filtering:**
- Children's accounts automatically filter out general audience and mature content
- Teen accounts filter out mature content
- Adult accounts have access to all appropriately-rated content

**Creator Responsibilities:**
- Accurately rate all uploaded content
- Use appropriate content warnings and tags
- Update ratings if content is modified
- Failure to properly categorize content may result in:
* Automatic content removal
* Loss of monetization privileges
* Account suspension or termination

3.4 Prohibited Content

You may not upload, post, or transmit content that:

**Illegal Content:**
- Violates any local, national, or international law
- Infringes on intellectual property rights (copyright, trademark, patent)
- Contains child sexual abuse material (CSAM)
- Promotes or facilitates illegal activities

**Harmful Content:**
- Promotes violence, terrorism, or hate speech
- Harasses, bullies, or threatens individuals or groups
- Contains graphic violence or gore (except in educational/news context)
- Promotes self-harm or suicide
- Contains non-consensual sexual content or revenge porn

**Deceptive Content:**
- Spreads misinformation or disinformation
- Impersonates others or misrepresents identity
- Contains spam, scams, or phishing attempts
- Manipulates platform features (artificial engagement)

**Inappropriate Content:**
- Contains sexually explicit material outside permitted categories
- Promotes dangerous or harmful activities
- Exploits or endangers minors
- Contains shocking or disgusting content designed to sensationalize

**Age-Inappropriate Content:**
- Adult content not properly categorized
- Children's content with hidden mature themes
- Content designed to circumvent age filters

3.5 Content Moderation

**Our Right to Review:**
- We reserve the right to review, monitor, and moderate all content
- Automated systems and human reviewers may assess content compliance
- We do not pre-screen all content but respond to reports and flags

**Content Removal:**
We may remove content that:
- Violates these Terms or our Community Guidelines
- Infringes on third-party rights
- Poses risks to users or the platform
- Is subject to valid legal requests

**Appeals Process:**
- You may appeal content removal decisions
- Submit appeals through your account settings
- We will review appeals within 14 business days
- Appeal decisions are final

4. ACCEPTABLE USE POLICY

4.1 Permitted Uses

You may use our Services to:
- View, upload, and share videos in accordance with these Terms
- Engage with content through likes, comments, and shares
- Create and manage channels
- Participate in our community
- Access monetization features (if eligible)

4.2 Prohibited Activities

You may not:

**Platform Abuse:**
- Circumvent or attempt to circumvent security measures
- Access unauthorized areas or accounts
- Interfere with platform functionality or performance
- Use automated systems (bots, scrapers) without permission
- Create fake accounts or engage in artificial engagement

**Harassment and Abuse:**
- Harass, threaten, or intimidate other users
- Engage in cyberbullying or stalking
- Dox or share private information without consent
- Organize coordinated harassment campaigns

**Commercial Abuse:**
- Engage in misleading or deceptive commercial practices
- Spam users with unsolicited commercial content
- Manipulate the platform for unfair commercial advantage
- Sell or transfer accounts

**System Abuse:**
- Upload viruses, malware, or malicious code
- Attempt to gain unauthorized access to our systems
- Overload or disrupt our infrastructure
- Reverse engineer our platform or services

**Legal Violations:**
- Use our Services for illegal purposes
- Violate export control or sanctions laws
- Facilitate money laundering or fraud
- Violate intellectual property rights

5. INTELLECTUAL PROPERTY RIGHTS

5.1 Truthworld's Intellectual Property

All content, features, and functionality of the Platform, including but not limited to:
- Software, code, and algorithms
- Design, layout, and user interface
- Logos, trademarks, and branding
- Documentation and tutorials

Are owned by Truthworld and protected by copyright, trademark, and other intellectual property laws.

**Limited License to Users:**
We grant you a limited, non-exclusive, non-transferable, revocable license to access and use our Services for personal, non-commercial purposes, subject to these Terms.

5.2 Copyright Policy and DMCA Compliance

We respect intellectual property rights and comply with the Digital Millennium Copyright Act (DMCA) and Indian Copyright Act, 1957.

**Copyright Infringement Reporting:**
If you believe your copyright has been infringed:
1. Submit a notice to: copyright@Truthworld.com
2. Include:
- Description of the copyrighted work
- URL of the infringing content
- Your contact information
- Good faith statement of unauthorized use
- Statement of accuracy and authority
- Physical or electronic signature

**Counter-Notification:**
If your content was removed due to a copyright claim, you may submit a counter-notification if you believe the removal was in error.

**Repeat Infringer Policy:**
- Accounts with multiple copyright violations may be terminated
- Three strikes may result in permanent account closure

5.3 Trademark Policy

You may not use Truthworld's trademarks without written permission. Unauthorized use may result in legal action.

6. MONETIZATION AND PAYMENTS

6.1 Monetization Eligibility

Content creators may be eligible for monetization through:
- Advertisement revenue sharing
- Channel memberships and subscriptions
- Super Chat and Super Stickers
- Merchandise shelf
- Premium content sales

**Eligibility Requirements:**
- Account in good standing
- Compliance with all policies
- Zero subscriber count required (Monetization active from Day 1)
- Cash withdrawal unlocked on a per-video basis upon reaching 10 hours of watch time for that specific video
- Unwithdrawn or locked earnings can be spent immediately on platform AI features (AI Subtitles, AI Dubbing, AI Highlights)
- Age verification (18+ for payout registration)
- Valid payment information

6.2 Payment Terms

**Revenue Sharing:**
- Revenue share percentages are specified in your monetization agreement
- Payments are processed monthly
- Minimum payout threshold applies
- Subject to applicable taxes and withholding

**Payment Methods:**
- Bank transfer
- PayPal
- Other approved payment processors

6.3 Prohibited Monetization Practices

You may not:
- Use invalid traffic or artificial engagement to inflate earnings
- Click on your own ads or encourage others to do so
- Place ads on prohibited content
- Violate advertiser-friendly content guidelines
- Manipulate the monetization system

7. PRIVACY AND DATA PROTECTION

Your use of our Services is governed by our Privacy Policy, which is incorporated into these Terms by reference.

**Key Privacy Points:**
- We collect personal information as described in our Privacy Policy
- We protect your data with industry-standard security measures
- You have rights to access, correct, and delete your data
- We comply with GDPR, CCPA, DPDPA, and other privacy laws

**For Indian Users:**
- We comply with the Digital Personal Data Protection Act (DPDPA), 2023
- Grievance Officer contact: grievance@Truthworld.com
- We respond to complaints within 24 hours

Please review our Privacy Policy for complete details.

8. COMMUNITY GUIDELINES

In addition to these Terms, all users must comply with our Community Guidelines, which provide detailed rules for respectful and safe platform use.

**Key Guidelines:**
- Treat others with respect
- Create authentic, original content
- Provide accurate information
- Report violations you encounter
- Follow age-appropriate content rules

Violations may result in warnings, content removal, or account termination.

9. THIRD-PARTY SERVICES AND LINKS

9.1 Third-Party Integrations

Our Platform may integrate with third-party services:
- Google Sign-In for authentication
- Firebase for data storage
- Payment processors for transactions
- Analytics services for platform improvement

**Third-Party Terms:**
- These services have their own terms and privacy policies
- We are not responsible for third-party practices
- Review their policies before using integrated services

9.2 External Links

Our Platform may contain links to external websites or services:
- We do not control or endorse third-party content
- External links are provided for convenience only
- We are not responsible for external content or practices
- Use external links at your own risk

10. DISCLAIMERS AND LIMITATIONS OF LIABILITY

10.1 Disclaimer of Warranties

THE SERVICES ARE PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO:

- Warranties of merchantability, fitness for a particular purpose, or non-infringement
- Guarantees of uninterrupted, timely, secure, or error-free service
- Guarantees regarding the accuracy, reliability, or quality of user-generated content
- Warranties that defects will be corrected

**User Content Disclaimer:**
- All content is user-generated and not reviewed by us before publication
- We do not endorse, support, or guarantee the accuracy of user content
- Users are responsible for evaluating content reliability
- We are not liable for damages from user-generated content

10.2 Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, Truthworld SHALL NOT BE LIABLE FOR:

**Indirect Damages:**
- Indirect, incidental, consequential, or punitive damages
- Loss of profits, revenue, data, or goodwill
- Service interruptions or data loss
- Cost of substitute services

**Direct Damages Cap:**
- Total liability shall not exceed the amount paid by you in the past 12 months
- For free users, liability is limited to INR 1,000

**Exceptions:**
Some jurisdictions do not allow limitation of liability for:
- Death or personal injury caused by negligence
- Fraud or fraudulent misrepresentation
- Violation of consumer protection laws

10.3 Indemnification

You agree to indemnify, defend, and hold harmless Truthworld, its affiliates, officers, directors, employees, and agents from:
- Claims arising from your use of the Services
- Your violation of these Terms
- Your violation of third-party rights
- Your Content and its consequences

11. TERMINATION

11.1 Termination by You

You may terminate your account at any time by:
- Using account deletion settings
- Contacting support at: ebenezervampu@Truthworld.com

**Upon Account Deletion:**
- Your public content may be removed (subject to our retention policies)
- Backup copies may persist for up to 90 days
- Some information may be retained as required by law

11.2 Termination by Us

We may suspend or terminate your account immediately if:
- You violate these Terms or our policies
- Your account is involved in fraudulent or illegal activity
- Termination is required by law
- Your account poses risks to other users or the platform

**Consequences of Termination:**
- Loss of access to your account and content
- Forfeiture of unpaid monetization earnings (in cases of policy violations)
- Prohibition from creating new accounts

**Notice:**
- We will attempt to provide advance notice when possible
- Immediate termination may occur for serious violations

11.3 Effect of Termination

Upon termination:
- All licenses granted by you to us continue for content that remains on the platform
- Provisions that should survive termination remain in effect (indemnification, disclaimers, governing law)

12. DISPUTE RESOLUTION

12.1 Governing Law

These Terms are governed by the laws of India, without regard to conflict of law principles.

**Jurisdiction:**
- Courts in Hyderabad, Telangana, India have exclusive jurisdiction
- You consent to personal jurisdiction in these courts

12.2 Informal Resolution

Before filing a legal claim, you agree to:
1. Contact us at: legal@Truthworld.com
2. Describe the dispute in detail
3. Allow 30 days for resolution attempts

12.3 Arbitration (Optional)

For disputes that cannot be resolved informally, parties may agree to binding arbitration:
- Conducted in Hyderabad, Telangana
- Governed by Indian Arbitration and Conciliation Act, 1996
- Language: English
- Single arbitrator mutually agreed upon

12.4 Class Action Waiver

You agree to resolve disputes individually, not as part of a class action or representative proceeding.

13. CHANGES TO TERMS

13.1 Modification Rights

We reserve the right to modify these Terms at any time. Changes may be made to:
- Reflect changes in law or regulation
- Implement new features or services
- Improve clarity or readability
- Address security or operational issues

13.2 Notice of Changes

When we make material changes:
- Updated "Last Updated" date will appear at the top
- Email notification to registered users
- In-app notification or banner
- Pop-up requiring acknowledgment for significant changes

13.3 Acceptance of Changes

**Your Options:**
- Continue using the Services (constitutes acceptance)
- Stop using the Services if you disagree
- Contact us with concerns before changes take effect

**Effective Date:**
- Changes become effective on the date specified in the notice
- Usually 30 days after notification for material changes
- Immediate for legal or security-related changes

14. GENERAL PROVISIONS

14.1 Entire Agreement

These Terms, together with our Privacy Policy and Community Guidelines, constitute the entire agreement between you and Truthworld.

14.2 Severability

If any provision is found invalid or unenforceable, the remaining provisions remain in full effect.

14.3 No Waiver

Failure to enforce any provision does not constitute a waiver of that provision or any other provision.

14.4 Assignment

You may not assign these Terms without our written consent. We may assign these Terms to any affiliate or successor.

14.5 Force Majeure

We are not liable for delays or failures due to circumstances beyond our reasonable control, including:
- Natural disasters
- War or terrorism
- Government actions
- Network or system failures
- Labor disputes

14.6 Language

These Terms are written in English. Translations may be provided for convenience, but the English version governs in case of conflicts.

14.7 Notices

**To You:**
Notices will be sent to your registered email address or posted on the Platform.

**To Us:**
Notices should be sent to:
Truthworld Legal Team
Email: legal@Truthworld.com
Address: Uppal Kalan, Telangana, India

15. CONTACT INFORMATION

For questions, concerns, or support regarding these Terms:

**General Inquiries:**
Email: ebenezervampu@Truthworld.com
Support: support@Truthworld.com

**Legal Matters:**
Email: legal@Truthworld.com

**Privacy Concerns:**
Email: privacy@Truthworld.com

**Copyright Issues:**
Email: copyright@Truthworld.com

**Indian Grievance Officer (DPDPA Compliance):**
Email: grievance@Truthworld.com
Response Time: 24 hours acknowledgment, 30 days resolution

**Mailing Address:**
Truthworld
Uppal Kalan, Telangana
India

---

BY USING Truthworld, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THESE TERMS AND CONDITIONS.

Thank you for being part of the Truthworld community!
""";
}
