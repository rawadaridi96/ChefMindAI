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
  late List<GuideModule> _modules;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get modules to determine length.
    // Note: Re-initializing controller on every dependency change might be overkill
    // but ensures language changes don't break if length varies (unlikely here).
    _modules = GuideData.getModules(context);
    _tabController = TabController(length: _modules.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Refresh modules in build to get latest localized strings
    _modules = GuideData.getModules(context);

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
          tabs: _modules.map((m) => Tab(text: m.title)).toList(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(),
        child: TabBarView(
          controller: _tabController,
          children: _modules
              .map(
                (module) => GuideModuleContent(
                  module: module,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
