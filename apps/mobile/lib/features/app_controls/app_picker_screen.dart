import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/storage/app_settings.dart';

/// Android: choose which installed apps Unscroll manages.
class AppPickerScreen extends ConsumerStatefulWidget {
  const AppPickerScreen({super.key});

  @override
  ConsumerState<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<AppPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(installedAppsProvider);
    final managed = ref.watch(settingsProvider.select((s) => s.managedApps));
    final apps = (installed.value ?? const [])
        .where((a) => a.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add apps')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search apps',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: installed.isLoading
                ? const Center(child: CircularProgressIndicator())
                : apps.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: EmptyState(
                      icon: Icons.apps_outlined,
                      title: _query.isEmpty ? 'No apps found' : 'No matches',
                      message: _query.isEmpty
                          ? 'This device did not return any apps.'
                          : 'Try a different search.',
                    ),
                  )
                : ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, i) {
                      final app = apps[i];
                      return CheckboxListTile(
                        title: Text(app.label),
                        value: managed.containsKey(app.packageName),
                        onChanged: (on) =>
                            ref.read(settingsProvider.notifier).update((s) {
                              final next = {...s.managedApps};
                              if (on == true) {
                                next[app.packageName] = ManagedApp(app.label);
                              } else {
                                next.remove(app.packageName);
                              }
                              return s.copyWith(managedApps: next);
                            }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
