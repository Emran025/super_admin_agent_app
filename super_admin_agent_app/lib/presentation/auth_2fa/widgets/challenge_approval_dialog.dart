import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/auth_2fa/value_objects/agent_decision.dart';
import '../cubit/auth_challenge_cubit.dart';
import '../cubit/auth_challenge_state.dart';

import 'package:super_admin_agent/presentation/shared/theme/spacing_tokens.dart';
import 'package:super_admin_agent/presentation/shared/widgets/custom_button.dart';
import 'package:super_admin_agent/presentation/shared/widgets/custom_card.dart';

/// Full-screen dialog for the owner to approve or reject an auth challenge.
///
/// Constitutional constraints enforced structurally:
/// - [PopScope(canPop: false)] — no back-button dismissal (owner must decide)
/// - No auto-dismiss, no countdown timer visible in the UI
/// - No business logic — only calls [AuthChallengeCubit] methods
/// - On [AuthChallengeSubmitted]: pops the dialog
/// - On [AuthChallengeError]: pops the dialog, shows a [SnackBar]
class ChallengeApprovalDialog extends StatelessWidget {
  const ChallengeApprovalDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: BlocConsumer<AuthChallengeCubit, AuthChallengeState>(
        listener: (context, state) {
          if (state is AuthChallengeSubmitted) {
            Navigator.of(context).pop();
          } else if (state is AuthChallengeError) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: cs.error,
                content: Text(state.message),
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Security Authorization'),
              automaticallyImplyLeading: false,
            ),
            body: SafeArea(
              child: _buildBody(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AuthChallengeState state) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (state is AuthChallengeFetching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: SpacingTokens.lg),
            Text('Fetching challenge data...', style: tt.titleMedium),
          ],
        ),
      );
    }

    if (state is AuthChallengeSubmitting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: SpacingTokens.lg),
            Text('Submitting authorization decision...', style: tt.titleMedium),
            const SizedBox(height: SpacingTokens.xs),
            Text('Signing verification payload with ECDSA key', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (state is AuthChallengeReady) {
      final challenge = state.challenge;
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.fingerprint, size: 64, color: cs.primary),
              ),
            ),
            const SizedBox(height: SpacingTokens.xl),
            Text(
              'Authorization Request',
              style: tt.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              'An external application is requesting authorization to perform this action.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.xl),
            CustomCard(
              hasGradientBorder: true,
              padding: const EdgeInsets.all(SpacingTokens.md + 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.contextLabel,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  const Divider(),
                  const SizedBox(height: SpacingTokens.sm),
                  _infoRow(context, 'CHALLENGE ID', challenge.challengeId),
                  const SizedBox(height: SpacingTokens.md),
                  _infoRow(
                    context,
                    'EXPIRES AT',
                    challenge.expiresAt.toLocal().toString().split('.').first,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'REJECT',
                    variant: CustomButtonVariant.danger,
                    icon: Icons.close,
                    onPressed: () => context
                        .read<AuthChallengeCubit>()
                        .submitDecision(AgentDecision.reject),
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: CustomButton(
                    label: 'APPROVE',
                    variant: CustomButtonVariant.primary,
                    icon: Icons.check,
                    onPressed: () => context
                        .read<AuthChallengeCubit>()
                        .submitDecision(AgentDecision.approve),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.lg),
          ],
        ),
      );
    }

    return const Center(child: Text('Loading challenge...'));
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.8),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(color: Colors.white, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
