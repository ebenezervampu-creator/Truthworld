import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/content/presentation/controllers/copyright_complaint_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class CopyrightComplaintScreen extends GetView<CopyrightComplaintController> {
  const CopyrightComplaintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        final horizontalPadding =
            isDesktop ? constraints.maxWidth * 0.15 : 16.0;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
              onPressed: Get.back,
            ),
            title: const Text(
              'Copyright Infringement Notice',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: Obx(() {
            final complaintId = controller.submittedComplaintId.value;
            if (complaintId != null) {
              return _buildSuccessView(context, complaintId);
            }

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegalNoticeBanner(context),
                    _buildAuthNotice(context),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      context,
                      '1. Complainant Details',
                      'Information of the copyright owner or authorized representative.',
                    ),
                    const SizedBox(height: 16),
                    _buildClaimantTypeDropdown(context),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: controller.nameController,
                      label: 'Full Legal Name *',
                      hint: 'Your full legal name',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Full legal name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: controller.orgController,
                      label: 'Organization / Company Name (Optional)',
                      hint: 'Company or entity you represent, if applicable',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: controller.emailController,
                            label: 'Contact Email Address *',
                            hint: 'email@example.com',
                            keyboardType: TextInputType.emailAddress,
                            inputFormatters: const [],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email address is required';
                              }
                              if (!v.contains('@') || !v.contains('.')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextFormField(
                            controller: controller.phoneController,
                            label: 'Contact Phone Number *',
                            hint: '+91 98765 43210',
                            keyboardType: TextInputType.phone,
                            inputFormatters: const [],
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Phone number is required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: controller.addressController,
                      label: 'Physical Mailing Address *',
                      hint: 'Street address, City, State, Postal Code, Country',
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Physical mailing address is required'
                          : null,
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      context,
                      '2. Original Copyrighted Work',
                      'Describe the work being infringed upon.',
                    ),
                    const SizedBox(height: 16),
                    _buildWorkTypeDropdown(context),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: controller.workTitleController,
                      label: 'Title / Description of Original Work *',
                      hint:
                          'e.g. Original song, short film, educational lecture',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Title/description of work is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: controller.workUrlController,
                      label:
                          'Link to Original Work / Registration Number (Optional)',
                      hint:
                          'https://... or Copyright Registration No. with jurisdiction',
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      context,
                      '3. Infringing Content on Truthworld',
                      'Specify the material to be reviewed and removed.',
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: controller.infringingUrlController,
                      label: 'Truthworld Video URL or Video ID *',
                      hint:
                          'https://truthworld.in/watch/VIDEO_ID or VIDEO_ID',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Truthworld Video URL or ID is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: controller.timestampsController,
                      label: 'Timestamp / Portion Infringed (Optional)',
                      hint: 'e.g. 01:23 - 04:56 or Entire Video',
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: controller.detailsController,
                      label: 'Additional Infringement Details *',
                      hint:
                          'Explain how the material infringes your copyright...',
                      maxLines: 4,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please explain the nature of infringement'
                          : null,
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      context,
                      '4. Statutory Legal Declarations',
                      'You must affirmatively agree to each statement under Indian and international law.',
                    ),
                    const SizedBox(height: 16),
                    _buildDeclarationCheckbox(
                      value: controller.declGoodFaith.value,
                      onChanged: (val) =>
                          controller.setDeclGoodFaith(val ?? false),
                      title:
                          'Good Faith Belief: I have a good faith belief that use of the material in the manner complained of is not authorized by the copyright owner, its agent, or the law.',
                    ),
                    _buildDeclarationCheckbox(
                      value: controller.declAccuracy.value,
                      onChanged: (val) =>
                          controller.setDeclAccuracy(val ?? false),
                      title:
                          'Accuracy & Authority: The information in this notification is accurate, and under penalty of perjury, I state that I am the owner, or an agent authorized to act on behalf of the owner, of an exclusive right that is allegedly infringed.',
                    ),
                    _buildDeclarationCheckbox(
                      value: controller.declForwarding.value,
                      onChanged: (val) =>
                          controller.setDeclForwarding(val ?? false),
                      title:
                          'Disclosure & Counter-Notification: I understand that a complete copy of this legal notice (including my contact details) may be provided to the creator who posted the content to allow them to respond or submit a statutory counter-notification.',
                    ),
                    _buildDeclarationCheckbox(
                      value: controller.declLiability.value,
                      onChanged: (val) =>
                          controller.setDeclLiability(val ?? false),
                      title:
                          'Legal Liability Warning: I understand that submitting a false, fraudulent, or bad-faith takedown notification may subject me to legal liability, damages, and costs under the Copyright Act, 1957, the IT Act, 2000, and DMCA §512(f).',
                    ),
                    const SizedBox(height: 24),
                    _buildTextFormField(
                      controller: controller.signatureController,
                      label: 'Electronic Signature (Full Legal Name) *',
                      hint:
                          'Type your full legal name to serve as your digital signature',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Electronic signature is required'
                          : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: controller.isSubmitting.value
                            ? null
                            : controller.submitComplaint,
                        icon: controller.isSubmitting.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.gavel_rounded,
                                color: Colors.black,
                              ),
                        label: Text(
                          controller.isSubmitting.value
                              ? 'Submitting Notice...'
                              : (FirebaseAuth.instance.currentUser == null
                                  ? 'Sign In to Submit Notice'
                                  : 'Submit Copyright Infringement Notice'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildGrievanceContactFooter(context),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildLegalNoticeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statutory Notice Submission (Rule 75 Copyright Rules / IT Rules 2021)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This form allows copyright holders and their authorized representatives to notify TowerVSP Services (OPC) Private Limited of alleged copyright infringement under the Copyright Act, 1957, the IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, and the DMCA. Submissions will receive an acknowledgment within 24 hours and will be reviewed in accordance with statutory guidelines.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthNotice(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sign in required: To file an official copyright infringement notice under DMCA / Rule 75, you must be signed in with a verified TruthWorld account.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildClaimantTypeDropdown(BuildContext context) {
    final options = [
      'Copyright Owner',
      'Authorized Agent / Representative',
      'Legal Counsel',
      'Exclusive Licensee',
    ];

    return Obx(
      () => DropdownButtonFormField<String>(
        value: controller.claimantType.value,
        decoration: InputDecoration(
          labelText: 'Relationship to Copyright Owner *',
          filled: true,
          fillColor: AppColors.bgSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
        ),
        items: options.map((opt) {
          return DropdownMenuItem(
            value: opt,
            child: Text(opt),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) controller.setClaimantType(val);
        },
      ),
    );
  }

  Widget _buildWorkTypeDropdown(BuildContext context) {
    final options = [
      'Video',
      'Audio / Music / Sound Recording',
      'Artwork / Graphic / Image',
      'Literary / Text / Script',
      'Software / Code',
      'Other Proprietary Work',
    ];

    return Obx(
      () => DropdownButtonFormField<String>(
        value: controller.workType.value,
        decoration: InputDecoration(
          labelText: 'Type of Copyrighted Work *',
          filled: true,
          fillColor: AppColors.bgSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
        ),
        items: options.map((opt) {
          return DropdownMenuItem(
            value: opt,
            child: Text(opt),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) controller.setWorkType(val);
        },
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters ?? TruthworldTextInputFormatters.standard,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 13,
        ),
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brand),
        ),
      ),
    );
  }

  Widget _buildDeclarationCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value
                  ? AppColors.brand
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.brand,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrievanceContactFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Direct Grievance & Copyright Contacts',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Copyright Designated Agent: hello@truthworld.in\n'
            'Grievance Officer: Vampu Ebenezer (hello@truthworld.in | +91 9390617877)\n'
            'Entity: TowerVSP Services (OPC) Private Limited (CIN: U63111TS2025OPC207488)\n'
            'Registered Office: Ramaram, Yadadri Bhuvanagiri, Telangana - 508116, India\n'
            'Appeals Portal: Grievance Appellate Committee (https://gac.gov.in)',
            style: TextStyle(fontSize: 12, height: 1.6, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, String complaintId) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'Complaint Submitted Successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Tracking Reference: $complaintId',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your notice has been recorded and transmitted to the Truthworld Legal & Grievance Department (TowerVSP Services (OPC) Private Limited). Under Rule 3(2) of the Information Technology Rules, 2021, statutory receipt acknowledgment is registered within 24 hours, and complaints are disposed of within 15 days.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: Get.back,
              child: const Text(
                'Back to Platform',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
