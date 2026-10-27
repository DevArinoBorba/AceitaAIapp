import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';

class _Plan {
  const _Plan({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.note,
    this.badge,
  });

  final String id;
  final String title;
  final String price;
  final String period;
  final String note;
  final String? badge;
}

const _plans = <_Plan>[
  _Plan(
    id: 'mensal',
    title: 'Mensal',
    price: 'R\$ 12,90',
    period: '/mês',
    note: 'Cancele quando quiser',
  ),
  _Plan(
    id: 'trimestral',
    title: 'Trimestral',
    price: 'R\$ 36,99',
    period: '/3 meses',
    note: 'R\$ 12,33 por mês',
  ),
  _Plan(
    id: 'anual',
    title: 'Anual',
    price: 'R\$ 114,99',
    period: '/ano',
    note: 'R\$ 9,58 por mês',
    badge: 'ECONOMIZE 26%',
  ),
];

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selected = 'anual';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Planos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Copiloto Turbo',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Decida em 2 segundos.\nGanhe por hora, não por sorte.',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '7 dias grátis, sem cartão. Depois é só continuar se valer a pena.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'O que vem no Turbo'),
          const _Benefit(text: 'Veredito na hora para cada oferta'),
          const _Benefit(text: 'Simulador de ganhos com o seu histórico'),
          const _Benefit(text: 'Card flutuante personalizável e voz'),
          const _Benefit(text: 'Leitura automática dos apps de corrida'),
          const _Benefit(text: 'Câmera secreta e radar'),
          const SectionHeader(title: 'Escolha o plano'),
          ..._plans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanCard(
                plan: plan,
                selected: _selected == plan.id,
                onTap: () => setState(() => _selected = plan.id),
              ),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Começar 7 dias grátis',
            icon: Icons.bolt_rounded,
            onPressed: () => _notifyCheckout(context),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _notifyCheckout(context),
              child: const Text('Restaurar compra'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cobrança pelo Google Play. O trial é controlado pelo servidor '
            '(uma vez por conta) e o acesso é revalidado a cada abertura.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  void _notifyCheckout(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Checkout ainda não conectado (fase 6: RevenueCat + trial no backend).',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      borderColor: selected ? AppColors.primary : AppColors.border,
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 1.6,
              ),
            ),
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: AppColors.primaryInk,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      plan.title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (plan.badge != null) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          plan.badge!,
                          style: const TextStyle(
                            color: AppColors.primaryInk,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  plan.note,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                plan.price,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                plan.period,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.good.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 12,
              color: AppColors.good,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
