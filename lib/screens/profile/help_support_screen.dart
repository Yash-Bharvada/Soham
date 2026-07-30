import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Soham%20PG%20Inquiry');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    const email = 'chetnabharvada1234@gmail.com';
    const phone = '8160695640';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Navy Header ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: AppDimensions.screenPadding,
                right: AppDimensions.screenPadding,
                bottom: 24,
              ),
              decoration: AppDecorations.navyGradient,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Help & Support', style: AppTextStyles.headerTitle),
                        Text('We are here to assist you 24/7',
                            style: AppTextStyles.headerSubtitle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Contact Cards ──────────────────────────────────────
                Text('Get in Touch', style: AppTextStyles.cardTitle),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _ContactCard(
                        icon: Icons.phone_outlined,
                        title: 'Call Us',
                        subtitle: phone,
                        buttonText: 'Call now',
                        color: AppColors.navy,
                        onTap: () => _makeCall(phone),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ContactCard(
                        icon: Icons.email_outlined,
                        title: 'Email Us',
                        subtitle: email,
                        buttonText: 'Send email',
                        color: AppColors.lightBlue,
                        onTap: () => _sendEmail(email),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── FAQ Section ────────────────────────────────────────
                Text('Frequently Asked Questions', style: AppTextStyles.cardTitle),
                const SizedBox(height: 10),

                Container(
                  decoration: AppDecorations.card,
                  child: Column(
                    children: [
                      _FaqTile(
                        question: 'When is rent due every month?',
                        answer:
                            'Rent is due on the 1st of every calendar month. Notifications are sent 2 days prior.',
                      ),
                      const Divider(height: 1, indent: 16),
                      _FaqTile(
                        question: 'How do I pay rent?',
                        answer:
                            'Go to the Payment tab, scan the GPay QR code or launch GPay / PhonePe directly, then upload the screenshot for owner verification.',
                      ),
                      const Divider(height: 1, indent: 16),
                      _FaqTile(
                        question: 'What KYC documents are required?',
                        answer:
                            'You must upload 3 Aadhaar card documents: Your Aadhaar, Father\'s Aadhaar, and Mother\'s Aadhaar in the Documents tab.',
                      ),
                      const Divider(height: 1, indent: 16),
                      _FaqTile(
                        question: 'Who do I contact for maintenance?',
                        answer:
                            'Call or email the owner directly at $phone or $email.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                buttonText,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        question,
        style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
      ),
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
      expandedAlignment: Alignment.topLeft,
      children: [
        Text(
          answer,
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}
