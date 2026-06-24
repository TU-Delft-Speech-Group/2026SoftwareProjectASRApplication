import 'package:asr_application/ui/docs/widgets/licenses_button.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import '../../core/widgets/app_navigation_button.dart';
import '../../core/widgets/fixed_width_container.dart';
import 'localized_markdown_page.dart';

class DocsOverviewPage extends StatelessWidget {
  const DocsOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CustomAppBar(title: context.l10n.docs__title),
      body: FixedWidthContainer(
        children: [
          Expanded(
            child: Column(
              spacing: 12,
              children: [
                AppNavigationButton(
                  label: context.l10n.docs__addingModelsTitle,
                  builder: (_) => LocalizedMarkdownPage(
                    document: LocalizedMarkdownDocument(
                      name: 'adding_models',
                      title: context.l10n.docs__addingModelsTitle,
                    ),
                  ),
                  icon: Icons.add_circle_outline,
                ),

                AppNavigationButton(
                  label: context.l10n.docs__aboutTitle,
                  builder: (_) => LocalizedMarkdownPage(
                    document: LocalizedMarkdownDocument(
                      name: 'about',
                      title: context.l10n.docs__aboutTitle,
                    ),
                  ),
                  icon: Icons.info_outline,
                ),

                AppNavigationButton(
                  label: context.l10n.docs__disclaimerTitle,
                  builder: (_) => LocalizedMarkdownPage(
                    document: LocalizedMarkdownDocument(
                      name: 'disclaimer',
                      title: context.l10n.docs__disclaimerTitle,
                    ),
                  ),
                  icon: Icons.gavel_outlined,
                ),
                LicensesButton(),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: AppBackButton(),
          ),
        ],
      ),
    );
  }
}
