import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _openUpi(BuildContext context, String scheme) async {
    final upiId = dotenv.env['UPI_ID'] ?? 'chetnabharvada1234@okhdfcbank';
    final uri = Uri.parse('$scheme://pay?pa=$upiId&pn=Soham+PG&cu=INR');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('App ($scheme) not found on device')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final upiId = dotenv.env['UPI_ID'] ?? 'chetnabharvada1234@okhdfcbank';

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
                        Text('Payment methods', style: AppTextStyles.headerTitle),
                        Text('Supported UPI & direct payment options',
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
                // ── Default UPI ID ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.navy.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code,
                                color: AppColors.navy, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Primary UPI ID', style: AppTextStyles.caption),
                                Text(upiId,
                                    style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_outlined,
                                color: AppColors.lightBlue, size: 20),
                            onPressed: () =>
                                _copyToClipboard(context, upiId, 'UPI ID'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Direct App Quick Pay ──────────────────────────────
                Text('Instant UPI apps', style: AppTextStyles.cardTitle),
                const SizedBox(height: 10),

                Container(
                  decoration: AppDecorations.card,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.payment,
                            color: AppColors.navy, size: 24),
                        title: const Text('Google Pay (GPay)'),
                        subtitle: const Text('Direct launch via upi://pay'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => _openUpi(context, 'upi'),
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: const Icon(Icons.phone_android,
                            color: AppColors.navy, size: 24),
                        title: const Text('PhonePe'),
                        subtitle: const Text('Direct launch via phonepe://pay'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => _openUpi(context, 'phonepe'),
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet,
                            color: AppColors.navy, size: 24),
                        title: const Text('Paytm / Any UPI App'),
                        subtitle: const Text('Copy UPI ID & pay'),
                        trailing: const Icon(Icons.copy, size: 18),
                        onTap: () => _copyToClipboard(context, upiId, 'UPI ID'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Owner Contact & Account Info ──────────────────────
                Text('Owner Contact & Details', style: AppTextStyles.cardTitle),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card,
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Owner Name',
                        value: 'Chetna Bharvada',
                      ),
                      const Divider(height: 20),
                      _DetailRow(
                        icon: Icons.email_outlined,
                        label: 'Support Email',
                        value: 'chetnabharvada1234@gmail.com',
                        onCopy: () => _copyToClipboard(
                            context, 'chetnabharvada1234@gmail.com', 'Email'),
                      ),
                      const Divider(height: 20),
                      _DetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        value: '8160695640',
                        onCopy: () => _copyToClipboard(
                            context, '8160695640', 'Phone Number'),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.navy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(value,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
            ],
          ),
        ),
        if (onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: const Icon(Icons.copy_outlined,
                size: 18, color: AppColors.lightBlue),
          ),
      ],
    );
  }
}
