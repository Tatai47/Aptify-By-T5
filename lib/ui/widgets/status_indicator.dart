import 'package:flutter/material.dart';

/// A polished desktop status pill indicating service/runtime health
/// (e.g. Python Installed, MySQL Localhost Connected).
class StatusIndicator extends StatelessWidget {
  final String label;
  final bool isOnline;
  final String? subtitle;
  final String? tooltip;
  final VoidCallback? onTap;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.isOnline,
    this.subtitle,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusText = isOnline ? 'Detected' : 'Not Found';

    final pill = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOnline
                ? statusColor.withAlpha(77)
                : const Color(0xFF374151),
            width: 1.2,
          ),
          boxShadow: [
            if (isOnline)
              BoxShadow(
                color: statusColor.withAlpha(25),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Indicator Dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withAlpha(153),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(38),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 300),
        child: pill,
      );
    }

    return pill;
  }
}
