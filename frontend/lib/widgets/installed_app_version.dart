import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';

/// Reports the installed artifact, not a manually maintained release string.
class InstalledAppVersion extends StatefulWidget {
  const InstalledAppVersion({super.key});

  @override
  State<InstalledAppVersion> createState() => _InstalledAppVersionState();
}

class _InstalledAppVersionState extends State<InstalledAppVersion> {
  final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _info,
    builder:
        (context, snapshot) => Text(
          snapshot.hasData
              ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber} (Meal Planner)'
              : 'Meal Planner Polska',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
  );
}
