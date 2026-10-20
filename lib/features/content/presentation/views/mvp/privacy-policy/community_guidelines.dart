import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// A simple class to hold our parsed guidelines sections
class GuidelineSection {
  GuidelineSection({
    required this.title,
    required this.content,
    required this.key,
  });
  final String title;
  final String content;
  final GlobalKey key;
}

class CommunityGuidelinesPage extends StatelessWidget {
  CommunityGuidelinesPage({
    super.key,
    this.isDashboard = false,
    this.requireAgreement,
  }) {
    _parseGuidelinesText();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        if (pos.pixels >= pos.maxScrollExtent - 60 ||
            (pos.atEdge && pos.pixels > 0)) {
          _hasScrolledToBottom.value = true;
        }
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
  final bool? requireAgreement;

  final ScrollController _scrollController = ScrollController();
  late final List<GuidelineSection> _sections;
  late final String _introContent;
  final RxBool _hasScrolledToBottom = false.obs;
  final RxBool _guidelinesAccepted = false.obs;

  /// Parses the giant text string into a structured list of sections.
  void _parseGuidelinesText() {
    // Regex to find headings like "1. CORE PRINCIPLES..." or "2. LUST-FREE AND MODERATE MARRIAGE/ROMANCE POLICY..."
    final regex = RegExp(r'\n(\d{1,2}\. [A-Z0-9_\-% /]+)\n', multiLine: true);
    final matches = regex.allMatches(_guidelinesText).toList();

    if (matches.isEmpty) {
      _introContent = _guidelinesText;
      _sections = const [];
      return;
    }

    // Get the intro text before the first heading
    final firstMatch = matches.first;
    final introContent = _guidelinesText.substring(0, firstMatch.start).trim();

    // Loop through all matches to create sections
    final tempSections = <GuidelineSection>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final title = match.group(1)!.trim();

      // Get the content between this heading and the next one
      final contentStart = match.end;
      final contentEnd = (i + 1 < matches.length)
          ? matches[i + 1].start
          : _guidelinesText.length;

      final content = _guidelinesText
          .substring(contentStart, contentEnd)
          .trim();

      tempSections.add(
        GuidelineSection(title: title, content: content, key: GlobalKey()),
      );
    }

    _introContent = introContent;
    _sections = tempSections;
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

  void _navigateToPolicy(String route) {
    if (isDashboard && Get.isRegistered<HomeController>()) {
      final homeController = Get.find<HomeController>();
      switch (route) {
        case '/community-guidelines':
          homeController.onSideNavItemSelect(
            HomeController.indexCommunityGuidelines,
          );
        case '/privacy':
          homeController.onSideNavItemSelect(HomeController.indexPrivacy);
        case '/terms':
          homeController.onSideNavItemSelect(HomeController.indexTerms);
      }
      if (kIsWeb) {
        WebPlatformUtils.pushUrlHistory(route);
      }
      return;
    }
    Get.toNamed(route);
  }

  /// Builds the left-hand navigation menu
  Widget _buildNavigationMenu(BuildContext context, {bool isDrawer = false}) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        width: 280, // Fixed width for the nav menu
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          children: [
            ..._sections.map((section) {
              return ListTile(
                title: Text(
                  section.title,
                  style: const TextStyle(fontSize: 14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
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

  /// Builds the main content area that displays the guidelines text
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

    final arguments = Get.arguments as Map<String, dynamic>?;
    final fromRejectedChannelId =
        arguments?['fromRejectedChannelId'] as String?;
    final ownerId = arguments?['ownerId'] as String?;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Render the introductory text first
          SelectableText(_introContent, style: bodyTextStyle),
          const SizedBox(height: 24),
          // Then render all the numbered sections
          ..._sections.map((section) {
            return Padding(
              key: section.key,
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
          if (fromRejectedChannelId != null) ...[
            const SizedBox(height: 40),
            const Divider(thickness: 1),
            const SizedBox(height: 24),
            Material(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guidelines Agreement Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your channel details were previously rejected for violating our community guidelines. Please review the guidelines above, confirm your agreement, and proceed to customize your channel to comply with the rules.',
                      style: bodyTextStyle,
                    ),
                    const SizedBox(height: 20),
                    Obx(
                      () => CheckboxListTile(
                        value: _guidelinesAccepted.value,
                        onChanged: (val) {
                          _guidelinesAccepted.value = val ?? false;
                        },
                        title: const Text(
                          'I have read and agree to comply with all the community guidelines listed above.',
                          style: TextStyle(fontSize: 14),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Obx(
                          () => ElevatedButton(
                            onPressed: _guidelinesAccepted.value
                                ? () {
                                    Get.offAllNamed(
                                      '/studio',
                                      arguments: {
                                        'channel': {
                                          'id': fromRejectedChannelId,
                                          'ownerId': ownerId,
                                        },
                                        'tab': 6, // Customization page
                                      },
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Accept & Customize Channel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final isAgreementRequired =
        requireAgreement ?? (args?['requireAgreement'] == true);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a breakpoint to decide which layout to show
        const breakpoint = 700;
        final isDesktop = constraints.maxWidth >= breakpoint;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 1,
            shadowColor: AppColors.bgPage.withValues(alpha: 0.1),
            leading: (isDashboard || isDesktop || isAgreementRequired)
                ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (isDashboard && Get.isRegistered<HomeController>()) {
                        Get.find<HomeController>().onSideNavItemSelect(
                          HomeController.indexHome,
                        );
                        if (kIsWeb) {
                          WebPlatformUtils.pushUrlHistory('/');
                        }
                      } else {
                        if (Navigator.of(context).canPop()) {
                          Get.back();
                        } else {
                          Get.offAllNamed('/');
                        }
                      }
                    },
                  )
                : null,
            title: Text(
              isDesktop ? 'Community Guidelines | Truthworld' : 'Community Guidelines',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            actions: [
              if (isDesktop) ...[
                TextButton(
                  onPressed: () => _navigateToPolicy('/terms'),
                  child: Text(
                    'Terms of Service',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToPolicy('/privacy'),
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ] else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: _navigateToPolicy,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: '/terms',
                      child: Text('Terms of Service'),
                    ),
                    const PopupMenuItem(
                      value: '/privacy',
                      child: Text('Privacy Policy'),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: (isDesktop || isAgreementRequired)
              ? null
              : Drawer(child: _buildNavigationMenu(context, isDrawer: true)),
          body: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNavigationMenu(context),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: _buildContentArea(context)),
                  ],
                )
              : _buildContentArea(context),
          bottomNavigationBar: !isAgreementRequired
              ? null
              : Obx(() {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              child: ElevatedButton(
                                onPressed: () {
                                  Get.back(result: true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'I Have Read & Accept Community Guidelines',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.arrow_downward,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Please scroll to the bottom to accept Community Guidelines',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
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

  // Guidelines text (compliant with standard formatting)
  static const String _guidelinesText = """
COMMUNITY GUIDELINES

Last Updated: October 12, 2026
Effective Date: October 12, 2026

Welcome to Truthworld, operated by TowerVSP Services (OPC) Private Limited (CIN: U63111TS2025OPC207488). Our mission is to foster a truthful, knowledge-centric, and productive community through open debate and verified information.

Truthworld is an OPEN DEBATE PLATFORM. We VERIFY claims — we do not censor them. Our Credibility Engine fact-checks every claim in every video, provides source citations, and displays a credibility score alongside the video. Channels can upload debates, controversial opinions, and discuss any topic — our job is to verify, not to silence.

All content uploaded to the Platform must comply with these guidelines. We moderate HOW content is delivered (it must be family-friendly), NOT what opinions are expressed. Violations of delivery standards may result in content removal, restrictions on account privileges, or permanent account termination. In accordance with Indian Intermediary Guidelines, removed content and relevant logs are retained for at least 180 days for statutory compliance.

1. CORE PRINCIPLES - OPEN DEBATE PLATFORM

Truthworld is designed as an open space for truth-seeking through debate, education, clean entertainment, self-improvement, technology, spirituality, news, and factual sharing.

We believe in:
• **Open Debate:** Any topic can be discussed — politics, history, religion, science, conspiracy theories, controversial figures, and more. We verify claims; we do not censor opinions.
• **Credibility, Not Censorship:** Our Credibility Engine fact-checks claims and provides sources. Viewers see the truth alongside every claim.
• **Family-Friendly Delivery:** While any topic is allowed, HOW it is said must be clean, civil, and appropriate for all audiences. No profanity, no explicit content.
• **Respect Through Clean Language:** Passionate debate is welcome. Vulgar language and slurs are not.

2. LUST-FREE AND ROMANCE-FREE POLICY

To maintain our focus on productivity, knowledge, family-friendliness, and clean culture, Truthworld is a lust-free and romance-free platform. Romantic content, dating themes, and love/romance stories between opposite genders are strictly prohibited under all circumstances, even within or after marriage. Romance and Fashion are completely barred as content categories.

**Permitted Content:**
• Wedding documentaries, marriage ceremonies, and general family/marriage content (focusing on familial love, such as father's love, mother's love, or sibling bonds).
• Scientific, biological, medical, or sociological discussions of relationships or human biology, provided they are presented in a clinical, educational, or academic manner.
• Healthy friendships, community bonding, and professional teamwork.

**Prohibited Content:**
• Romantic stories, movies, short films, songs, or web series focusing on romance, dating themes, hookups, or courtship (whether before, within, or after marriage).
• Any romantic categories, romance genres, or opposite-sex romantic storylines.
• Any romantic couples or opposite-sex romance stories, including honeymoons and romantic trips.
• Content depicting, encouraging, or celebrating physical intimacy, dating apps, or lustful behavior.
• Highly suggestive attire, gestures, and behavior designed to invoke physical attraction, romance, or lust.
• Fashion showcases, glamour modeling, revealing outfit hauls, and vanity apparel displays (Fashion is permanently discontinued and prohibited as a platform category).

3. CONSTRUCTIVE ROASTING AND BULLYING POLICY

We believe comedy and humor are important parts of a vibrant culture. Roasting, banter, and lighthearted comedy are fully permitted on Truthworld, but they must remain within a "good manner."

**Permitted Roasting:**
• Friendly banter, comedic skits, and lighthearted roasts where all participating parties are in agreement or of good nature.
• Satirical commentary or criticism of public figures, public events, or widely-discussed ideas, provided the focus is on their actions, statements, or policies, rather than personal cruelty.

**Prohibited Bullying:**
• Cyberbullying, malicious harassment, doxing, or organized harassment campaigns.
• Content that demeans, dehumanizes, or targets private individuals with the intent to cause emotional distress, humiliation, or reputational damage.
• Hate speech, personal slurs, or attacks based on race, religion, gender, disability, or nationality.

4. BANNED LANGUAGE AND PROFANITY POLICY

Truthworld enforces a strict linguistic policy to keep all communication clean, professional, and respectful.

**Strictly Prohibited:**
• Unparliamentary words, slurs, and explicit vulgarities.
• Profanity, swearing, or excessive curse words in video titles, descriptions, thumbnails, or comments.
• Sexually explicit language or vulgar slang.

**Enforcement:**
• Our automated filters may flag or shadow-ban comments containing banned vocabulary.
• Creators are encouraged to use clean alternatives in their voiceovers and scripts. Excessive profanity in uploaded videos will lead to automated demonetization or content removal.

5. CONTENT POLICY - WHAT WE MODERATE AND WHAT WE DO NOT

Truthworld moderates HOW content is delivered — NOT what opinions, claims, or ideas are expressed. Our Credibility Engine handles truth verification. Our moderation handles family-friendly delivery.

**We DO NOT moderate (Credibility Engine handles these):**
• Misinformation, lies, false claims — fact-checked with source citations
• Conspiracy theories — scored and verified against evidence
• Glorification of controversial historical figures — context provided by Credibility Engine
• Historical revisionism, denial of events — verified against established sources
• Political extremism, radical views — context and fact-checks provided
• Controversial opinions on any topic — open debate platform
• Religious debates, theological arguments — open debate platform

**We DO moderate (family-friendly delivery):**
• Profanity, vulgar language, slurs, and explicit curse words
• Sexually explicit content
• Graphic visual violence and gore for entertainment
• Intense romantic/lustful content, romantic narratives, and all romance genres (strictly prohibited across Truthworld)
• Fashion & glamour modeling content: Vanity-centric fashion showcases, revealing attire, suggestive modeling, and catwalks (Fashion is permanently discontinued and prohibited as a platform category)
• Real-money gambling PROMOTION (referral codes, ads — not discussion)
• Step-by-step dangerous manufacturing instructions (weapons, drugs)
• Video gaming content: All video game walkthroughs, gameplay playthroughs, video game streaming, game recordings, and esports content (strictly prohibited across Truthworld)

**Fully Allowed Content Categories:**
• **Education & Science:** Lectures, tutorials, coding walkthroughs, historical research, science experiments.
• **Technology:** Software development, product reviews, hardware architecture, AI engineering, and technical analysis.
• **Short Films:** Drama, comedy sketches, narrative storytelling, creative indie cinema, and festival entries (must strictly comply with family-friendly and romance-free standards; romance is strictly barred).
• **Debates & Commentary:** Political debates, religious discussions, controversial opinions, historical analysis — any topic.
• **News, Documentaries & Sports:** Current events, independent journalism, historical documentaries, and sports coverage.
• **Sports & Athletics (Any and All Sports Allowed):** All athletic and physical sports are completely permitted and welcomed — including tournament coverage, match highlights, athletic training, competitive team sports (cricket, football, basketball, hockey, etc.), individual athletic disciplines, combat sports, extreme sports, fitness routines, and sports analysis. Any and all genuine physical sports content is fully allowed.
• **Lifestyle & Living:** Mindful habits, daily routines, home design, personal development, productivity systems, and wellness living.
• **Spirituality & Philosophy:** Mind, spirit, ethics, clean lifestyle guides.
• **DIY, Cooking & Art:** Crafting, cooking, digital art, creative designs.
• **Music & Songs:** Instrumental music, background tracks, clean songs (non-romantic themes).
• **Vlogs (Personal Chronicles & Video Diaries):** Daily life vlogs, personal narratives, creator journeys, Q&A sessions, life updates, travel chronicles, and behind-the-scenes content (family-friendly delivery required).
• **Movies & TV Shows:** Clean film reviews, trailers, cinematic analysis, television series discussions, and entertainment commentary (strictly zero romance or suggestive content).
• **Kids & Family:** Child-friendly educational content, storytelling, wholesome family activities, and parenting guidance.

6. SENSITIVE TOPICS - OPEN DEBATE RULES

Truthworld allows discussion of ANY sensitive topic. Our Credibility Engine fact-checks claims and provides viewers with sources and credibility scores. We only restrict HOW topics are discussed (family-friendly delivery) and direct PROMOTION of harmful activities.

**Real-Money Gambling & Betting:**
• Allowed: ALL discussion, debate, news, analysis, criticism, defense, glorification, business analysis, documentaries, legal debates — anything about gambling.
• Prohibited: ONLY direct promotion — referral codes, "sign up and play" ads, sponsored gambling content.
• Example: "How Hike's Rush platform generated ₹100Cr" = Allowed (analysis). "Download Rush! Use my code for ₹100 bonus!" = Prohibited (promotion).

**Video Gaming Prohibition & Physical Sports Policy:**
• Prohibited: All video gaming content is strictly prohibited across Truthworld. This includes gameplay playthroughs, video game walkthroughs, "Let's Play" recordings, esports competitions, gaming livestreams, speedruns, and gaming compilations. Truthworld maintains a strict focus on real-world knowledge, education, creative short films, and physical sports.
• Allowed (Any of Sports): Any and all forms of athletic and physical sports are completely allowed and encouraged. Whether team sports, track and field, racket sports, swimming, martial arts, outdoor adventures, competitive championships, or sports analysis, all sports content is fully permitted.

**Romance & Fashion Category Prohibition Policy:**
• Prohibited (Romance): Romance is completely prohibited as a content category, genre, or theme across Truthworld. All romantic stories, dating series, courtship media, romantic music videos, and opposite-gender romantic fiction are strictly prohibited. Truthworld is dedicated to intellectual truth, knowledge, productive dialogue, and clean family-friendly entertainment. Only clean familial love (father's love, mother's love, sibling bonds) and platonic friendships are welcomed.
• Prohibited / Discontinued (Fashion Category): The Fashion category has been permanently discontinued and removed from Truthworld. Content focusing on glamour modeling, revealing outfits, vanity lookbooks, and suggestive fashion hauls is strictly prohibited. Modest, functional, or cultural attire discussions in educational or historical contexts are permitted under Education or History, but fashion as a standalone category or vanity showcase is barred.

**Cybercrime, Hacking & Digital Security:**
• Allowed: ALL discussion — cybersecurity education, hacking news, phishing awareness, digital safety, investigative reporting.
• Prohibited: ONLY step-by-step malicious hacking tutorials with downloadable tools.

**Drugs & Substance Abuse:**
• Allowed: ALL discussion — drug awareness, addiction stories, pharmaceutical documentaries, harm reduction, news coverage.
• Prohibited: ONLY step-by-step drug manufacturing instructions.

**Violence, War & Extremism:**
• Allowed: ALL discussion — crime news, war documentaries, history lessons, conflict journalism, political extremism debates, counterterrorism analysis.
• Prohibited: ONLY graphic visual depictions of real violence for entertainment.

**Financial Scams & Fraud:**
• Allowed: ALL discussion — exposing scams, investor education, financial literacy, consumer warnings.
• Prohibited: ONLY active promotion of fraudulent schemes (pyramid schemes, pump-and-dump scams).

**Controversial Claims, Misinformation & Conspiracy Theories:**
• Allowed: ALL claims, opinions, theories, and debates — the Credibility Engine fact-checks everything and shows viewers the evidence.
• Not Prohibited: Nothing. The Credibility Engine handles all fact-checking. We do not censor claims.

7. REPORTING AND ENFORCEMENT PROCESS

We rely on both automated systems and our active community to maintain these standards.

• **Flagging Content:** Users can flag any video, description, or comment that violates these guidelines.
• **Review Process:** Flagged content is queued for human review by our moderation team.
• **Penalties:** Depending on the severity of the violation, actions may range from a friendly warning, restriction of upload access, content removal, or permanent ban.
• **Appeals:** If you believe your content was wrongly flagged or removed under these policies, you can submit an appeal through your Creator Studio dashboard within 14 days.

8. CREDIBILITY SCORING AND CLAIM ANALYSIS POLICY

To help viewers evaluate statements and maintain truthfulness without resorting to opaque censorship, Truthworld implements an Epistemic Credibility & Claim Verification System.

• **Claim-Level Grounding (No Binary "Fake" Labels):** Truthworld rejects blunt, monolithic "Fake" or "Banned" stamps. We extract discrete, atomic factual claims from audio speech and visual OCR, anchoring each claim to its exact timestamp in the video.
• **Authoritative Source Grounding:** Verified claims are cross-referenced with primary, authoritative databases (Official Gazettes, Government portals, PIB Fact Check, judicial records, and peer-reviewed scientific registries). Citing links are displayed directly inside the player overlay for independent public inspection.
• **Protection of Conscience & Religious Beliefs (Article 25):** We explicitly distinguish between empirical facts and personal or spiritual convictions. Theological claims, scriptural interpretations, and religious beliefs are categorized as faith-based context and are never subjected to empirical truth/falsity penalties.
• **Bilateral Creator Dispute Recourse (Audi Alteram Partem):** Creators have the statutory and platform right to contest any automated claim analysis. By using the in-app dispute dialog, creators can submit counter-citations. During review, claims transparently reflect a "Dispute Pending Review" status rather than a unilateral verdict.
• **Universal Intermediary Protection & Non-Destructive Overlays:** Truthworld acts purely as an Intermediary / Interactive Computer Service across global jurisdictions:
  - *United States:* Protected under Section 230 of the Communications Decency Act (47 U.S.C. § 230(c)) and DMCA Safe Harbor (17 U.S.C. § 512). Automated fact-check overlays constitute protected Good Samaritan transparency annotations.
  - *European Union & UK:* Governed under the Digital Services Act (Regulation (EU) 2022/2065, Articles 6, 16, 20, and 21), entitling users to internal appeals and certified out-of-court dispute settlement.
  - *India & APAC:* Protected under Section 79 of the Information Technology Act, 2000, and Rule 3 of the IT (Intermediary Guidelines) Rules, 2021.
  - *Universal Doctrine:* Fact-check overlays are non-destructive informational transparency layers (analogous to Community Notes) that do not alter the raw source video file or usurp creator authorship.
• **Good Faith Public Truth Defense (BNS Section 356 / IPC Section 499):** Algorithmic verification is conducted objectively for the public good, falling squarely within the First and Ninth Exceptions to Section 356 of the Bharatiya Nyaya Sanhita, 2023 (Section 499 IPC) regarding imputations of truth made in good faith for public interest.



9. COPYRIGHT AND INTELLECTUAL PROPERTY POLICY

Truthworld respects the intellectual property rights of others and expects its creators to do the same. Uploading videos containing copyrighted material without permission or authorization violates our terms.

**Copyright Reporting Form & Claims:**
To submit a formal statutory copyright infringement claim, you can use our public online takedown form at `/copyright-complaint` or email our designated team at hello@truthworld.in with the following information (the "Copyright Reporting Form"):
1. Your complete contact details (full name, email address, physical address, and phone number).
2. A clear description of the copyrighted work you believe has been infringed.
3. The exact URL(s) of the infringing content on Truthworld.
4. A statement that you have a good faith belief that use of the material in the manner complained of is not authorized by the copyright owner, its agent, or the law.
5. A statement that the information in the notification is accurate, and under penalty of perjury, that you are the owner or authorized to act on behalf of the owner of the copyright.
6. Your physical or electronic signature.

**The Takedown Process:**
Upon receipt of a valid and complete copyright takedown notice:
• **Prompt Removal:** We will promptly remove or disable access to the reported video.
• **Uploader Notification:** We will notify the uploader of the takedown claim and explain that their video was removed.
• **Counter-Notification:** If the uploader believes their content was removed in error (e.g., they have a license, fair use rights, or the work is public domain), they may submit a counter-notice to hello@truthworld.in containing their contact details, video URL, good faith explanation, and consent to court jurisdiction.
• **Restoration:** If a valid counter-notice is received, we will forward it to the claimant. If the claimant does not notify us of a lawsuit within 10-14 business days, we may restore the video.

**Repeat Infringer Policy (Three-Strikes System):**
Truthworld enforces a strict "Three-Strikes" repeat infringer policy:
• **Strike Issuance:** Each valid copyright takedown notice results in one copyright strike against the uploader's account.
• **Strike Consequences:**
  - *Strike 1:* A warning is issued. Uploading and other account features may be temporarily restricted for 7 days.
  - *Strike 2:* Account uploads are suspended for 14 days.
  - *Strike 3:* The account and all associated channels will be permanently terminated. The user is banned from creating new accounts.
• **Strike Expiration:** Copyright strikes expire after 90 days, provided the user does not receive another strike during that period. Resolved strikes (through counter-notification or claimant retracts) are removed immediately.
""";
}
