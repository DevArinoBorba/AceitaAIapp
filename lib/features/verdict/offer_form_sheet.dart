import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/goals_repository.dart';
import '../../domain/entities/offer.dart';
import '../../domain/entities/verdict.dart';
import '../../domain/services/earnings_engine.dart';

/// Abre o formulário de avaliação manual de oferta.
/// Devolve o veredito ou `null` se o motorista cancelar.
Future<OfferVerdict?> showOfferFormSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<OfferVerdict>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: const _OfferFormSheet(),
    ),
  );
}

class _OfferFormSheet extends ConsumerStatefulWidget {
  const _OfferFormSheet();

  @override
  ConsumerState<_OfferFormSheet> createState() => _OfferFormSheetState();
}

class _OfferFormSheetState extends ConsumerState<_OfferFormSheet> {
  final _valueController = TextEditingController();
  final _distanceController = TextEditingController();
  final _timeController = TextEditingController();
  final _ratingController = TextEditingController();
  final _labelController = TextEditingController();

  DriverApp _app = DriverApp.uber;
  String? _error;

  @override
  void dispose() {
    _valueController.dispose();
    _distanceController.dispose();
    _timeController.dispose();
    _ratingController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    final raw = controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _submit() {
    final value = _parse(_valueController);
    final distance = _parse(_distanceController) ?? 0;
    final minutes = _parse(_timeController);
    final rating = _parse(_ratingController);

    if (value == null || value <= 0) {
      setState(() => _error = 'Informe o valor da corrida.');
      return;
    }
    if (distance < 0) {
      setState(() => _error = 'A distância não pode ser negativa.');
      return;
    }
    if (minutes == null || minutes <= 0) {
      setState(() => _error = 'Informe o tempo estimado em minutos.');
      return;
    }
    if (rating != null && (rating < 0 || rating > 5)) {
      setState(() => _error = 'A nota do passageiro vai de 0 a 5.');
      return;
    }

    final offer = Offer.create(
      appId: _app.id,
      value: value,
      distanceKm: distance,
      timeMin: minutes.round(),
      passengerRating: rating,
      label: _labelController.text.trim().isEmpty
          ? null
          : _labelController.text.trim(),
    );

    final verdict = EarningsEngine(ref.read(goalsProvider)).evaluate(offer);

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(verdict);
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Avaliar uma oferta',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Copie os números que o app de corrida mostrou. '
            'O cálculo usa suas metas (${brl(goals.minPerKm)}/km e '
            '${brl(goals.minPerHour)}/h).',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DriverApp.all
                .map(
                  (app) => ChoiceChip(
                    label: Text(app.label),
                    selected: _app.id == app.id,
                    onSelected: (_) => setState(() => _app = app),
                    labelStyle: TextStyle(
                      color: _app.id == app.id
                          ? AppColors.text
                          : AppColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: AppColors.primary.withValues(alpha: 0.18),
                    backgroundColor: AppColors.surfaceAlt,
                    side: BorderSide(
                      color: _app.id == app.id
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : AppColors.border,
                    ),
                    showCheckmark: false,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _valueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(color: AppColors.text),
                  decoration: appInput(label: 'Valor', hint: '21,40'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _distanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(color: AppColors.text),
                  decoration: appInput(label: 'Distância', hint: '8,2', suffix: 'km'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _timeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(color: AppColors.text),
                  decoration:
                      appInput(label: 'Tempo', hint: '22', suffix: 'min'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ratingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(color: AppColors.text),
                  decoration: appInput(
                    label: 'Nota (opcional)',
                    hint: '4,9',
                    prefixIcon: const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            style: const TextStyle(color: AppColors.text),
            decoration: appInput(
              label: 'Categoria (opcional)',
              hint: 'UberX, 99Pop...',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(Icons.error_outline,
                    color: AppColors.bad, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.bad,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Calcular veredito',
            icon: Icons.bolt_rounded,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
