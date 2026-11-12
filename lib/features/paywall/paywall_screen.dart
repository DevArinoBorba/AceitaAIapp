import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Planos'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: const <Widget>[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.workspace_premium_rounded, color: AppColors.primary),
                SizedBox(height: 12),
                Text(
                  'Aceita AI Turbo',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Assinaturas indisponíveis nesta versão.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Não há compra nem período de teste para ativar.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
          SectionHeader(title: 'Recursos do app'),
          ListTile(
            leading: Icon(Icons.check_rounded, color: AppColors.good),
            title: Text('Avaliação de ofertas com suas metas'),
          ),
          ListTile(
            leading: Icon(Icons.check_rounded, color: AppColors.good),
            title: Text('Histórico de ofertas'),
          ),
          ListTile(
            leading: Icon(Icons.check_rounded, color: AppColors.good),
            title: Text('Card flutuante personalizável'),
          ),
          SizedBox(height: 20),
          Text(
            'A contratação do Turbo está em preparação. '
            'Preços e condições serão informados quando a assinatura estiver disponível.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
