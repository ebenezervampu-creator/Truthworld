import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

// Constants for consistent styling
const double kBorderRadius = 16.0;
const double kSmallPadding = 8.0;
const double kMediumPadding = 16.0;
const double kLargePadding = 24.0;

class HelpPage extends StatefulWidget {
  final bool isDashboard;
  const HelpPage({super.key, this.isDashboard = false});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final List<FAQItem> faqItems = [
    // General
    FAQItem(
      category: 'General',
      question: 'What is Truthworld?',
      answer: 'Truthworld is a next-generation video sharing and streaming platform designed for high-performance creators, learners, and communities. We support high-fidelity video streaming, reactive playlist management, custom channels, and local video downloads for offline access.',
    ),
    FAQItem(
      category: 'General',
      question: 'Is Truthworld free to use?',
      answer: 'Yes! Truthworld is entirely free for both viewers and creators. You can watch, like, comment, create playlists, and publish videos to your channel without any premium subscriptions or fees.',
    ),
    
    // Video & Uploads
    FAQItem(
      category: 'Uploads',
      question: 'How do I upload a video?',
      answer: 'Tap the "+" icon in the navigation bar or go to Creator Studio. Choose a video file from your device, add a catchy title, descriptive text, relevant tags, select a category, and tap "Upload". Your video will compile and publish instantly.',
    ),
    FAQItem(
      category: 'Uploads',
      question: 'Why did my video upload fail?',
      answer: 'Upload failures usually occur due to unstable internet connections or selecting an unsupported file format. We recommend using standard formats like MP4 or WebM. Ensure your network is active and stable before retrying.',
    ),
    FAQItem(
      category: 'Uploads',
      question: 'How do I edit or delete my uploaded videos?',
      answer: 'Navigate to your Channel or Creator Studio. Find the target video in your list, tap the three-dots options menu on the video card, and select either "Edit Details" or "Delete Video". Deleting a video is permanent and cannot be undone.',
    ),

    // Downloads
    FAQItem(
      category: 'Downloads',
      question: 'How do I download a video for offline watching?',
      answer: 'Open any video to view its playback screen. Below the player, tap the "Download" button. Choose your preferred quality resolution, and the download will initiate. Once complete, it will be stored locally in your library.',
    ),
    FAQItem(
      category: 'Downloads',
      question: 'Where can I find my downloaded videos?',
      answer: 'All downloaded videos are saved in your local app/browser database (IndexedDB) and are fully accessible without an internet connection. Navigate to Library > Downloads to view and play them offline.',
    ),
    FAQItem(
      category: 'Downloads',
      question: 'How do I delete a downloaded video to free up storage?',
      answer: 'Go to Library > Downloads. Locate the downloaded video you want to remove, click on its three-dots menu or action button, and select "Delete Download". This clears the local space instantly.',
    ),

    // Account & Security
    FAQItem(
      category: 'Account',
      question: 'How do I reset my password?',
      answer: 'If you are signed in, navigate to Settings > Account > Profile. If you are signed out, tap the "Forgot Password" link on the sign-in page, enter your registered email address, and follow the instructions sent to your inbox.',
    ),
    FAQItem(
      category: 'Account',
      question: 'How do I pause my watch and search history?',
      answer: 'Navigate to Settings > Privacy. Here, you can toggle the "Pause Watch History" and "Pause Search History" controls. When enabled, your playback positions and search queries will temporarily stop being saved.',
    ),
    FAQItem(
      category: 'Account',
      question: 'How do I delete my account?',
      answer: 'Go to Settings > Privacy > Delete Account. A confirmation dialog will warn you that this action permanently deletes your profile, channels, playlists, and uploaded videos. Confirm to complete deletion.',
    ),

    // Playlists & Playback
    FAQItem(
      category: 'Playback',
      question: 'How do I create and manage playlists?',
      answer: 'While watching any video, tap the "Save" button below the player. Select an existing playlist or choose "Create New Playlist" and give it a title. You can view, organize, and delete your playlists under the Library tab.',
    ),
    FAQItem(
      category: 'Playback',
      question: 'Can I autoplay the next video in a playlist?',
      answer: 'Yes! Navigate to Settings > Playback & Data, and turn on the "Autoplay" toggle. The player will automatically load and play the next recommended or playlist video when the current one finishes.',
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'General', 'Uploads', 'Downloads', 'Account', 'Playback'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FAQItem> get _filteredFAQItems {
    return faqItems.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: !widget.isDashboard ? _buildAppBar(context, colorScheme) : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              _buildHeaderSearch(colorScheme),
              _buildCategoryChips(colorScheme),
              Expanded(
                child: _buildFAQList(colorScheme),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
    return AppBar(
      title: Text(
        'Help & Support',
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
          fontSize: 20,
        ),
      ),
      backgroundColor: colorScheme.surface,
      elevation: 0,
      centerTitle: context.isMobile,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: colorScheme.onSurface,
          size: 20,
        ),
        onPressed: () => Get.back(),
      ),
    );
  }

  Widget _buildHeaderSearch(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(kMediumPadding, kSmallPadding, kMediumPadding, kMediumPadding),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How can we help you today?',
            style: GoogleFonts.roboto(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: kMediumPadding),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search help articles, topics...',
              prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(ColorScheme colorScheme) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kMediumPadding),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: kSmallPadding),
            child: ChoiceChip(
              label: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                }
              },
              selectedColor: colorScheme.primary,
              backgroundColor: AppTheme.secondaryBackground.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kBorderRadius),
                side: BorderSide(
                  color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFAQList(ColorScheme colorScheme) {
    final filtered = _filteredFAQItems;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(kLargePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: kMediumPadding),
              Text(
                'No results found',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: kSmallPadding),
              Text(
                'Try searching for something else or change categories.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(kMediumPadding),
      children: [
        ...filtered.map((item) => FAQTile(item: item)),
        const SizedBox(height: kLargePadding),
        _buildContactSupportCard(colorScheme),
      ],
    );
  }

  Widget _buildContactSupportCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(kLargePadding),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBackground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kBorderRadius),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.support_agent_rounded, size: 48, color: colorScheme.primary),
          const SizedBox(height: kSmallPadding),
          Text(
            'Still need help?',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: kSmallPadding),
          Text(
            'Our dedicated support team is available 24/7 to assist you with any questions or technical issues.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: kMediumPadding),
          ElevatedButton.icon(
            onPressed: () {
              Get.snackbar(
                'Support Team',
                'Support email: support@truthworld.app',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: colorScheme.primary,
                colorText: Colors.white,
              );
            },
            icon: const Icon(Icons.mail, color: Colors.white),
            label: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: kLargePadding, vertical: kMediumPadding),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }
}

class FAQItem {
  final String category;
  final String question;
  final String answer;

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class FAQTile extends StatefulWidget {
  final FAQItem item;

  const FAQTile({super.key, required this.item});

  @override
  State<FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<FAQTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: kSmallPadding),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kBorderRadius),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      color: AppTheme.secondaryBackground.withValues(alpha: 0.05),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(widget.item.question),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: kMediumPadding,
            vertical: kSmallPadding,
          ),
          title: Text(
            widget.item.question,
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          trailing: RotationTransition(
            turns: _animation,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kMediumPadding,
                0,
                kMediumPadding,
                kMediumPadding,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  widget.item.answer,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
          onExpansionChanged: (expanded) {
            if (expanded) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          },
        ),
      ),
    );
  }
}
