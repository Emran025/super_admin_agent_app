import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/auth_2fa/value_objects/agent_decision.dart';
import '../cubit/auth_challenge_cubit.dart';
import '../cubit/auth_challenge_state.dart';

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
    return PopScope(
      canPop: false,
      child: BlocConsumer<AuthChallengeCubit, AuthChallengeState>(
        listener: (context, state) {
          if (state is AuthChallengeSubmitted) {
            Navigator.of(context).pop();
          } else if (state is AuthChallengeError) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Authentication Request'),
              automaticallyImplyLeading: false,
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AuthChallengeState state) {
    if (state is AuthChallengeFetching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is AuthChallengeSubmitting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Submitting your decision...'),
          ],
        ),
      );
    }

    if (state is AuthChallengeReady) {
      final challenge = state.challenge;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.contextLabel,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _infoRow('Challenge ID', challenge.challengeId),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Expires',
                      challenge.expiresAt.toLocal().toString(),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context
                        .read<AuthChallengeCubit>()
                        .submitDecision(AgentDecision.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('REJECT'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context
                        .read<AuthChallengeCubit>()
                        .submitDecision(AgentDecision.approve),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('APPROVE'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return const Center(child: Text('Loading challenge...'));
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
