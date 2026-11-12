import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_dock.dart';
import '../../core/widgets/ui_kit.dart';
import 'offer_form_sheet.dart';

/// Destino do rodapé quando ainda não há uma oferta para avaliar.
class EvaluateScreen extends ConsumerStatefulWidget {
  const EvaluateScreen({super.key});
  @override
  ConsumerState<EvaluateScreen> createState() => _EvaluateScreenState();
}

class _EvaluateScreenState extends ConsumerState<EvaluateScreen> {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _evaluate();
    });
  }

  Future<void> _evaluate() async {
    if (_opening) return;
    _opening = true;
    final verdict = await showOfferFormSheet(context, ref);
    _opening = false;
    if (!mounted || verdict == null) return;
    context.go('/avaliar', extra: verdict);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Avaliar oferta')),
        bottomNavigationBar: const AppDock(selected: '/avaliar'),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SurfaceCard(
                child: Text(
                    'Informe valor, distância e tempo da oferta para comparar com as suas metas.')),
            const SizedBox(height: 16),
            PrimaryButton(
                label: 'Preencher oferta',
                icon: Icons.bolt_outlined,
                onPressed: _evaluate),
          ]),
        ),
      );
}
