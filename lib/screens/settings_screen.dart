import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final timerManager = Provider.of<TimerManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Guide'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guide Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline, color: AppColors.accentCyan, size: 28),
                          const SizedBox(width: 12),
                          Text('How it works', style: AppStyles.heading2.copyWith(fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        '1',
                        'Grant Usage Stats Access',
                        'Allows our app to monitor which application is currently in the foreground and count your active usage time.',
                        timerManager.hasUsagePermission,
                      ),
                      const Divider(color: AppColors.borderDark, height: 24),
                      _buildStep(
                        '2',
                        'Enable Accessibility Service',
                        'Allows the background blocker to simulate the "Back" action to return to home screen once your daily limit is exceeded.',
                        timerManager.hasAccessibilityPermission,
                      ),
                      const Divider(color: AppColors.borderDark, height: 24),
                      _buildStep(
                        '3',
                        'Enable Notifications',
                        'Android requires a persistent low-priority notification so the tracking service is not terminated by the OS battery saver.',
                        timerManager.hasNotificationPermission,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Text('Developer Tools & Actions', style: AppStyles.subheading.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              
              // Actions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.refresh, color: AppColors.accentBlue),
                        title: const Text('Refresh Installed Apps', style: AppStyles.cardTitle),
                        subtitle: const Text('Query the package manager for launchable apps'),
                        onTap: () async {
                          await timerManager.loadInstalledApps();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('App list refreshed successfully')),
                          );
                        },
                      ),
                      const Divider(color: AppColors.borderDark, height: 1),
                      ListTile(
                        leading: const Icon(Icons.restore_outlined, color: AppColors.orange),
                        title: const Text('Force Reset Usage Stats', style: AppStyles.cardTitle),
                        subtitle: const Text('Reset usage to zero for all blocked apps'),
                        onTap: () async {
                          await timerManager.forceResetAll();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All app usage statistics reset!')),
                          );
                        },
                      ),
                      const Divider(color: AppColors.borderDark, height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_outlined, color: AppColors.red),
                        title: const Text('Clear All Cooldowns & Limits', style: AppStyles.cardTitle),
                        subtitle: const Text('Remove limits from all currently blocked apps'),
                        onTap: () async {
                          // Clear everything
                          for (var app in List.from(timerManager.blockedApps)) {
                            await timerManager.toggleAppBlock({'packageName': app.packageName, 'name': app.appName}, false);
                          }
                          await timerManager.forceResetAll();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All limits and cooldowns cleared!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Habit Control v1.0.0\nCreated for Digital Well-being',
                  style: AppStyles.caption.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description, bool isCompleted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.green.withOpacity(0.2) : AppColors.borderDark,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted ? AppColors.green : AppColors.textMuted,
              width: 1.5,
            ),
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: AppColors.green)
              : Text(
                  number,
                  style: AppStyles.captionBold.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
