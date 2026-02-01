import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import '../../domain/guide_data.dart';

class GuideModuleContent extends StatelessWidget {
  final GuideModule module;

  const GuideModuleContent({
    super.key,
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          module.description,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.zestyLime,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ...module.steps.map((step) => _buildStepCard(context, step)),
      ],
    );
  }

  Widget _buildStepCard(BuildContext context, GuideStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        blur: 15,
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.zestyLime.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                step.icon,
                color: AppColors.zestyLime,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.electricWhite,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.electricWhite.withOpacity(0.8),
                        ),
                  ),
                  if (step.tip != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      step.tip!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.zestyLime,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
