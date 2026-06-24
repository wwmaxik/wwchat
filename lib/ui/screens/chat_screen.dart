import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/ble_mesh_service.dart';

import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../services/connectivity_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.contact});

  final Contact contact;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().setActiveContact(widget.contact.id);
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().setActiveContact(null);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final connectivity = context.read<ConnectivityService>();

    final source = connectivity.isInternetAvailable
        ? MessageSource.internet
        : MessageSource.ble;

    await chatProvider.addMessage(
      text: text,
      recipientId: widget.contact.id,
      isMe: true,
      source: source,
    );

    _controller.clear();
  }

  void _showNodesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final bleService = context.watch<ConnectivityService>().bleMeshService;
        return ListenableBuilder(
          listenable: bleService,
          builder: (context, child) {
            final devices = bleService.discoveredDevices;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby mesh nodes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Scanning for nodes...')),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          String stateText;
                          Color stateColor;

                          if (device.state ==
                              BleMeshConnectionState.connected) {
                            stateText = 'Connected';
                            stateColor = Colors.green;
                          } else if (device.state ==
                              BleMeshConnectionState.connecting) {
                            stateText = 'Connecting...';
                            stateColor = Colors.orange;
                          } else {
                            stateText = 'Not connected';
                            stateColor = Colors.grey;
                          }

                          return ListTile(
                            leading: const Icon(Icons.settings_bluetooth),
                            title: Text(device.deviceName),
                            subtitle: Text(device.deviceId),
                            trailing: Text(
                              stateText,
                              style: TextStyle(
                                color: stateColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.getMessagesWith(widget.contact.id);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contact.name),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: connectivity.isInternetAvailable
                        ? Colors.green
                        : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  connectivity.isInternetAvailable
                      ? 'Online sync'
                      : 'Mesh mode',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!connectivity.isInternetAvailable)
            IconButton(
              icon: const Icon(Icons.bluetooth_searching),
              onPressed: () => _showNodesSheet(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return MessageBubble(message: message);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: connectivity.isInternetAvailable
                          ? 'Type a message...'
                          : 'Send through nearby mesh...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      filled: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = message.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isMe
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft:
                !isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isMe
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  message.source == MessageSource.internet
                      ? Icons.public
                      : Icons.bluetooth,
                  size: 12,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
