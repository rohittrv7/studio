import 'package:flutter/material.dart';

import '../../domain/entities/folder.dart';

/// A list tile representing a single [Folder].
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
  });

  final Folder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B86D);
    final hasChildren = folder.children.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF282828)),
        ),
        child: Row(
          children: [
            // Folder icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    folder.name,
                    style: const TextStyle(
                      color: Color(0xFFF2F2F2),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasChildren) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${folder.children.length} sub-folder${folder.children.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Media count badge
            if (folder.mediaCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF303030)),
                ),
                child: Text(
                  '${folder.mediaCount}',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF444444),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
