import 'package:material_ui/material_ui.dart';

import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../shared/permission_list.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Permissions')),
    body: const PageBody(
      children: [
        SizedBox(height: Space.md),
        PermissionList(),
      ],
    ),
  );
}
