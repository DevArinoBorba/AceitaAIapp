import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: locked ? AppColors.muted : AppColors.primary,
              ),
              const Spacer(),
              if (locked)
                const Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: AppColors.muted,
                ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
