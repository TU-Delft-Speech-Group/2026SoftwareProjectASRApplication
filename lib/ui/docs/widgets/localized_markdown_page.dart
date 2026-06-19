import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import '../../core/widgets/fixed_width_container.dart';

const String _markdownAssetDirectory = 'assets/markdown/docs';
const String _fallbackLanguageCode = 'en';

class LocalizedMarkdownDocument {
  const LocalizedMarkdownDocument({required this.name, required this.title});

  /// Base filename without extension.
  final String name;
  final String title;

  String assetPathFor(String languageCode) {
    return '$_markdownAssetDirectory/$name.$languageCode.md';
  }
}

class LocalizedMarkdownPage extends StatelessWidget {
  const LocalizedMarkdownPage({super.key, required this.document});

  final LocalizedMarkdownDocument document;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CustomAppBar(title: document.title),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _loadMarkdown(languageCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return FixedWidthContainer(
                children: [
                  Expanded(
                    child: _MarkdownError(
                      message: context.l10n.errors_markdownRender,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 0, 22, 22),
                    child: AppBackButton(),
                  ),
                ],
              );
            }

            return FixedWidthContainer(
              maxWidth: 1080,
              children: [
                Expanded(
                  child: Markdown(
                    data: snapshot.data ?? '',
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    styleSheet: _styleSheet(context),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: AppBackButton(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<String> _loadMarkdown(String languageCode) async {
    final localizedPath = document.assetPathFor(languageCode);
    try {
      return await rootBundle.loadString(localizedPath);
    } on FlutterError {
      if (languageCode == _fallbackLanguageCode) rethrow;
      return rootBundle.loadString(
        document.assetPathFor(_fallbackLanguageCode),
      );
    }
  }

  MarkdownStyleSheet _styleSheet(BuildContext context) {
    final bodyStyle = TextStyle(
      color: context.colors.foreground,
      fontFamily: context.fontFamily.body,
      fontSize: context.fontSize.body,
      height: 1.45,
    );

    return MarkdownStyleSheet(
      h1: bodyStyle.copyWith(
        fontFamily: context.fontFamily.heading,
        fontSize: context.fontSize.heading,
        fontWeight: FontWeight.w700,
      ),
      h2: bodyStyle.copyWith(
        fontFamily: context.fontFamily.subheading,
        fontSize: context.fontSize.subheading,
        fontWeight: FontWeight.w700,
      ),
      h3: bodyStyle.copyWith(
        fontFamily: context.fontFamily.subsubheading,
        fontSize: context.fontSize.subsubheading,
        fontWeight: FontWeight.w700,
      ),
      p: bodyStyle,
      listBullet: bodyStyle,
      blockquote: bodyStyle,
      a: bodyStyle.copyWith(
        color: context.colors.darkBlue,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

class _MarkdownError extends StatelessWidget {
  const _MarkdownError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.foreground,
            fontFamily: context.fontFamily.body,
            fontSize: context.fontSize.body,
          ),
        ),
      ),
    );
  }
}
