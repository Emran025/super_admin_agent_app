import 'package:flutter/material.dart';

import '../../shared/theme/radius_tokens.dart';
import '../../shared/theme/spacing_tokens.dart';

class MessageComposerBar extends StatefulWidget {
  const MessageComposerBar({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.isSending = false,
  });

  final ValueChanged<String> onSend;
  final bool enabled;
  final bool isSending;

  @override
  State<MessageComposerBar> createState() => _MessageComposerBarState();
}

class _MessageComposerBarState extends State<MessageComposerBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled || widget.isSending) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.md,
          SpacingTokens.xs,
          SpacingTokens.md,
          SpacingTokens.sm,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: widget.enabled ? () {} : null,
              icon: Icon(Icons.add_circle_outline, color: cs.primary),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled && !widget.isSending,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'رسالة نصية',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RadiusTokens.pill),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: widget.enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.enabled && !widget.isSending ? _submit : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: widget.isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Icon(Icons.send, color: cs.onPrimary, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
