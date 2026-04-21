import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/article.dart';
import '../theme/app_theme.dart';
import '../utils/favicons.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final bool compact;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = textSecondaryOf(context);
    final muted = textMutedOf(context);
    final border = theme.dividerColor;
    final titleColor = theme.colorScheme.onSurface;

    final when = article.publishedAt ?? article.createdAt;
    final maxTags = compact ? 2 : 3;
    final visibleTags = article.tags.take(maxTags).toList();
    final hasSummary = !compact &&
        article.summary != null &&
        article.summary!.isNotEmpty;
    final titleMaxLines = compact ? 1 : 2;

    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: kRed),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: compact ? 10 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: faviconUrl(article.source),
                              width: 20,
                              height: 20,
                              placeholder: (context, url) => Container(
                                width: 20,
                                height: 20,
                                color: border,
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 20,
                                height: 20,
                                color: border,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              article.source.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondary,
                                fontSize: 11,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeago.format(when),
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        article.title,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (hasSummary) ...[
                        const SizedBox(height: 8),
                        Text(
                          article.summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (visibleTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          runSpacing: 4,
                          children: [
                            for (int i = 0; i < visibleTags.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Text(
                                '#${visibleTags[i]}',
                                style: const TextStyle(
                                  color: kRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
