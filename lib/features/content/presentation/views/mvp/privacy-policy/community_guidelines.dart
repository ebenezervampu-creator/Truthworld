import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

class CommunityGuidelinesPage extends StatefulWidget {
  const CommunityGuidelinesPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<CommunityGuidelinesPage> createState() =>
      _CommunityGuidelinesPageState();
}

class _CommunityGuidelinesPageState extends State<CommunityGuidelinesPage> {
  final ScrollController _scrollController = ScrollController();
  final RxList<GuidelineSection> _sections = <GuidelineSection>[].obs;
  final RxString _introContent = ''.obs;
  final RxBool _guidelinesAccepted = false.obs;

  @override
  void initState() {
    super.initState();
    _parseGuidelinesText();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Parses the giant text string into a structured list of sections.
  void _parseGuidelinesText() {
    // Regex to find headings like "1. CORE PRINCIPLES..." or "2. LUST-FREE AND MODERATE MARRIAGE/ROMANCE POLICY..."
    final regex = RegExp(r'\n(\d{1,2}\. [A-Z0-9_\-% /]+)\n', multiLine: true);
    final matches = regex.allMatches(_guidelinesText).toList();

    if (matches.isEmpty) {
      _introContent.value = _guidelinesText;
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
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Render the introductory text first
            SelectableText(_introContent.value, style: bodyTextStyle),
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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
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
                    Material(
                      type: MaterialType.transparency,
                      child: CheckboxListTile(
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
                        ElevatedButton(
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
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 1,
            shadowColor: AppColors.bgPage.withValues(alpha: 0.1),
            leading: (widget.isDashboard || isDesktop)
                ? IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () {
                      if (widget.isDashboard) {
                        Get.find<HomeController>().sideNavSelectedIndex.value =
                            HomeController.indexSettings;
                      } else {
                        Get.back();
                      }
                    },
                  )
                : null,
            title: Text(
              'Community Guidelines | Truthworld',
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
          drawer: isDesktop
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
        );
      },
    );
  }

  // Guidelines text (compliant with standard formatting)
  static const String _guidelinesText = """
COMMUNITY GUIDELINES

Last Updated: July 24, 2026
Effective Date: July 24, 2026

Welcome to Truthworld. Our mission is to foster a truthful, knowledge-centric, and productive community through open debate and verified information.

Truthworld is an OPEN DEBATE PLATFORM. We VERIFY claims — we do not censor them. Our Credibility Engine fact-checks every claim in every video, provides source citations, and displays a credibility score alongside the video. Channels can upload debates, controversial opinions, and discuss any topic — our job is to verify, not to silence.

All content uploaded to the Platform must comply with these guidelines. We moderate HOW content is delivered (it must be family-friendly), NOT what opinions are expressed. Violations of delivery standards may result in content removal, restrictions on account privileges, or permanent account termination.

1. CORE PRINCIPLES - OPEN DEBATE PLATFORM

Truthworld is designed as an open space for truth-seeking through debate, education, clean entertainment, self-improvement, technology, spirituality, news, and factual sharing.

We believe in:
• **Open Debate:** Any topic can be discussed — politics, history, religion, science, conspiracy theories, controversial figures, and more. We verify claims; we do not censor opinions.
• **Credibility, Not Censorship:** Our Credibility Engine fact-checks claims and provides sources. Viewers see the truth alongside every claim.
• **Family-Friendly Delivery:** While any topic is allowed, HOW it is said must be clean, civil, and appropriate for all audiences. No profanity, no explicit content.
• **Respect Through Clean Language:** Passionate debate is welcome. Vulgar language and slurs are not.

2. LUST-FREE AND ROMANCE-FREE POLICY

To maintain our focus on productivity, knowledge, family-friendliness, and clean culture, Truthworld is a lust-free and romance-free platform. Romantic content, dating themes, and love/romance stories between opposite genders are strictly prohibited under all circumstances, even within or after marriage.

**Permitted Content:**
• Wedding documentaries, marriage ceremonies, and general family/marriage content (focusing on familial love, such as father's love, mother's love, or sibling bonds).
• Scientific, biological, medical, or sociological discussions of relationships or human biology, provided they are presented in a clinical, educational, or academic manner.
• Healthy friendships, community bonding, and professional teamwork.

**Prohibited Content:**
• Romantic stories, movies, short films, songs, or web series focusing on romance, dating themes, hookups, or courtship (whether before, within, or after marriage).
• Any romantic couples or opposite-sex romance stories, including honeymoons and romantic trips.
• Content depicting, encouraging, or celebrating physical intimacy, dating apps, or lustful behavior.
• Highly suggestive attire, gestures, and behavior designed to invoke physical attraction, romance, or lust.

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
• Intense romantic/lustful content
• Real-money gambling PROMOTION (referral codes, ads — not discussion)
• Step-by-step dangerous manufacturing instructions (weapons, drugs)

**Fully Allowed Content Categories:**
• **Education & Science:** Lectures, tutorials, coding walkthroughs, historical research, science experiments.
• **Technology & Gaming:** Software development, product reviews, clean gaming playthroughs, technical analysis.
• **Debates & Commentary:** Political debates, religious discussions, controversial opinions, historical analysis — any topic.
• **News, Documentaries & Sports:** Current events, independent journalism, historical documentaries, sports.
• **Spirituality & Philosophy:** Mind, spirit, ethics, clean lifestyle guides.
• **DIY, Cooking & Art:** Crafting, cooking, digital art, creative designs.
• **Music & Songs:** Instrumental music, background tracks, clean songs (non-romantic themes).

6. SENSITIVE TOPICS - OPEN DEBATE RULES

Truthworld allows discussion of ANY sensitive topic. Our Credibility Engine fact-checks claims and provides viewers with sources and credibility scores. We only restrict HOW topics are discussed (family-friendly delivery) and direct PROMOTION of harmful activities.

**Real-Money Gambling & Betting:**
• Allowed: ALL discussion, debate, news, analysis, criticism, defense, glorification, business analysis, documentaries, legal debates — anything about gambling.
• Prohibited: ONLY direct promotion — referral codes, "sign up and play" ads, sponsored gambling content.
• Example: "How Hike's Rush platform generated ₹100Cr" = Allowed (analysis). "Download Rush! Use my code for ₹100 bonus!" = Prohibited (promotion).

**Violent/Crime-Themed Games:**
• Allowed: Game reviews, critiques, gaming industry analysis, esports, academic discussions.
• Prohibited: Kill compilations glorifying in-game violence as entertainment.

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

To help viewers evaluate statements and maintain truthfulness, Truthworld implements a Credibility Scoring System.

• **Fact-Checking & Source Citations:** We extract key claims from uploaded media and use LLM (Large Language Model) APIs and public databases to check statements against reliable sources. These sources and citations are displayed alongside the video.
• **Informational Nature:** Truthworld provides these automated checks and credibility scores for informational, academic, and educational purposes only. We just show sources and verify claims. Truthworld is not liable for any errors or inaccuracies in the automated evaluations or citations.
• **Intermediary Shield:** Creators are responsible for the truthfulness of their content. Truthworld serves purely as an intermediary, utilizes third-party LLM APIs, and does not assume responsibility or legal liability for any claims or disputes arising from video content or credibility metrics.

9. COPYRIGHT AND INTELLECTUAL PROPERTY POLICY

Truthworld respects the intellectual property rights of others and expects its creators to do the same. Uploading videos containing copyrighted material without permission or authorization violates our terms.

**Copyright Reporting Form & Claims:**
To submit a copyright infringement claim, please email our designated copyright agent at ebenezervampu@towervsp.com with the following information (the "Copyright Reporting Form"):
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
• **Counter-Notification:** If the uploader believes their content was removed in error (e.g., they have a license, fair use rights, or the work is public domain), they may submit a counter-notice to ebenezervampu@towervsp.com containing their contact details, video URL, good faith explanation, and consent to court jurisdiction.
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
