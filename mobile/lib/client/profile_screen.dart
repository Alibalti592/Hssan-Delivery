import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/dark_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthController>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthController>().account;

    return Column(
      children: [
        const DarkHeader(title: 'Mon profil'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: fieldFill,
                        child: Text(
                          (account?.name.isNotEmpty ?? false)
                              ? account!.name[0]
                              : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: navy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        account?.name ?? '',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account?.phone ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _confirmSignOut(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: navy),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Se déconnecter',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: mutedText),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
