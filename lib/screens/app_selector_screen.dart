import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/timer_manager.dart';
import '../utils/constants.dart';


class AppSelectorScreen extends StatefulWidget {
  const AppSelectorScreen({super.key});

  @override
  State<AppSelectorScreen> createState() => _AppSelectorScreenState();
}

class _AppSelectorScreenState extends State<AppSelectorScreen> {
  String _searchQuery = '';
  String? _expandedPackage;

  @override
  Widget build(BuildContext context) {
    final timerManager = Provider.of<TimerManager>(context);
    final installed = timerManager.installedApps;
    final blocked = timerManager.blockedApps;
    
    // Filter apps by search query
    final filteredApps = installed.where((app) {
      final name = (app['name'] as String? ?? '').toLowerCase();
      final pkg = (app['packageName'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || pkg.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add App Blocker'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark, width: 1.5),
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: AppStyles.body,
                decoration: const InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          
          // Apps List
          Expanded(
            child: timerManager.isLoadingApps
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    ),
                  )
                : filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          'No apps found',
                          style: AppStyles.subheading.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final pkg = app['packageName'] as String;
                          final name = app['name'] as String;
                          final isSystem = app['isSystem'] as bool? ?? false;
                          
                          // Check if app is already limited
                          final limitIndex = blocked.indexWhere((a) => a.packageName == pkg);
                          final isLimited = limitIndex != -1;
                          final appLimit = isLimited ? blocked[limitIndex] : null;
                          final isExpanded = _expandedPackage == pkg;

                          // Dynamic avatar color
                          final colorIndex = name.isNotEmpty ? name.codeUnitAt(0) % 5 : 0;
                          final avatarColor = [
                            AppColors.accentBlue,
                            AppColors.accentCyan,
                            AppColors.accentPurple,
                            AppColors.accentMagenta,
                            AppColors.green
                          ][colorIndex];

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: isLimited
                                  ? () {
                                      setState(() {
                                        _expandedPackage = isExpanded ? null : pkg;
                                      });
                                    }
                                  : null,
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: avatarColor.withOpacity(0.2),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(name, style: AppStyles.cardTitle),
                                        ),
                                        if (isSystem)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.textMuted.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'SYSTEM',
                                              style: TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      pkg,
                                      style: AppStyles.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Switch(
                                      value: isLimited,
                                      activeColor: AppColors.accentCyan,
                                      activeTrackColor: AppColors.accentBlue.withOpacity(0.4),
                                      inactiveThumbColor: AppColors.textMuted,
                                      inactiveTrackColor: AppColors.borderDark,
                                      onChanged: (val) async {
                                        await timerManager.toggleAppBlock(app, val);
                                        setState(() {
                                          if (val) {
                                            _expandedPackage = pkg; // Expand details immediately upon enabling
                                          } else {
                                            if (_expandedPackage == pkg) {
                                              _expandedPackage = null;
                                            }
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  
                                  // Expandable Details (Sliders to configure time limits)
                                  if (isLimited && isExpanded && appLimit != null)
                                    Container(
                                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: AppColors.borderDark, width: 1),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 12),
                                          
                                          // Limit Slider
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Usage Limit:', style: AppStyles.body.copyWith(fontWeight: FontWeight.bold)),
                                              Text('${appLimit.limitMinutes} minutes', style: AppStyles.subheading.copyWith(color: AppColors.accentCyan)),
                                            ],
                                          ),
                                          Slider(
                                            value: appLimit.limitMinutes.toDouble(),
                                            min: 1,
                                            max: 120,
                                            divisions: 119,
                                            activeColor: AppColors.accentCyan,
                                            inactiveColor: AppColors.borderDark,
                                            onChanged: (val) {
                                              timerManager.updateAppLimit(pkg, val.toInt(), appLimit.cooldownMinutes);
                                            },
                                          ),
                                          
                                          const SizedBox(height: 12),
                                          
                                          // Cooldown Slider
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Reset Cooldown:', style: AppStyles.body.copyWith(fontWeight: FontWeight.bold)),
                                              Text(
                                                appLimit.cooldownMinutes >= 60
                                                    ? '${(appLimit.cooldownMinutes / 60).toStringAsFixed(1)} hours'
                                                    : '${appLimit.cooldownMinutes} mins',
                                                style: AppStyles.subheading.copyWith(color: AppColors.accentMagenta),
                                              ),
                                            ],
                                          ),
                                          Slider(
                                            value: appLimit.cooldownMinutes.toDouble(),
                                            min: 5,
                                            max: 360, // up to 6 hours
                                            divisions: 71,
                                            activeColor: AppColors.accentMagenta,
                                            inactiveColor: AppColors.borderDark,
                                            onChanged: (val) {
                                              timerManager.updateAppLimit(pkg, appLimit.limitMinutes, val.toInt());
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
