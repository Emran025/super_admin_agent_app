import 'package:flutter/material.dart';

import '../theme/radius_tokens.dart';
import '../theme/spacing_tokens.dart';

/// Prompts the user to set this app as the default SMS application.
class DefaultSmsAppBanner extends StatelessWidget {
  const DefaultSmsAppBanner({
    super.key,
    required this.onRequestDefault,
    this.isLoading = false,
  });

  final VoidCallback? onRequestDefault;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'التطبيق ليس تطبيق الرسائل الافتراضي',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'لعرض وإدارة الرسائل بعد استبدال تطبيق الرسائل النظامي، '
            'يُرجى تعيين هذا التطبيق كتطبيق الرسائل الافتراضي.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onRequestDefault,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RadiusTokens.sm),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.sms, size: 18),
              label: Text(
                isLoading ? 'جارٍ الطلب...' : 'تعيين كتطبيق افتراضي',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
