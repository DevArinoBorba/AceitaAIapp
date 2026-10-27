# Copiloto

Copiloto de ganhos para motoristas de aplicativo. Este é o **MVP (fase 1)**:
motor de cálculo, metas, veredito por oferta, histórico local e simulador —
tudo funcionando sem depender de serviço nativo.

O projeto nasceu da engenharia reversa do GigU (documento completo em
`C:\Users\arino\Downloads\GigU_reverso_plano_clone.md`). A arquitetura segue a
mesma ideia de duas camadas (Flutter + Kotlin), mas com código, marca, textos e
design próprios.

---

## 1. Rodar

Pré-requisitos:

- Flutter 3.47+ (Dart 3.13) — neste ambiente o SDK está em `C:\Users\arino\dev\flutter`
- Para gerar APK: Android SDK + `flutter doctor --android-licenses`

```powershell
cd C:\Users\arino\Projetos\copiloto
C:\Users\arino\dev\flutter\bin\flutter.bat pub get
C:\Users\arino\dev\flutter\bin\flutter.bat run      # com celular plugado
C:\Users\arino\dev\flutter\bin\flutter.bat analyze
C:\Users\arino\dev\flutter\bin\flutter.bat test
```

Sem Android SDK você ainda consegue rodar tudo que importa agora:
`analyze` + `test` (23 testes, incluindo fluxo completo de tela).

---

## 2. O que já existe

| Tela | Rota | O que faz |
|---|---|---|
| Home | `/` | lucro analisado do dia, progresso da meta, atalhos, status do serviço nativo |
| Metas | `/metas` | sliders de R$/km, R$/h, margem, custo/km, metas de faturamento e nota |
| Avaliar oferta | bottom sheet → `/avaliar` | entrada manual (valor, km, min, nota) → veredito colorido |
| Veredito | `/avaliar` | card com 5 métricas, semáforo por métrica, "como foi calculado" |
| Simulador | `/simulador` | projeção semanal/mensal filtrando por R$/km (bloqueado no free) |
| Histórico | `/historico` | resumo, lista, detalhe, swipe para apagar |
| Ajustes | `/ajustes` | modo PRO (dev), gerar exemplo, zerar dados, fórmulas |
| Planos | `/planos` | paywall com 3 planos (checkout ainda não conectado) |

Estado compartilhado com Riverpod: `goalsProvider`, `historyProvider`,
`subscriptionProvider`, `sharedPreferencesProvider` (injetado no `main`).

---

## 3. Motor de cálculo

`lib/domain/services/earnings_engine.dart` — puro, sem Flutter, 100% testado.

```
R$/km   = valor / distância
R$/h    = valor / (minutos / 60)
R$/min  = valor / minutos
lucro   = valor - (distância × custo/km)
margem  = lucro / valor × 100
```

Semáforo: `>= meta boa` → verde · `>= meta mínima` → amarelo · abaixo → vermelho.
O veredito final é o **pior** entre R$/km, R$/hora e margem (prejuízo é sempre
vermelho). Nota do passageiro tem semáforo próprio.

O simulador (`lib/domain/services/simulator.dart`) roda sobre o histórico real e
projeta **mantendo as mesmas horas trabalhadas**:

```
lucro/hora depois = lucro das ofertas aceitas / horas das ofertas aceitas
projeção semanal  = lucro/hora depois × horas por semana
```

Isso é honesto: mostra o ganho de recusar corrida ruim **e** o custo em taxa de
aceitação.

---

## 4. Estrutura

```
lib/
  main.dart                  bootstrap + SharedPreferences
  app.dart                   MaterialApp.router (dark)
  core/
    theme/app_theme.dart     paleta cockpit + ThemeData
    widgets/ui_kit.dart      SurfaceCard, GradePill, PrimaryButton, inputs
    utils/formatters.dart    R$, km, tempo, data (sem intl)
    router/app_router.dart   7 rotas do MVP
  domain/
    entities/{goals,offer,verdict}.dart
    services/{earnings_engine,simulator}.dart   <- regras puras
  data/
    prefs.dart
    goals_repository.dart    metas em JSON
    history_repository.dart  histórico em JSON (cap 300) + seed de exemplo
  features/
    home/ calculator/ verdict/ simulator/ history/ settings/ paywall/ subscription/
test/
  earnings_engine_test.dart  11 testes das fórmulas e semáforos
  simulator_test.dart        6 testes de projeção
  app_test.dart              3 testes de tela (fluxo completo)
```

Regra de ouro: **nenhuma regra de negócio na UI**. Quando o serviço nativo
entrar (fase 2), ele chama o mesmo `EarningsEngine` e o card do overlay é o
mesmo desenho do `VerdictCard`.

---

## 5. Fase 2 — serviço nativo (próximo passo)

Detalhes em `docs/arquitetura.md`. Resumo:

1. `GiguServices`-like: foreground service que sobrevive ao app fechado.
2. `AccessibilityService` lê o texto da oferta no app de corrida.
3. Parser **declarativo em JSON** (não Lua): regex + regras por app/versão.
4. Fallback OCR (ML Kit) quando o parser falha.
5. Overlay do card + TTS + histórico local.
6. Ponte Pigeon: o nativo publica o veredito, o Flutter só configura e desenha.

---

## 6. Limites conscientes do MVP

- Sem login/conta (fase 5) — dados só no aparelho.
- Sem RevenueCat (fase 6) — `subscriptionProvider` é stub com modo dev.
- Histórico em JSON no `SharedPreferences`; troca por Drift/SQLite quando passar
  de ~1.000 ofertas ou quando entrar sincronização.
- Tema claro não existe de propósito.
- Nada de acessibilidade, câmera ou overlay ainda: essas permissões só entram
  quando o serviço existir, para não pedir acesso sem entregar valor.

## 7. Aviso legal (leia antes de publicar)

Ler a tela de apps de corrida via `AccessibilityService` é a parte sensível:
- o Google Play exige que o uso seja *core functionality* declarado;
- Uber/99/iFood proíbem automação nos termos de uso — o risco de banimento é da
  conta do motorista;
- gravação de tela e dados de passageiro caem na LGPD.

Este repositório **não** copia marca, logo, textos, vídeos, imagens nem scripts
do GigU. A arquitetura foi estudada; os ativos são seus.
