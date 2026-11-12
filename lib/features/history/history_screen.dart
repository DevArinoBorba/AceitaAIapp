import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/app_dock.dart';
import '../../data/history_repository.dart';
import '../../domain/entities/verdict.dart';
import '../verdict/verdict_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _tab = 0;
  int _days = 7;
  String _filter = 'Todas';

  @override
  Widget build(BuildContext context) {
    final allVerdicts = ref.watch(historyProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _days - 1));
    final verdicts = allVerdicts
        .where((v) =>
            (_days == 0 || !v.offer.createdAt.isBefore(start)) &&
            (_filter == 'Todas' ||
                (_filter == 'Aceitas' && v.accepted == true) ||
                (_filter == 'Recusadas' && v.accepted == false) ||
                (_filter == 'Indefinidas' && v.accepted == null)))
        .toList();

    final total = verdicts.length;
    final accepted = verdicts.where((v) => v.accepted == true).toList();
    final declined = verdicts.where((v) => v.accepted == false).length;
    final profit = accepted.fold<double>(0, (sum, v) => sum + v.profit);
    final avgPerHour = total == 0
        ? 0.0
        : verdicts.fold<double>(0, (sum, v) => sum + v.valuePerHour) / total;

    return Scaffold(
      bottomNavigationBar: const AppDock(selected: '/historico'),
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Histórico e insights',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          if (total > 0)
            IconButton(
              tooltip: 'Zerar histórico',
              onPressed: () => _confirmClear(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.muted,
            ),
        ],
      ),
      body: allVerdicts.isEmpty
          ? _EmptyHistory(
              onEvaluate: () => context.go('/'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: <Widget>[
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Avaliações')),
                    ButtonSegment(value: 1, label: Text('Insights'))
                  ],
                  selected: {_tab},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _tab = value.first),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: DropdownButtonFormField<int>(
                    initialValue: _days,
                    decoration: appInput(label: 'Período'),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('Últimos 7 dias')),
                      DropdownMenuItem(
                          value: 30, child: Text('Últimos 30 dias')),
                      DropdownMenuItem(value: 0, child: Text('Todo histórico'))
                    ],
                    onChanged: (v) => setState(() => _days = v ?? 7),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: DropdownButtonFormField<String>(
                    initialValue: _filter,
                    decoration: appInput(label: 'Situação'),
                    isExpanded: true,
                    items: ['Todas', 'Aceitas', 'Recusadas', 'Indefinidas']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _filter = v ?? 'Todas'),
                  )),
                ]),
                const SizedBox(height: 18),
                SurfaceCard(
                    child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _Stat(
                        label: 'Ofertas',
                        value: '$total',
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Aceitas',
                        value: '${accepted.length}',
                        color: AppColors.good,
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Recusadas',
                        value: '$declined',
                        color: AppColors.text,
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Indefinidas',
                        value: '${total - accepted.length - declined}',
                      ),
                    ),
                  ],
                )),
                if (accepted.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Text(
                      '${accepted.length} de $total corridas confirmadas '
                      'como aceitas',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                if (_tab == 1) ...[
                  const SectionHeader(title: 'Resumo do período'),
                  SurfaceCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(brl(profit),
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('Lucro estimado das aceitas',
                            style: TextStyle(color: AppColors.muted)),
                        const Divider(height: 30, color: AppColors.border),
                        Text('Valor/h médio das ofertas: ${brl(avgPerHour)}',
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        const Text(
                            'O aceite não confirma a conclusão da viagem. Os valores usam os custos salvos em cada avaliação.',
                            style: TextStyle(
                                color: AppColors.muted,
                                height: 1.4,
                                fontSize: 12)),
                      ])),
                ] else ...[
                  const SectionHeader(title: 'Avaliações recentes'),
                  if (verdicts.isEmpty)
                    const SurfaceCard(
                        child: Text('Nenhuma oferta neste filtro.')),
                  ...verdicts.map(
                    (verdict) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey<String>(
                          '${verdict.offer.createdAt.toIso8601String()}'
                          '${verdict.offer.value}',
                        ),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.bad.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: AppColors.bad,
                          ),
                        ),
                        onDismissed: (_) {
                          final index = allVerdicts.indexOf(verdict);
                          ref.read(historyProvider.notifier).removeAt(index);
                        },
                        child: _HistoryTile(
                          verdict: verdict,
                          onTap: () => _showDetail(context, ref, verdict),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Zerar histórico?',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Todas as ofertas avaliadas serão apagadas deste aparelho. '
          'Isso também zera a base do simulador.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Apagar',
              style: TextStyle(color: AppColors.bad),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(historyProvider.notifier).clear();
  }

  void _showDetail(BuildContext context, WidgetRef ref, OfferVerdict verdict) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            VerdictCard(verdict: verdict),
            const SizedBox(height: 14),
            Text(
              switch (verdict.accepted) {
                true => 'Corrida confirmada como aceita',
                false => 'Corrida confirmada como recusada',
                null => 'Aceitação não identificada — confirme abaixo',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: PrimaryButton(
                    label: 'Aceitei',
                    icon: Icons.check_rounded,
                    tonal: true,
                    onPressed: () {
                      ref
                          .read(historyProvider.notifier)
                          .setAccepted(verdict, true);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Recusei',
                    icon: Icons.close_rounded,
                    tonal: true,
                    onPressed: () {
                      ref
                          .read(historyProvider.notifier)
                          .setAccepted(verdict, false);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Fechar',
              tonal: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.verdict, required this.onTap});

  final OfferVerdict verdict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final offer = verdict.offer;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          GradeDot(grade: verdict.overall, size: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  <String>[
                    offer.app.label,
                    if (offer.label != null && offer.label!.isNotEmpty)
                      offer.label!,
                  ].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shortDate(offer.createdAt)} · '
                  '${kmLabel(offer.distanceKm)} · '
                  '${timeLabel(offer.timeMin)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                brl(offer.value),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${brl(verdict.valuePerKm)}/km',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          if (verdict.accepted != null) ...<Widget>[
            Tooltip(
              message: verdict.accepted! ? 'Aceita' : 'Recusada',
              child: Icon(
                verdict.accepted!
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 15,
                color: verdict.accepted! ? AppColors.good : AppColors.bad,
              ),
            ),
            const SizedBox(width: 6),
          ],
          GradePill(grade: verdict.overall, compact: true),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onEvaluate});

  final VoidCallback onEvaluate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
                Icons.history_rounded,
                color: AppColors.muted,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nenhuma oferta avaliada',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada avaliação vira dado: é assim que o simulador aprende o '
              'padrão da sua região.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Avaliar uma oferta',
              icon: Icons.bolt_rounded,
              expanded: false,
              onPressed: onEvaluate,
            ),
          ],
        ),
      ),
    );
  }
}
