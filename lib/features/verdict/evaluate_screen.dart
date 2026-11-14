import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dock.dart';
import '../../core/widgets/ui_kit.dart';
import 'offer_form_sheet.dart';

/// Tela principal da aba "Avaliar" no rodapé: exibe o formulário diretamente na
/// página, sem abrir popup sobreposto nem cortar botões no tablet.
class EvaluateScreen extends ConsumerWidget {
  const EvaluateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Avaliar oferta',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: const AppDock(selected: '/avaliar'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: OfferFormView(
                showHandle: false,
                showTitle: true,
                padding: EdgeInsets.zero,
                onSubmitted: (verdict) =>
                    context.push('/avaliar', extra: verdict),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
