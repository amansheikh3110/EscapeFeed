import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../models/app_limit.dart';
import '../utils/constants.dart';
import '../services/usage_tracker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh permissions and states when user returns to app
      final timerManager = Provider.of<TimerManager>(context, listen: false);
      timerManager.checkPermissions();
      timerManager.loadUsageStats();
      timerManager.checkServiceStatus();
    }
  }

  // Format milliseconds to hours and minutes
  String _formatDuration(int millis) {
    final duration = Duration(milliseconds: millis);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerManager = Provider.of<TimerManager>(context);
    final blockedApps = timerManager.blockedApps;
    
    final bool isServiceReady = timerManager.hasUsagePermission && 
                                timerManager.hasAccessibilityPermission && 
                                timerManager.hasNotificationPermission;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HABIT CONTROL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Permission Warning Panel
              if (!isServiceReady) ...[
                const SizedBox(height: 8),
                _buildPermissionAlertCard(context, timerManager),
              ],
              
              const SizedBox(height: 16),
              
              // 2. Service Status Panel
              _buildServiceStatusCard(context, timerManager, isServiceReady),
              
              const SizedBox(height: 24),
              
              // 3. Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active App Limits', style: AppStyles.subheading.copyWith(color: AppColors.textPrimary)),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/selector'),
                    icon: const Icon(Icons.edit, size: 16, color: AppColors.accentCyan),
                    label: const Text('Manage', style: TextStyle(color: AppColors.accentCyan)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 4. Blocked Apps List
              if (blockedApps.isEmpty)
                _buildEmptyStateCard(context)
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: blockedApps.length,
                  itemBuilder: (context, index) {
                    final appLimit = blockedApps[index];
                    return _buildAppLimitListItem(context, appLimit, timerManager);
                  },
                ),
                
              const SizedBox(height: 80), // spacer for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/selector'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentCyan.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.add, color: AppColors.bgDark),
              const SizedBox(width: 8),
              Text(
                'Add App Limit',
                style: AppStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgDark,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPermissionAlertCard(BuildContext context, TimerManager timerManager) {
    return Card(
      color: AppColors.orange.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.orange, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 28),
                const SizedBox(width: 12),
                Text('Permissions Required', style: AppStyles.heading2.copyWith(fontSize: 18, color: AppColors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'For background blocking to work correctly, please grant the following permissions:',
              style: AppStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            
            // Usage Permission
            if (!timerManager.hasUsagePermission)
              _buildPermissionButton(
                'Grant Usage Access',
                'Required to track foreground app time',
                () => UsageTracker.requestUsageStatsPermission(),
              ),
              
            // Accessibility Permission
            if (!timerManager.hasAccessibilityPermission) ...[
              if (!timerManager.hasUsagePermission) const SizedBox(height: 12),
              _buildPermissionButton(
                'Enable Accessibility Service',
                'Required to close apps when limits finish',
                () => UsageTracker.openAccessibilitySettings(),
              ),
            ],
            
            // Notifications Permission
            if (!timerManager.hasNotificationPermission) ...[
              if (!timerManager.hasUsagePermission || !timerManager.hasAccessibilityPermission) const SizedBox(height: 12),
              _buildPermissionButton(
                'Enable Notification Permission',
                'Required to run background service',
                () => timerManager.requestNotificationPermission(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionButton(String title, String subtitle, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cardDark,
        foregroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppStyles.body.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildServiceStatusCard(BuildContext context, TimerManager timerManager, bool isReady) {
    final active = timerManager.isTrackingActive;
    
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: active ? AppColors.accentCyan.withOpacity(0.3) : AppColors.borderDark,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.accentCyan.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'MONITORING ACTIVE' : 'BLOCKER PAUSED',
                      style: AppStyles.heading2.copyWith(
                        fontSize: 18,
                        letterSpacing: 1.0,
                        color: active ? AppColors.accentCyan : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      active ? 'Limits are actively enforced' : 'Apps will not be blocked',
                      style: AppStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Switch(
                  value: active,
                  activeColor: AppColors.accentCyan,
                  activeTrackColor: AppColors.accentBlue.withOpacity(0.4),
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.borderDark,
                  onChanged: isReady
                      ? (val) => timerManager.toggleTrackingService(val)
                      : (val) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please grant all required permissions first'),
                              backgroundColor: AppColors.orange,
                            ),
                          );
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.hourglass_empty_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'No Apps Limited Yet',
                style: AppStyles.cardTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Select apps like YouTube or social media, set daily usage limits, and reclaim your time!',
                style: AppStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/selector'),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Apps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.borderDark,
                  foregroundColor: AppColors.accentCyan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppLimitListItem(BuildContext context, AppLimit app, TimerManager timerManager) {
    final bool cooldown = app.isInCooldown;
    final double ratio = cooldown ? app.cooldownRatio : app.usageRatio;
    final Color progressColor = cooldown ? AppColors.red : (ratio > 0.8 ? AppColors.orange : AppColors.accentCyan);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: cooldown ? AppColors.red.withOpacity(0.5) : AppColors.borderDark,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Row with App Name, Icon, Status and Toggle/Reset Option
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: progressColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: progressColor.withOpacity(0.3), width: 1.5),
                        ),
                        child: Text(
                          app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                          style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.appName, style: AppStyles.cardTitle),
                            const SizedBox(height: 2),
                            Text(
                              cooldown ? 'COOLDOWN ACTIVE' : 'LIMIT ACTIVE',
                              style: AppStyles.caption.copyWith(
                                color: progressColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Reset Button (useful for developers and testing)
                IconButton(
                  icon: const Icon(Icons.lock_open_rounded, size: 20, color: AppColors.textSecondary),
                  tooltip: 'Reset App Limit',
                  onPressed: () => _showResetConfirmDialog(context, app, timerManager),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: AppColors.borderDark,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Timers & Stats details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (cooldown) ...[
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: AppColors.red),
                      const SizedBox(width: 6),
                      Text(
                        'Blocked for: ${_formatDuration(app.remainingCooldownMillis)}',
                        style: AppStyles.caption.copyWith(color: AppColors.red, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    'Cooldown resets: ${_formatDuration(app.cooldownMillis)}',
                    style: AppStyles.caption,
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.timelapse_rounded, size: 16, color: AppColors.accentCyan),
                      const SizedBox(width: 6),
                      Text(
                        'Used: ${_formatDuration(app.usedMillis)}',
                        style: AppStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    'Limit: ${app.limitMinutes}m',
                    style: AppStyles.captionBold,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmDialog(BuildContext context, AppLimit app, TimerManager timerManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        title: Text('Reset ${app.appName}?', style: AppStyles.heading2),
        content: Text(
          'This will reset the tracked usage back to 0 and immediately clear any active cooldown lock. Confirm?',
          style: AppStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              await timerManager.resetAppUsage(app.packageName);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan.withOpacity(0.12),
              foregroundColor: AppColors.accentCyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}