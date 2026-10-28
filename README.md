# Aceita AI

Copiloto de ganhos para motoristas de aplicativo. Lê a oferta na tela do app de
corrida, calcula a conta (R$/km, R$/h, lucro, margem) e mostra um card
flutuante dizendo, em segundos, se vale aceitar.

O projeto nasceu do estudo de engenharia reversa do GigU (documento em
`C:\Users\arino\Downloads\GigU_reverso_plano_clone.md`). A arquitetura segue a
mesma ideia de duas camadas (Flutter + Kotlin), mas com código, marca, textos e
design próprios — nada de ativo, texto ou script do GigU.

**Estado:** validado em aparelho real com oferta real do Uber Driver
(`valor=17,04 · 13,2 km · 24 min → R$/km 1,29 · R$/h 43` — igual à estimativa
impressa pelo próprio Uber). 99 Motorista e inDrive têm parser escrito, ainda
não testados com ofertas reais.

---

## 1. Rodar

Pré-requisitos (já instalados nesta máquina):

- Flutter 3.47.8 — `C:\Users\arino\dev\flutter`
- Android SDK 36 — `C:\Users\arino\Android\Sdk` (`ANDROID_HOME` configurado)
- JDK 21 — `C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot`

Em um shell novo:

```powershell
$env:Path = "C:\Users\arino\dev\flutter\bin;$env:Path"
cd C:\Users\arino\Projetos\copiloto
flutter pub get
flutter analyze
flutter test
flutter run                  # com o celular plugado e depuração USB ligada
```

Gerar o APK de release:

```powershell
flutter build apk --release                  # universal (~35 MB)
flutter build apk --release --split-per-abi  # por ABI (arm64 ~34 MB)
# saída: build\app\outputs\flutter-apk\
```

Instalar no celular por USB:

```powershell
adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

Depois de instalar ou de `am force-stop`, o MIUI desliga o serviço de
acessibilidade. Religar por ADB:

```powershell
adb shell settings put secure enabled_accessibility_services "br.com.copiloto.app/br.com.copiloto.app.reader.OfferReaderService"
adb shell settings put secure accessibility_enabled 1
adb shell cmd appops set br.com.copiloto.app SYSTEM_ALERT_WINDOW allow
```

---

## 2. O que existe

| Tela | Rota | O que faz |
|---|---|---|
| Home | `/` | lucro analisado do dia, progresso da meta, atalhos, status do serviço |
| Metas | `/metas` | R$/km, R$/h, margem, custo/km, metas de faturamento e nota |
| Avaliar oferta | `/avaliar` | entrada manual (valor, km, min, nota) → veredito colorido |
| Veredito | `/avaliar` | 5 métricas, semáforo por métrica, "como foi calculado" |
| Simulador | `/simulador` | projeção semanal/mensal filtrando por R$/km (Turbo) |
| Histórico | `/historico` | resumo, lista, detalhe, swipe para apagar |
| Leitura | `/leitura` | ativação do serviço, apps monitorados, card da oferta, testes |
| Ajustes | `/ajustes` | modo PRO (dev), gerar exemplo, zerar dados, fórmulas |
| Planos | `/planos` | paywall com 3 planos (checkout ainda não conectado) |

Estado compartilhado com Riverpod: `goalsProvider`, `historyProvider`,
`subscriptionProvider`, `readerProvider`, `sharedPreferencesProvider`.

---

## 3. Motor de cálculo

Dois motores idênticos, um em cada camada — o card precisa calcular com o app
fechado, então a conta também vive no Kotlin:

- Dart: `lib/domain/services/earnings_engine.dart`
- Kotlin: `android/.../reader/EarningsEngine.kt`

```
R$/km   = valor / distância
R$/h    = valor / (minutos / 60)
R$/min  = valor / minutos
lucro   = valor - (distância × custo/km)
margem  = lucro / valor × 100
```

Semáforo: `>= meta boa` → verde · `>= meta mínima` → amarelo · abaixo →
vermelho. O veredito final é o **pior** entre R$/km, R$/hora e margem
(prejuízo é sempre vermelho). Nota do passageiro tem semáforo próprio.

O simulador (`lib/domain/services/simulator.dart`) projeta mantendo as mesmas
horas trabalhadas — mostra o ganho de recusar corrida ruim **e** o custo em
taxa de aceitação.

---

## 4. O leitor nativo

`AccessibilityService` (`br.com.copiloto.app.reader.OfferReaderService`) +
`MediaProjection` + ML Kit OCR + overlay.

O ponto central descoberto no aparelho: **o card da oferta do Uber não está na
árvore de acessibilidade**. O serviço recebe eventos de toda a tela, mas os
números da oferta não aparecem. Por isso o caminho real é:

1. o evento de acessibilidade diz que uma janela nova apareceu;
2. o serviço tira um screenshot (`MediaProjection`, `canTakeScreenshot`);
3. o ML Kit lê o texto da imagem;
4. o parser procura os números por **padrão de texto** (nunca por `viewId`);
5. o `EarningsEngine` calcula e o card flutua por cima do app de corrida.

Apps monitorados: Uber Driver (`com.ubercab.driver`), 99 Motorista
(`com.app99.driver`) e inDrive (`sinet.startup.inDrive`). Só apps escolhidos
são lidos; nada sai do aparelho.

Diagnóstico: em modo dev, o serviço guarda a última foto que o OCR recebeu
(`files/shots/tela_HHmmss.jpg`, as 8 últimas), o texto lido (`ocr.jsonl`) e os
dumps de acessibilidade (`dumps.jsonl`). `tools/inspect_dumps.py` resume os
dumps.

O card usa `FLAG_SECURE` para não aparecer em gravações — **exceto** o card de
exemplo/preview, e esse se esconde sozinho quando o app volta para a frente,
para não contaminar a próxima leitura.

---

## 5. Card personalizável

`/leitura → Card da oferta`: 9 números alternáveis, com dois presets.

| Campo | Chave |
|---|---|
| Valor da oferta | `valor` |
| R$/km | `rkm` |
| R$/h | `rh` |
| R$/min | `rmin` |
| Lucro | `lucro` |
| Margem | `margem` |
| Distância da busca | `buscaKm` |
| Distância da viagem | `viagemKm` |
| Tempo estimado | `min` |

O preset **não é estado salvo** — ele é derivado do conjunto de campos
(Simples / Detalhada / Personalizado). Assim o card nunca fica inconsistente
com o que está salvo. O card recusa ficar sem nenhum número.

---

## 6. Estrutura

```
lib/
  main.dart                  bootstrap + SharedPreferences
  app.dart                   MaterialApp.router (dark) + ciclo de vida
  core/
    theme/app_theme.dart     paleta cockpit + ThemeData
    widgets/ui_kit.dart      SurfaceCard, GradePill, PrimaryButton, inputs
    utils/formatters.dart    R$, km, tempo, data (sem intl)
    router/app_router.dart   8 rotas
  domain/
    entities/{goals,offer,verdict,card_layout}.dart
    services/{earnings_engine,simulator}.dart   <- regras puras
  data/
    prefs.dart
    goals_repository.dart    metas em JSON
    history_repository.dart  histórico em JSON (cap 300)
  features/
    home/ calculator/ verdict/ simulator/ history/ reader/ settings/
    paywall/ subscription/
  platform/
    reader_channel.dart      MethodChannel/EventChannel do leitor
android/app/src/main/kotlin/br/com/copiloto/app/reader/
  OfferReaderService.kt      serviço de acessibilidade + captura + card
  OfferParser.kt             parser por padrão de texto
  EarningsEngine.kt          conta espelhada do Dart
  OfferCardView.kt           desenho do card flutuante
  CardLayout.kt              campos + presets do card
  ScreenOcr.kt               ML Kit + throttle + snapshots
  ReaderBubble.kt            balão de status
  ReaderBridge.kt            prefs + MethodChannel + EventChannel
test/
  earnings_engine_test.dart  fórmulas e semáforos
  simulator_test.dart        projeção
  card_layout_test.dart      chaves dos campos (quebra de compatibilidade)
  reader_channel_test.dart   parsing do status nativo
  app_test.dart              fluxo de telas
```

Regra de ouro: **nenhuma regra de negócio na UI**.

---

## 7. Limites conscientes

- Sem login/conta — dados só no aparelho.
- Sem RevenueCat — `subscriptionProvider` é stub com modo dev.
- Histórico em JSON no `SharedPreferences`; troca por Drift/SQLite quando
  passar de ~1.000 ofertas.
- Tema claro não existe de propósito.
- 99 e inDrive: parser escrito, falta validar com oferta real.
- Ofertas lidas pelo card ainda não entram no histórico automaticamente (a home
  soma só o que foi avaliado/salvo).

---

## 8. Aviso legal (leia antes de publicar)

Ler a tela de apps de corrida via `AccessibilityService` é a parte sensível:

- o Google Play exige que o uso seja *core functionality* declarado;
- Uber/99/inDrive proíbem automação nos termos de uso — o risco de banimento é
  da conta do motorista;
- gravação de tela e dados de passageiro caem na LGPD.

Este repositório **não** copia marca, logo, textos, vídeos, imagens nem scripts
do GigU. A arquitetura foi estudada; os ativos são próprios.

---

## 9. Identificadores técnicos

O nome do produto é **Aceita AI**, mas o identificador Android continua
`br.com.copiloto.app` (namespace, `applicationId`, canais
`br.com.copiloto.app/reader*`, prefs `copiloto_reader`). Foi mantido de
propósito: trocar o `applicationId` obriga desinstalar o app, conceder a
acessibilidade de novo e perde metas e histórico. É invisível para o motorista
e pode ser trocado quando o app for para a Play Store.
