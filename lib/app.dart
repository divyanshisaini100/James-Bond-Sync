import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'models/clipboard_item.dart';
import 'models/paired_device.dart';
import 'models/pair_request.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _appState.initialize().then((_) => _appState.start());
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      appState: _appState,
      child: MaterialApp(
        title: 'Universal Clipboard Sync',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState appState, required Widget child})
      : super(notifier: appState, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final devices = state.pairingManager.devices;
    final history = state.historyStore.items;
    final pending = state.pendingPairRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal Clipboard Sync'),
        actions: [
          Row(
            children: [
              const Text('Sync'),
              Switch(
                value: state.isSyncEnabled,
                onChanged: state.toggleSync,
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_history') {
                state.clearHistory();
              } else if (value == 'reset_storage') {
                _confirmReset(context, state);
              } else if (value == 'background_on') {
                state.toggleBackgroundSync(true);
              } else if (value == 'background_off') {
                state.toggleBackgroundSync(false);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear_history',
                child: Text('Clear history'),
              ),
              PopupMenuItem(
                value: 'reset_storage',
                child: Text('Forget devices & reset'),
              ),
              PopupMenuItem(
                value: 'background_on',
                child: Text('Enable background sync'),
              ),
              PopupMenuItem(
                value: 'background_off',
                child: Text('Disable background sync'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(
            title: 'Paired Devices',
            trailing: TextButton(
              onPressed: () => _showPairDialog(context),
              child: const Text('Add'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickAndSendFile(context, state, isImage: true),
                icon: const Icon(Icons.image),
                label: const Text('Send Image'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickAndSendFile(context, state, isImage: false),
                icon: const Icon(Icons.attach_file),
                label: const Text('Send File'),
              ),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _SectionTitle(title: 'Pair Requests'),
            ...pending.map((request) => _PairRequestTile(
                  deviceName: request.deviceName,
                  deviceId: request.deviceId,
                  onApprove: () => _approvePair(context, state, request),
                  onReject: () => state.rejectPairRequest(request.deviceId),
                )),
            const SizedBox(height: 16),
          ],
          if (devices.isEmpty)
            const Text('No devices paired yet.')
          else
            ...devices.map((d) => _DeviceTile(
                  device: d,
                  onRemove: () => state.removePairedDevice(d.id),
                )),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Clipboard History'),
          if (history.isEmpty)
            const Text('No clipboard items yet.')
          else
            ...history.map((item) => _HistoryTile(item: item)),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Storage'),
          content: const Text(
              'This clears history, paired devices, and pending queues. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      state.clearAllStorage();
    }
  }

  Future<void> _showPairDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    final state = AppScope.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pair Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Device name'),
              ),
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Device ID'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Pair'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final name = nameController.text.trim();
      final id = idController.text.trim();
      if (name.isEmpty || id.isEmpty) {
        return;
      }
      final code = await state.addPairedDevice(id, name);
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Pairing Code'),
            content: SelectableText(
              'Share this 6-digit code with the other device to approve pairing:\n\n$code',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _pickAndSendFile(
    BuildContext context,
    AppState state, {
    required bool isImage,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: isImage ? FileType.image : FileType.any,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    final ok = state.sendBinaryItem(
      bytes: bytes,
      dataType: isImage ? 'image' : 'file',
      fileName: file.name,
      mimeType: isImage ? _mimeFromExtension(file.extension) : null,
    );
    if (!ok && context.mounted) {
      final limitMb = (state.maxBinaryBytes / (1024 * 1024)).toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File too large. Max $limitMb MB.')),
      );
    }
  }

  Future<void> _approvePair(BuildContext context, AppState state, PairRequest request) async {
    final controller = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Pairing Code'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '6-digit code'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (approved != true) {
      return;
    }
    final ok = await state.approvePairRequest(request, controller.text.trim());
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pairing code does not match.')),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onRemove});

  final PairedDevice device;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(device.name),
      subtitle: Text(device.id),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(device.isOnline ? Icons.circle : Icons.circle_outlined,
              color: device.isOnline ? Colors.green : Colors.grey, size: 12),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final ClipboardItem item;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (item.dataType == 'image' && item.payloadBase64 != null) {
      final bytes = base64Decode(item.payloadBase64!);
      return Card(
        child: ListTile(
          leading: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
          title: Text(item.fileName ?? 'Image'),
          subtitle: Text('${_formatBytes(item.sizeBytes ?? bytes.length)} • ${item.deviceId}'),
        ),
      );
    }
    if (item.dataType == 'file' && item.payloadBase64 != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.insert_drive_file),
          title: Text(item.fileName ?? 'File'),
          subtitle: Text('${_formatBytes(item.sizeBytes ?? 0)} • ${item.deviceId}'),
        ),
      );
    }
    final preview = item.text.length > 64 ? '${item.text.substring(0, 64)}...' : item.text;

    return Card(
      child: ListTile(
        title: Text(preview),
        subtitle: Text('From ${item.deviceId}'),
        onTap: () => state.clipboardService.setClipboardText(item.text, suppressNextRead: true),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String? _mimeFromExtension(String? extension) {
  final ext = extension?.toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'tif':
    case 'tiff':
      return 'image/tiff';
    default:
      return null;
  }
}

class _PairRequestTile extends StatelessWidget {
  const _PairRequestTile({
    required this.deviceName,
    required this.deviceId,
    required this.onApprove,
    required this.onReject,
  });

  final String deviceName;
  final String deviceId;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(deviceName),
        subtitle: Text(deviceId),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onApprove,
              icon: const Icon(Icons.check),
            ),
            IconButton(
              onPressed: onReject,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
