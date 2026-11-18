import 'package:flutter/material.dart';
import 'language.dart';

/// Displays the author's original code without recoloring it in dark mode.
Future<void> showAuthorSupport(BuildContext context) => showDialog<void>(
  context: context,
  builder:
      (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, '赞赏作者'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, '关闭'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tr(context, '感谢你支持 Poise 的持续开发。')),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/support/author.png',
                    fit: BoxFit.contain,
                    semanticLabel: tr(context, 'Finn Wang 的微信赞赏码'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr(context, '可截图后在微信扫一扫中从相册识别。赞赏完全自愿，不影响任何功能。'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
);
