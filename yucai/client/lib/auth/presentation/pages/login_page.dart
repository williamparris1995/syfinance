import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// Single-button OIDC login. Lists providers advertised by the server
/// (currently just Google) via the auth repository; tapping a button
/// dispatches [OIDCLoginRequested], which drives the loopback PKCE flow
/// (see `OIDCAuthenticator` + `OidcLoginUseCase`).
///
/// On error the bloc emits [AuthError], surfaced here as a SnackBar.
/// On success the router redirect (listening to the bloc stream) sends
/// the user to `/home`.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '御财',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '登录以继续',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: context.yucai.muted),
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final loading = state is AuthLoading;
                      return FilledButton.icon(
                        onPressed: loading
                            ? null
                            : () => context
                                .read<AuthBloc>()
                                .add(const OIDCLoginRequested('google')),
                        icon: state is AuthLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.logIn),
                        label: const Text('使用 Google 登录'),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Offline-first (R6 FR-3): the app is usable without an
                  // account; skipping lands in guest mode on the home shell.
                  TextButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(SkipLoginRequested());
                      context.go('/home');
                    },
                    child: const Text('先不登录，离线使用'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
