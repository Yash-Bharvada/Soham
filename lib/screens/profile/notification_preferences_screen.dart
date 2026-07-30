import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _emailReminders = true;
  bool _pushReminders = true;
  bool _overdueAlerts = true;
  bool _docUpdates = true;

  @override
  Widget build(BuildContext context) {
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
                        Text('Notification preferences',
                            style: AppTextStyles.headerTitle),
                        Text('Manage email & mobile notification alerts',
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
                Container(
                  decoration: AppDecorations.card,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _emailReminders,
                        onChanged: (v) => setState(() => _emailReminders = v),
                        activeColor: AppColors.navy,
                        title: Text('Email Rent Reminders',
                            style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                        subtitle: Text(
                            'Receive rent due notices at chetnabharvada1234@gmail.com',
                            style: AppTextStyles.caption),
                        secondary: const Icon(Icons.email_outlined,
                            color: AppColors.navy, size: 22),
                      ),
                      const Divider(height: 1, indent: 52),
                      SwitchListTile(
                        value: _pushReminders,
                        onChanged: (v) => setState(() => _pushReminders = v),
                        activeColor: AppColors.navy,
                        title: Text('Mobile Push Notifications',
                            style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                        subtitle: Text('Get in-app reminders on your phone',
                            style: AppTextStyles.caption),
                        secondary: const Icon(Icons.notifications_active_outlined,
                            color: AppColors.navy, size: 22),
                      ),
                      const Divider(height: 1, indent: 52),
                      SwitchListTile(
                        value: _overdueAlerts,
                        onChanged: (v) => setState(() => _overdueAlerts = v),
                        activeColor: AppColors.navy,
                        title: Text('Overdue Alerts',
                            style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                        subtitle: Text(
                            'High priority alerts when rent crosses due date',
                            style: AppTextStyles.caption),
                        secondary: const Icon(Icons.warning_amber_outlined,
                            color: AppColors.red, size: 22),
                      ),
                      const Divider(height: 1, indent: 52),
                      SwitchListTile(
                        value: _docUpdates,
                        onChanged: (v) => setState(() => _docUpdates = v),
                        activeColor: AppColors.navy,
                        title: Text('Document Status Updates',
                            style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                        subtitle: Text(
                            'Notifications when owner verifies or rejects Aadhaar',
                            style: AppTextStyles.caption),
                        secondary: const Icon(Icons.badge_outlined,
                            color: AppColors.navy, size: 22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Preferences saved successfully')),
                    );
                    Navigator.pop(context);
                  },
                  child: Text('Save preferences',
                      style: AppTextStyles.labelLarge),
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
