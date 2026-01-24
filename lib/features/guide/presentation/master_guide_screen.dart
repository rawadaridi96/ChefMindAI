import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../domain/guide_data.dart';
import 'widgets/guide_module_content.dart';

class MasterGuideScreen extends StatefulWidget {
  const MasterGuideScreen({super.key});

  @override
  State<MasterGuideScreen> createState() => _MasterGuideScreenState();
}

class _MasterGuideScreenState extends State<MasterGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    if (_tabController.index < 3) {
      _tabController.animateTo(_tabController.index + 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modules = GuideData.getModules(context);

    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.guideTitle,
          style: const TextStyle(
              color: AppColors.electricWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.electricWhite),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.zestyLime,
          labelColor: AppColors.zestyLime,
          unselectedLabelColor: AppColors.electricWhite.withOpacity(0.5),
          isScrollable: true,
          tabs: [
            Tab(text: l10n.guideQuickStart),
            Tab(text: l10n.guideVault),
            Tab(text: l10n.guidePantryCart),
            Tab(text: l10n.guideFamilySync),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(),
        child: TabBarView(
          controller: _tabController,
          children: [
            GuideModuleContent(
              module: modules[0],
              onDismiss: _handleDismiss,
            ),
            GuideModuleContent(
              module: modules[1],
              onDismiss: _handleDismiss,
            ),
            GuideModuleContent(
              module: modules[2],
              onDismiss: _handleDismiss,
            ),
            GuideModuleContent(
              module: modules[3],
              onDismiss: _handleDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
