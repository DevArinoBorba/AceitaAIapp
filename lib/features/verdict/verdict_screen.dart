import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/history_repository.dart';
import '../../domain/entities/verdict.dart';
import 'offer_form_sheet.dart';
import 'offer_analysis.dart';

class VerdictScreen extends ConsumerStatefulWidget {
  const VerdictScreen({super.key, required this.verdict});

  final OfferVerdict verdict;

  @override
  ConsumerState<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends ConsumerState<VerdictScreen> {
  late OfferVerdict _current = widget.verdict;
  bool _saved = false;

  Future<void> _save() async {
    await ref.read(historyProvider.notifier).add(_current);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Oferta salva no histórico.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _evaluateAnother() async {
    final verdict = await showOfferFormSheet(context, ref);
    if (verdict == null || !mounted) return;
    setState(() {
      _current = verdict;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final verdict = _current;
    final offer = verdict.offer;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Avaliar oferta',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            OfferAnalysis(verdict: verdict),
            const SizedBox(height: 18),
            PrimaryButton(
              label: _saved ? 'Salvo no histórico' : 'Salvar no histórico',
              icon: _saved ? Icons.check_rounded : Icons.bookmark_add_outlined,
              onPressed: _saved ? null : _save,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Avaliar outra oferta',
              icon: Icons.add_rounded,
              tonal: true,
              onPressed: _evaluateAnother,
            ),
            const SizedBox(height: 22),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  iconColor: AppColors.muted,
                  collapsedIconColor: AppColors.muted,
                  title: const Text(
                    'Como foi calculado',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  children: <Widget>[
                    _FormulaRow(
                      label: 'R\$/km',
                      formula: '${brl(offer.value)} / '
                          '${decimal(offer.distanceKm)} km',
                      result: brl(verdict.valuePerKm),
                    ),
                    _FormulaRow(
                      label: 'R\$/hora',
                      formula: '${brl(offer.value)} / '
                          '${decimal(offer.timeMin / 60.0, 2)} h',
                      result: brl(verdict.valuePerHour),
                    ),
                    _FormulaRow(
                      label: 'Custo',
                      formula: '${decimal(offer.distanceKm)} km x '
                          '${brl(verdict.goals.costPerKm)}',
                      result: brl(offer.distanceKm * verdict.goals.costPerKm),
                    ),
                    _FormulaRow(
                      label: 'Lucro',
                      formula: '${brl(offer.value)} - custo',
                      result: brl(verdict.profit),
                    ),
                    _FormulaRow(
                      label: 'Margem',
                      formula: 'lucro / ${brl(offer.value)}',
                      result: pctLabel(verdict.profitPct),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Os semáforos comparam cada métrica com as suas metas '
                      '(Metas > R\$/km, R\$/hora e margem mínima). A pior '
                      'métrica manda no veredito final.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  const _FormulaRow({
    required this.label,
    required this.formula,
    required this.result,
  });

  final String label;
  final String formula;
  final String result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              formula,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            result,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
