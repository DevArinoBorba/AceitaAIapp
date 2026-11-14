import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Navegação principal com ícone e nome sempre visíveis.
class AppDock extends StatelessWidget {
  const AppDock({super.key, this.selected = '/'});
  final String? selected;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          height: 76,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.panel,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            _item(context, 'Início', '/', Icons.home_outlined),
            _item(context, 'Meu custo', '/custo', Icons.toll_outlined),
            _item(context, 'Metas', '/metas', Icons.bar_chart_outlined),
            _item(context, 'Histórico', '/historico', Icons.history_rounded),
          ]),
        ),
      );

  Widget _item(
      BuildContext context, String label, String route, IconData icon) {
    final active = selected == route;
    return Expanded(
        child: Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        selected: active,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF373739), Color(0xFF171719)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(25),
            ),
            child: InkWell(
              onTap: () {
                if (!active) context.go(route);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          size: 26,
                          color: active ? AppColors.text : AppColors.muted),
                      const SizedBox(height: 4),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? AppColors.text
                                      : AppColors.muted))),
                    ]),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
