import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../platform/reader_channel.dart';

bool _checkedThisSession = false;

/// Reseta o controle de sessão (usado em testes).
void resetSessionCheckForTest() => _checkedThisSession = false;

/// Consulta o canal nativo por uma nova release no GitHub e exibe o popup de
/// atualização caso `hasUpdate == true`.
Future<void> checkAndShowUpdateDialog(
  BuildContext context, {
  ReaderChannel channel = const ReaderChannel(),
  bool manual = false,
}) async {
  if (!manual && _checkedThisSession) return;
  if (!manual) {
    _checkedThisSession = true;
  }

  final info = await channel.checkForUpdate();
  if (!context.mounted) return;

  if (info == null) {
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível verificar atualizações agora.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  if (!info.hasUpdate) {
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Você já está na versão mais recente (v${info.installedVersion}).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(info: info, channel: channel),
  );
}

enum _UpdateActionState {
  idle,
  downloading,
  permissionRequired,
  error,
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.info,
    this.channel = const ReaderChannel(),
  });

  /// Mantém métodos estáticos na classe além do nível de arquivo para
  /// conveniência de acesso.
  static bool get checkedThisSession => _checkedThisSession;
  static void resetSessionCheckForTest() => _checkedThisSession = false;

  final AppUpdateInfo info;
  final ReaderChannel channel;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _UpdateActionState _state = _UpdateActionState.idle;
  int _percent = 0;
  StreamSubscription<ReaderEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.channel.watch().listen((event) {
      final progress = event.updateProgress;
      if (progress == null || !mounted) return;
      if (_state == _UpdateActionState.downloading) {
        setState(() {
          _percent = progress.percent.clamp(0, 100);
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _cleanNotes {
    final raw = widget.info.notes.trim();
    if (raw.isNotEmpty) return raw;
    final title = widget.info.title.trim();
    if (title.isNotEmpty) return title;
    return 'Melhorias de estabilidade, leitura de tela e desempenho.';
  }

  Future<void> _onPrimaryPressed() async {
    switch (_state) {
      case _UpdateActionState.downloading:
        return;
      case _UpdateActionState.idle:
        setState(() {
          _state = _UpdateActionState.downloading;
          _percent = 0;
        });
        final result = await widget.channel.downloadAndInstallUpdate(
          downloadUrl: widget.info.downloadUrl,
          sha256: widget.info.sha256,
        );
        if (!mounted) return;
        _handleInstallResult(result);
      case _UpdateActionState.permissionRequired:
        setState(() {
          _state = _UpdateActionState.downloading;
        });
        final result = await widget.channel.installPendingUpdate();
        if (!mounted) return;
        _handleInstallResult(result);
      case _UpdateActionState.error:
        final targetUrl = widget.info.downloadUrl.isNotEmpty
            ? widget.info.downloadUrl
            : widget.info.htmlUrl;
        await widget.channel.openExternalUrl(targetUrl);
        if (!mounted) return;
        Navigator.of(context).pop();
    }
  }

  void _handleInstallResult(String result) {
    if (result == 'installer_launched') {
      Navigator.of(context).pop();
      return;
    }
    if (result == 'permission_required') {
      setState(() {
        _state = _UpdateActionState.permissionRequired;
      });
      return;
    }
    setState(() {
      _state = _UpdateActionState.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDownloading = _state == _UpdateActionState.downloading;

    final primaryLabel = switch (_state) {
      _UpdateActionState.idle => 'Atualizar agora',
      _UpdateActionState.downloading => 'Baixando...',
      _UpdateActionState.permissionRequired => 'Instalar agora',
      _UpdateActionState.error => 'Baixar pelo navegador',
    };

    final primaryIcon = switch (_state) {
      _UpdateActionState.idle => Icons.system_update_rounded,
      _UpdateActionState.downloading => Icons.downloading_rounded,
      _UpdateActionState.permissionRequired => Icons.install_mobile_rounded,
      _UpdateActionState.error => Icons.open_in_browser_rounded,
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SurfaceCard(
        padding: const EdgeInsets.all(20),
        borderColor: AppColors.primary.withValues(alpha: 0.45),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Uma nova versão está disponível',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Versão ${widget.info.latestVersion} (atual: ${widget.info.installedVersion})',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    _cleanNotes,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
            if (isDownloading) ...<Widget>[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _percent / 100.0,
                  minHeight: 7,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Baixando atualização... $_percent%',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_state == _UpdateActionState.permissionRequired) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.average.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.average.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.security_update_warning_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Autorize a opção "Permitir desta fonte" no Android e toque em Instalar agora.',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_state == _UpdateActionState.error) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bad.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.bad.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.bad,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Falha ao baixar dentro do app. Você pode baixar direto pelo navegador.',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: primaryLabel,
              icon: primaryIcon,
              onPressed: isDownloading ? null : _onPrimaryPressed,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed:
                    isDownloading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Depois',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
