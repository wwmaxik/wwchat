import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final connectivity = context.watch<ConnectivityService>();
    final authService = context.watch<AuthService>();
    final theme = Theme.of(context);

    final userName = authService.currentUser?.displayName ??
        authService.currentUser?.email?.split('@').first ??
        'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('wwchat'),
        actions: [
          Switch(
            value: connectivity.isInternetAvailable,
            onChanged: (val) =>
                connectivity.toggleInternet(val, deviceName: userName),
            thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
              if (states.contains(WidgetState.selected)) {
                return const Icon(Icons.public);
              }
              return const Icon(Icons.bluetooth);
            }),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => authService.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: chatProvider.contacts.isEmpty
          ? Center(
              child: Text(
                authService.isAvailable
                    ? 'No contacts yet'
                    : 'Configure Firebase to load contacts',
                style: theme.textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              itemCount: chatProvider.contacts.length,
              itemBuilder: (context, index) {
                final contact = chatProvider.contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(contact.name.characters.first.toUpperCase()),
                  ),
                  title: Text(contact.name),
                  subtitle:
                      Text('Mesh ID: ${contact.meshAddress ?? 'Unavailable'}'),
                  trailing: Icon(
                    connectivity.isInternetAvailable
                        ? Icons.public
                        : Icons.bluetooth,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(contact: contact),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
