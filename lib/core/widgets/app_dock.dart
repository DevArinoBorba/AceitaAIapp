import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Atalhos de trabalho. Rótulos acessíveis ficam no tooltip, sem ocupar a tela.
class AppDock extends StatelessWidget {
  const AppDock({super.key, this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
        height: 60,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.panel,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            _item(context, 'Metas', '/metas', Icons.track_changes_outlined),
            _item(context, 'Meu custo', '/custo', Icons.toll_outlined),
            _item(context, 'Histórico', '/historico', Icons.history_rounded),
          ]),
        ),
      );

  Widget _item(
      BuildContext context, String label, String route, IconData icon) {
    final active = selected == route;
    return Expanded(
        child: Center(
            child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: active ? AppColors.chrome : null,
        borderRadius: BorderRadius.circular(24),
      ),
      child: IconButton(
        tooltip: label,
        icon: Icon(icon, size: 25),
        color: active ? AppColors.primaryInk : AppColors.primary,
        onPressed: active ? null : () => context.push(route),
        disabledColor: AppColors.primaryInk,
      ),
    )));
  }
}
