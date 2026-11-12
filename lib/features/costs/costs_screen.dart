import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/app_dock.dart';
import '../../data/cost_repository.dart';
import '../../domain/entities/cost_profile.dart';
import '../../domain/entities/goals.dart';
import '../subscription/subscription_provider.dart';

/// "Meu custo": transforma o que o motorista paga no carro em R$ por km.
///
/// O número que sai daqui substitui o padrão de R$ 0,75 que o card usa para
/// calcular lucro — é a diferença entre "achei que lucrei" e "lucrei".
class CostsScreen extends ConsumerStatefulWidget {
  const CostsScreen({super.key});

  @override
  ConsumerState<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends ConsumerState<CostsScreen> {
  Timer? _save;

  @override
  void dispose() {
    _save?.cancel();
    super.dispose();
  }

  /// Atualiza a tela na hora e grava com um respiro (o teclado dispara a cada
  /// tecla; não precisa gravar 20 vezes por segundo).
  void _apply(CostProfile next) {
    ref.read(costProfileProvider.notifier).preview(next);
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(costProfileProvider.notifier).commit();
    });
  }

  void _saveNow(CostProfile next) {
    _save?.cancel();
    ref.read(costProfileProvider.notifier).update(next);
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(subscriptionProvider).isPro;
    final profile = ref.watch(costProfileProvider);
    final active = ref.watch(hasCostProfileProvider);

    return Scaffold(
      bottomNavigationBar: const AppDock(selected: '/custo'),
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Meu custo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _confirmReset(context),
            child: const Text('Restaurar'),
          ),
        ],
      ),
      body: isPro
          ? _buildForm(context, profile, active)
          : _LockedView(
              onUnlockDev: () =>
                  ref.read(subscriptionProvider.notifier).setDevUnlock(true),
            ),
    );
  }

  Widget _buildForm(BuildContext context, CostProfile profile, bool active) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
      children: <Widget>[
        Text(
          'Quanto o seu carro custa por quilômetro rodado? Preencha uma vez — '
          'o card passa a calcular o lucro com o seu custo, não com a média '
          'do app.',
          style: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.95),
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        _ResultCard(
          profile: profile,
          reference: const Goals().costPerKm,
          active: active,
        ),
        const SectionHeader(title: 'Combustível'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FuelType.values.map((type) {
                  final selected = profile.fuelType == type;
                  return _Chip(
                    label: type.label,
                    selected: selected,
                    onTap: () => _apply(
                      profile.copyWith(
                        fuelType: type,
                        fuelPrice: type.defaultPrice,
                        fuelConsumption: type.defaultConsumption,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CostField(
                      label: 'Preço',
                      suffix: profile.fuelType.priceUnit,
                      value: profile.fuelPrice,
                      onChanged: (v) => _apply(profile.copyWith(fuelPrice: v)),
                      onCommit: (v) => _saveNow(profile.copyWith(fuelPrice: v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CostField(
                      label: 'Consumo',
                      suffix: profile.fuelType.consumptionUnit,
                      value: profile.fuelConsumption,
                      decimals: 1,
                      onChanged: (v) =>
                          _apply(profile.copyWith(fuelConsumption: v)),
                      onCommit: (v) =>
                          _saveNow(profile.copyWith(fuelConsumption: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Line(
                label: 'Combustível por km',
                value: '${brl(profile.fuelPerKm)}/km',
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Seu carro'),
        SurfaceCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Chip(
                label: 'Carro próprio',
                selected: !profile.isRented,
                onTap: () => _saveNow(
                    profile.copyWith(ownership: VehicleOwnership.owned)),
              ),
              _Chip(
                label: 'Carro alugado',
                selected: profile.isRented,
                onTap: () => _saveNow(
                    profile.copyWith(ownership: VehicleOwnership.rented)),
              ),
            ],
          ),
        ),
        if (profile.isRented)
          ..._rentalFields(profile)
        else ...<Widget>[
          const SectionHeader(title: 'Desgaste por km'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                _WearRow(
                  title: 'Óleo e filtros',
                  cost: profile.oilCost,
                  everyKm: profile.oilEveryKm,
                  perKm: profile.oilPerKm,
                  onCost: (v) => _apply(profile.copyWith(oilCost: v)),
                  onCostCommit: (v) => _saveNow(profile.copyWith(oilCost: v)),
                  onEvery: (v) => _apply(profile.copyWith(oilEveryKm: v)),
                  onEveryCommit: (v) =>
                      _saveNow(profile.copyWith(oilEveryKm: v)),
                ),
                const Divider(color: AppColors.border, height: 26),
                _WearRow(
                  title: 'Pneus (jogo)',
                  cost: profile.tiresCost,
                  everyKm: profile.tiresEveryKm,
                  perKm: profile.tiresPerKm,
                  onCost: (v) => _apply(profile.copyWith(tiresCost: v)),
                  onCostCommit: (v) => _saveNow(profile.copyWith(tiresCost: v)),
                  onEvery: (v) => _apply(profile.copyWith(tiresEveryKm: v)),
                  onEveryCommit: (v) =>
                      _saveNow(profile.copyWith(tiresEveryKm: v)),
                ),
                const Divider(color: AppColors.border, height: 26),
                _WearRow(
                  title: 'Freios',
                  cost: profile.brakesCost,
                  everyKm: profile.brakesEveryKm,
                  perKm: profile.brakesPerKm,
                  onCost: (v) => _apply(profile.copyWith(brakesCost: v)),
                  onCostCommit: (v) =>
                      _saveNow(profile.copyWith(brakesCost: v)),
                  onEvery: (v) => _apply(profile.copyWith(brakesEveryKm: v)),
                  onEveryCommit: (v) =>
                      _saveNow(profile.copyWith(brakesEveryKm: v)),
                ),
                const Divider(color: AppColors.border, height: 26),
                _WearRow(
                  title: 'Revisão geral',
                  cost: profile.serviceCost,
                  everyKm: profile.serviceEveryKm,
                  perKm: profile.servicePerKm,
                  onCost: (v) => _apply(profile.copyWith(serviceCost: v)),
                  onCostCommit: (v) =>
                      _saveNow(profile.copyWith(serviceCost: v)),
                  onEvery: (v) => _apply(profile.copyWith(serviceEveryKm: v)),
                  onEveryCommit: (v) =>
                      _saveNow(profile.copyWith(serviceEveryKm: v)),
                ),
                const Divider(color: AppColors.border, height: 26),
                _CostField(
                  label: 'Reserva p/ imprevisto',
                  suffix: 'R\$/km',
                  value: profile.reservePerKm,
                  onChanged: (v) => _apply(profile.copyWith(reservePerKm: v)),
                  onCommit: (v) => _saveNow(profile.copyWith(reservePerKm: v)),
                ),
                const SizedBox(height: 12),
                _Line(
                  label: 'Desgaste por km',
                  value: '${brl(profile.maintenancePerKm)}/km',
                  color: AppColors.average,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Depreciação do carro'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CostField(
                  label: 'Valor do carro (FIPE)',
                  suffix: 'R\$',
                  value: profile.vehicleValue,
                  onChanged: (v) => _apply(profile.copyWith(vehicleValue: v)),
                  onCommit: (v) => _saveNow(profile.copyWith(vehicleValue: v)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Idade do carro',
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ageBands.map((band) {
                    final selected = profile.vehicleAgeYears == band.years;
                    return _Chip(
                      label: band.label,
                      selected: selected,
                      onTap: () => _apply(
                        profile.copyWith(
                          vehicleAgeYears: band.years,
                          depreciationPct: band.pct,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CostField(
                        label: 'Perda por ano',
                        suffix: '%',
                        value: profile.depreciationPct,
                        decimals: 1,
                        onChanged: (v) =>
                            _apply(profile.copyWith(depreciationPct: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(depreciationPct: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ReadOnly(
                        label: 'Por mês',
                        value: brl(profile.depreciationMonthly),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Memory(
                  '${brlCompact(profile.vehicleValue)} × '
                  '${decimal(profile.depreciationPct, 1)}% = '
                  '${brlCompact(profile.vehicleValue * profile.depreciationPct / 100)}/ano'
                  ' ÷ ${brlCompact(profile.kmPerYear)} km/ano',
                ),
                const SizedBox(height: 8),
                _Line(
                  label: 'Depreciação por km',
                  value: '${brl(profile.depreciationPerKm)}/km',
                  color: AppColors.good,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Custos fixos (por mês)'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                _CostField(
                  label: 'Parcela do carro',
                  suffix: 'R\$',
                  value: profile.installment,
                  onChanged: (v) => _apply(profile.copyWith(installment: v)),
                  onCommit: (v) => _saveNow(profile.copyWith(installment: v)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CostField(
                        label: 'Seguro (por ano)',
                        suffix: 'R\$',
                        value: profile.insuranceYearly,
                        onChanged: (v) =>
                            _apply(profile.copyWith(insuranceYearly: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(insuranceYearly: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CostField(
                        label: 'IPVA + licenc. (ano)',
                        suffix: 'R\$',
                        value: profile.taxesYearly,
                        onChanged: (v) =>
                            _apply(profile.copyWith(taxesYearly: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(taxesYearly: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CostField(
                        label: 'MEI / imposto',
                        suffix: 'R\$/mês',
                        value: profile.meiMonthly,
                        onChanged: (v) =>
                            _apply(profile.copyWith(meiMonthly: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(meiMonthly: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CostField(
                        label: 'Internet / celular',
                        suffix: 'R\$/mês',
                        value: profile.internetMonthly,
                        onChanged: (v) =>
                            _apply(profile.copyWith(internetMonthly: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(internetMonthly: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CostField(
                        label: 'Lavagem',
                        suffix: 'R\$/mês',
                        value: profile.washMonthly,
                        onChanged: (v) =>
                            _apply(profile.copyWith(washMonthly: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(washMonthly: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CostField(
                        label: 'Outros',
                        suffix: 'R\$/mês',
                        value: profile.otherMonthly,
                        onChanged: (v) =>
                            _apply(profile.copyWith(otherMonthly: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(otherMonthly: v)),
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.border, height: 26),
                _CostField(
                  label: 'Alimentação (por dia)',
                  suffix: 'R\$/dia',
                  value: profile.foodPerDay,
                  onChanged: (v) => _apply(profile.copyWith(foodPerDay: v)),
                  onCommit: (v) => _saveNow(profile.copyWith(foodPerDay: v)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deixe 0 se você leva de casa. Média na rua: R\$ 25/dia.',
                  style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.8),
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                _Line(
                  label: 'Alimentação no mês',
                  value: brl(profile.foodMonthly),
                  color: AppColors.muted,
                  small: true,
                ),
                const SizedBox(height: 12),
                _Line(
                  label: 'Total por mês',
                  value: brl(profile.monthlyTotal),
                  color: AppColors.text,
                ),
                const SizedBox(height: 4),
                _Line(
                  label: 'Contas do carro por km',
                  value: '${brl(profile.fixedPerKm)}/km',
                  color: AppColors.muted,
                  small: true,
                ),
                if (profile.foodPerKm > 0) ...<Widget>[
                  const SizedBox(height: 4),
                  _Line(
                    label: 'Alimentação por km',
                    value: '${brl(profile.foodPerKm)}/km',
                    color: AppColors.muted,
                    small: true,
                  ),
                ],
              ],
            ),
          ),
          const SectionHeader(title: 'Sua operação'),
          SurfaceCard(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CostField(
                        label: 'Km por dia',
                        suffix: 'km',
                        value: profile.kmPerDay,
                        decimals: 0,
                        onChanged: (v) => _apply(profile.copyWith(kmPerDay: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(kmPerDay: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CostField(
                        label: 'Dias por mês',
                        suffix: 'dias',
                        value: profile.daysPerMonth.toDouble(),
                        decimals: 0,
                        onChanged: (v) =>
                            _apply(profile.copyWith(daysPerMonth: v.round())),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(daysPerMonth: v.round())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CostField(
                        label: 'Horas por dia',
                        suffix: 'h',
                        value: profile.hoursPerDay,
                        decimals: 0,
                        onChanged: (v) =>
                            _apply(profile.copyWith(hoursPerDay: v)),
                        onCommit: (v) =>
                            _saveNow(profile.copyWith(hoursPerDay: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Line(
                  label: 'Km por mês',
                  value: kmLabel(profile.kmPerMonth),
                  color: AppColors.text,
                ),
                const SizedBox(height: 4),
                _Line(
                  label: 'Km por ano',
                  value: kmLabel(profile.kmPerYear),
                  color: AppColors.muted,
                  small: true,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          profile.isRented
              ? 'Estimativa usando toda a franquia semanal: combustível + '
                  '(aluguel + alimentação + lavagem + outros) ÷ km da franquia. '
                  'Se rodar menos, o custo por km será maior. Não inclui km excedente.'
              : 'A conta é a mesma das calculadoras do setor: combustível + desgaste '
                  '+ depreciação + contas do mês ÷ km + alimentação. Rodar mais barato '
                  'não é rodar mais: é saber quanto sobra.',
          style: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.85),
            fontSize: 11.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  List<Widget> _rentalFields(CostProfile profile) => <Widget>[
        const SectionHeader(title: 'Aluguel semanal'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CostField(
                label: 'Aluguel semanal',
                suffix: 'R\$/semana',
                value: profile.rentWeekly,
                onChanged: (v) => _apply(profile.copyWith(rentWeekly: v)),
                onCommit: (v) => _saveNow(profile.copyWith(rentWeekly: v)),
              ),
              const SizedBox(height: 12),
              _CostField(
                label: 'Franquia semanal',
                suffix: 'km/semana',
                value: profile.rentalKmWeekly,
                decimals: 0,
                onChanged: (v) => _apply(profile.copyWith(rentalKmWeekly: v)),
                onCommit: (v) => _saveNow(profile.copyWith(rentalKmWeekly: v)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Informe a franquia semanal do contrato. A estimativa considera '
                'o uso de todos esses quilômetros, com manutenção, depreciação, '
                'seguro e impostos do carro cobertos pela locadora.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Gastos extras por semana'),
        SurfaceCard(
          child: Column(
            children: <Widget>[
              _CostField(
                label: 'Alimentação',
                suffix: 'R\$/semana',
                value: profile.foodWeekly,
                onChanged: (v) => _apply(profile.copyWith(foodWeekly: v)),
                onCommit: (v) => _saveNow(profile.copyWith(foodWeekly: v)),
              ),
              const SizedBox(height: 12),
              _CostField(
                label: 'Lavagem',
                suffix: 'R\$/semana',
                value: profile.washWeekly,
                onChanged: (v) => _apply(profile.copyWith(washWeekly: v)),
                onCommit: (v) => _saveNow(profile.copyWith(washWeekly: v)),
              ),
              const SizedBox(height: 12),
              _CostField(
                label: 'Outros',
                suffix: 'R\$/semana',
                value: profile.otherWeekly,
                onChanged: (v) => _apply(profile.copyWith(otherWeekly: v)),
                onCommit: (v) => _saveNow(profile.copyWith(otherWeekly: v)),
              ),
            ],
          ),
        ),
      ];
  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Restaurar valores de referência?'),
        content: const Text(
          'Volta para os valores médios do Brasil (combustível, peças e '
          'contas). Seus números atuais serão perdidos.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(costProfileProvider.notifier).reset();
  }
}

/// Faixas de idade usadas para sugerir o % de depreciação ao ano.
class _AgeBand {
  const _AgeBand(this.label, this.years, this.pct);

  final String label;
  final double years;
  final double pct;
}

const _ageBands = <_AgeBand>[
  _AgeBand('0–1 ano', 0.5, 15),
  _AgeBand('1–3 anos', 2, 10),
  _AgeBand('3–5 anos', 4, 7),
  _AgeBand('5+ anos', 7, 4),
];

/// Cartão de resultado: é o número que o card nativo passa a usar.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.profile,
    required this.reference,
    required this.active,
  });

  final CostProfile profile;

  /// O custo padrão do app, só para comparar (R$ 0,75/km).
  final double reference;

  /// O perfil já foi salvo e está valendo no card.
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (profile.isRented && !profile.isComplete) {
      return const SurfaceCard(
          child: Text(
        'Preencha o aluguel semanal, a franquia de km e o consumo de combustível '
        'para calcular e atualizar o custo no card. Enquanto isso, o card mantém '
        'o último custo válido.',
      ));
    }
    final total = profile.totalPerKm;
    final diff = total - reference;
    const fixedColor = Color(0xFF85858B);
    const foodColor = Color(0xFF55555B);

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.primary.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'SEU CUSTO REAL',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (active ? AppColors.primary : AppColors.muted)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      active
                          ? Icons.check_circle_rounded
                          : Icons.visibility_rounded,
                      size: 12,
                      color: active ? AppColors.primary : AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      active ? 'no card' : 'prévia',
                      style: TextStyle(
                        color: active ? AppColors.primary : AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    brl(total),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '/km',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            diff.abs() < 0.005
                ? 'A referência do app é ${brl(reference)}/km — igual ao seu custo.'
                : diff > 0
                    ? 'A referência do app é ${brl(reference)}/km — você estava '
                        'contando ${brl(diff)}/km de lucro que não existe.'
                    : 'A referência do app é ${brl(reference)}/km — seu custo '
                        'real é menor, então o lucro estava subestimado.',
            style: TextStyle(
              color: diff > 0.005 ? AppColors.average : AppColors.muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _CostBar(
            profile: profile,
            fixedColor: fixedColor,
            foodColor: foodColor,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              _Legend(
                color: AppColors.primary,
                label: 'Combustível ${brl(profile.fuelPerKm)}',
              ),
              if (!profile.isRented)
                _Legend(
                  color: AppColors.average,
                  label: 'Desgaste ${brl(profile.maintenancePerKm)}',
                ),
              if (!profile.isRented)
                _Legend(
                  color: AppColors.good,
                  label: 'Depreciação ${brl(profile.depreciationPerKm)}',
                ),
              _Legend(
                color: fixedColor,
                label:
                    '${profile.isRented ? 'Aluguel e extras' : 'Fixos'} ${brl(profile.fixedPerKm)}',
              ),
              if (profile.foodPerKm > 0)
                _Legend(
                  color: foodColor,
                  label: 'Alimentação ${brl(profile.foodPerKm)}',
                ),
            ],
          ),
          const Divider(color: AppColors.border, height: 26),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label:
                      profile.isRented ? 'Custo por semana' : 'Custo por hora',
                  value: brl(profile.isRented
                      ? profile.rentalWeeklyCost
                      : profile.costPerHour),
                ),
              ),
              Container(width: 1, height: 34, color: AppColors.border),
              const SizedBox(width: 14),
              Expanded(
                child: _Stat(
                  label: profile.isRented
                      ? 'Franquia semanal'
                      : 'Ponto de equilíbrio',
                  value: profile.isRented
                      ? kmLabel(profile.rentalKmWeekly)
                      : '${brl(profile.breakEvenPerDay)}/dia',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostBar extends StatelessWidget {
  const _CostBar({
    required this.profile,
    required this.fixedColor,
    required this.foodColor,
  });

  final CostProfile profile;
  final Color fixedColor;
  final Color foodColor;

  @override
  Widget build(BuildContext context) {
    final parts = <(double, Color)>[
      (profile.fuelPerKm, AppColors.primary),
      (profile.maintenancePerKm, AppColors.average),
      (profile.depreciationPerKm, AppColors.good),
      (profile.fixedPerKm, fixedColor),
      (profile.foodPerKm, foodColor),
    ].where((part) => part.$1 > 0).toList();

    if (parts.isEmpty) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Row(
        children: parts
            .map(
              (part) => Expanded(
                flex: (part.$1 * 1000).round().clamp(1, 100000),
                child: Container(height: 8, color: part.$2),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WearRow extends StatelessWidget {
  const _WearRow({
    required this.title,
    required this.cost,
    required this.everyKm,
    required this.perKm,
    required this.onCost,
    required this.onCostCommit,
    required this.onEvery,
    required this.onEveryCommit,
  });

  final String title;
  final double cost;
  final double everyKm;
  final double perKm;
  final ValueChanged<double> onCost;
  final ValueChanged<double> onCostCommit;
  final ValueChanged<double> onEvery;
  final ValueChanged<double> onEveryCommit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${brl(perKm)}/km',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _CostField(
                label: 'Custo',
                suffix: 'R\$',
                value: cost,
                onChanged: onCost,
                onCommit: onCostCommit,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CostField(
                label: 'A cada',
                suffix: 'km',
                value: everyKm,
                decimals: 0,
                onChanged: onEvery,
                onCommit: onEveryCommit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.color,
    this.small = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: small ? 11 : 12,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: small ? 11.5 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Memory extends StatelessWidget {
  const _Memory(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.muted.withValues(alpha: 0.8),
        fontSize: 10.5,
        height: 1.4,
      ),
    );
  }
}

class _ReadOnly extends StatelessWidget {
  const _ReadOnly({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: appInput(label: label),
      child: Text(
        value,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Campo numérico com vírgula decimal, formatação ao sair e gravação no blur.
class _CostField extends StatefulWidget {
  const _CostField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onCommit,
    this.suffix,
    this.decimals = 2,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onCommit;
  final String? suffix;
  final int decimals;

  @override
  State<_CostField> createState() => _CostFieldState();
}

class _CostFieldState extends State<_CostField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CostField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != oldWidget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    final parsed = _parse(_controller.text);
    _controller.text = _format(parsed);
    widget.onCommit?.call(parsed);
  }

  String _format(double value) {
    final fixed = value.toStringAsFixed(widget.decimals);
    return widget.decimals == 0 ? fixed : fixed.replaceAll('.', ',');
  }

  /// Aceita "1.500,50", "1500,50", "1500.50" e "0,05".
  static double _parse(String text) {
    var clean = text.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (clean.contains(',')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    }
    final value = double.tryParse(clean);
    if (value == null || value.isNaN || value.isInfinite) return 0;
    return value < 0 ? 0 : value;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: appInput(label: widget.label, suffix: widget.suffix),
      onChanged: (text) => widget.onChanged(_parse(text)),
      onSubmitted: (text) {
        widget.onChanged(_parse(text));
        _focus.unfocus();
      },
      onTapOutside: (_) => _focus.unfocus(),
    );
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView({required this.onUnlockDev});

  final VoidCallback onUnlockDev;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.speed_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Meu custo é Turbo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cadastre combustível, peças, depreciação e contas fixas. O card '
              'passa a mostrar o lucro real de cada oferta — com o custo do '
              'seu carro, não com a média do app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Ver planos',
              icon: Icons.workspace_premium_rounded,
              expanded: false,
              onPressed: () => context.push('/planos'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onUnlockDev,
              child: const Text('Modo PRO (dev)'),
            ),
          ],
        ),
      ),
    );
  }
}
