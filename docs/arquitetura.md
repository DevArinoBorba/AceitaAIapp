# Arquitetura — fase 2 (serviço nativo)

Objetivo: ler a oferta na tela do app de corrida, calcular com o mesmo motor do
MVP e mostrar o card flutuante — sem o motorista digitar nada.

```
┌─────────────────────────── Flutter (painel) ───────────────────────────┐
│ configura metas · liga/desliga · histórico · assinatura · tela de teste │
└───────────────▲────────────────────────────────────┬───────────────────┘
                │ EventChannel (veredito, status)     │ Pigeon (comandos)
┌───────────────┴────────────────────────────────────▼───────────────────┐
│ Kotlin                                                                  │
│  CopilotService (foreground, sobrevive ao app)                          │
│    ├── ScreenReader (AccessibilityService)                              │
│    ├── ParserRegistry (JSON por app/versão) + fallback OCR (ML Kit)      │
│    ├── EarningsEngine (porta do Dart, mesmas fórmulas)                  │
│    ├── OverlayCard (SYSTEM_ALERT_WINDOW) + TTS                          │
│    └── HistoryStore (SQLite) + SyncWorker (WorkManager)                  │
└─────────────────────────────────────────────────────────────────────────┘
```

## 1. Contrato Pigeon (proposta)

```dart
@HostApi()
abstract class CopilotHostApi {
  Future<void> start(ServiceConfig config);
  Future<void> stop();
  Future<bool> isRunning();

  Future<void> updateGoals(GoalsData goals);        // espelha as metas
  Future<void> updateSubscription(bool turbo);      // gate do serviço
  Future<void> updateParserPack(String json);       // pack remoto de parsers

  Future<ReaderStatus> readerStatus();
  Future<void> openAccessibilitySettings();
  Future<void> openOverlaySettings();

  Future<List<DetectedOffer>> localHistory({int limit});
  Future<void> clearHistory();
  Future<TestResult> runTest(TestRequest request);  // replay de dump de tela
}

@EventChannel()
abstract class CopilotEvents {
  Stream<ReaderStatus> readerStatusChanged();
  Stream<OfferVerdictData> verdict();
  Stream<UsageStatsData> stats();
}
```

Modelos: `ServiceConfig{costPerKm, minPerKm, goodPerKm, minPerHour, goodPerHour,
voiceEnabled, overlayOpacity, overlayDurationMs, screenshotEnabled}`,
`DetectedOffer{appId, flavorId, value, km, minutes, rating, label, addresses,
rawTexts, receivedAt}`, `OfferVerdictData{offer, valuePerKm, valuePerHour,
profit, profitPct, semaphores, overall}`.

Regra: **o nativo não decide preço**. Ele recebe as metas atualizadas pelo
Flutter e devolve métricas + veredito. Se a assinatura cair, `updateSubscription(false)`
para o serviço imediatamente (é o que o GigU faz e é o comportamento correto).

## 2. Parser declarativo (substitui Lua)

Um JSON por app, versionado, enviado pelo servidor:

```json
{
  "app": "uber",
  "country": "BR",
  "flavorId": "BR_Uber",
  "versionRange": { "min": 400000, "max": null },
  "match": {
    "package": "com.ubercab.driver",
    "title": "Nova viagem"
  },
  "fields": {
    "value": {
      "patterns": ["R\\$\\s*([\\d.,]+)"],
      "source": "any",
      "type": "money"
    },
    "distance": {
      "patterns": ["([\\d,.]+)\\s*km"],
      "type": "distance"
    },
    "minutes": {
      "patterns": ["(\\d+)\\s*min"],
      "type": "int"
    },
    "rating": {
      "patterns": ["★\\s*([\\d.,]+)"],
      "type": "decimal",
      "optional": true
    },
    "label": {
      "patterns": ["^(UberX|Uber Comfort|Moto|99Pop)$"],
      "type": "text",
      "optional": true
    }
  },
  "requires": ["value", "distance", "minutes"],
  "limits": { "maxValue": 500, "maxDistance": 200, "maxMinutes": 240 }
}
```

Vantagens sobre Lua: sem runtime nativo extra, validável no servidor, testável
com `runTest`, seguro (sem código executável vindo da rede), e o "pack" pode ser
trocado sem atualizar o APK.

Quando o JSON falhar → OCR da região do app → mesmo schema aplicado ao texto do
OCR → se falhar de novo, telemetria com o dump cru (o servidor vira o
laboratório de parsers).

## 3. Fluxo e cuidados

1. `TYPE_WINDOW_CONTENT_CHANGED` com **debounce por package** (~350 ms) e hash do
   conteúdo para não processar a mesma tela duas vezes.
2. Identifica `package` → parser aplicável (app + país + versão).
3. Extrai os campos, valida limites (evita R$ 12.000 de bug de regex).
4. Calcula com o motor (mesmas fórmulas do Dart — manter uma única especificação
   em `docs/formulas.md` para não divergir).
5. Deduplica por `(package, value, km, min, janela de 20s)`.
6. Publica o veredito (EventChannel) → Flutter + overlay + TTS + histórico.
7. Se `turbo == false` → para o reader e limpa o overlay.

Erros precisam ser **parciais**: parser falhou → OCR; OCR falhou → só registra
telemetria; histórico falhou → card e voz continuam. O GigU trata cada etapa
separadamente — é o que mantém o app utilizável com tela nova de app de corrida.

## 4. Permissões (pedir só quando o serviço existir)

`BIND_ACCESSIBILITY_SERVICE` (serviço), `SYSTEM_ALERT_WINDOW` (card),
`FOREGROUND_SERVICE` + tipo adequado, `POST_NOTIFICATIONS`,
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `RECEIVE_BOOT_COMPLETED` (religar no
boot), `FOREGROUND_SERVICE_MEDIA_PROJECTION` só quando a câmera/print entrar.

Onboarding por fabricante (Xiaomi/Samsung/Motorola) é obrigatório: sem
"autostart" e "bateria sem restrição" o serviço morre em minutos.

## 5. Ordem de implementação

| Passo | Entrega |
|---|---|
| 1 | `CopilotService` + Pigeon + tela de status (sem leitura ainda) |
| 2 | `ScreenReader` logando os textos da tela (debug) |
| 3 | Parser JSON para **um** app (Uber BR) + `runTest` com dump real |
| 4 | Overlay + TTS + histórico local |
| 5 | OCR fallback + telemetria de falha |
| 6 | Boot, bateria, multi-app, pack remoto |

## 6. Política do Google Play

O formulário de declaração de acessibilidade exige: finalidade específica,
vídeo de demonstração e justificativa de por que não há API pública. A leitura
de oferta de terceiros é o ponto frágil — tenha um plano B (entrada manual
rápida com atalho, que já existe neste MVP) e nunca use o serviço para coletar
dados além do necessário para o cálculo.

## 7. Como ficou de fato (estado em out/2026)

Divergências em relação ao plano acima, todas deliberadas:

| Plano | Feito | Motivo |
|---|---|---|
| Pigeon (codegen) | `MethodChannel` + `EventChannel` | Sem etapa de geração; a fachada tipada em Dart dá o mesmo contrato |
| Parser + cálculo no Kotlin | Kotlin só coleta texto; cálculo no Dart | Uma fórmula só (`EarningsEngine`), sem risco de divergir |
| Uber BR | Só apps de motorista | Ver lista abaixo |

Pacotes lidos (`ReaderBridge.defaultTargets`):

| App | Pacote |
|---|---|
| Uber Driver | `com.ubercab.driver` |
| 99 Motorista e Entregador | `com.app99.driver` (o `com.taxis99` é o do passageiro) |
| inDrive | `sinet.startup.inDriver` (mesmo app para passageiro e motorista) |

Coleta: `AccessibilityService` com debounce de 350 ms, dedupe de 2,5 s, teto de
500 nós e profundidade 40. Cada nó guarda `text`, `id` (`viewIdResourceName`) e
`class`. Ignora system UI, launcher e ajustes; nunca lê a própria tela. A
captura usa `rootInActiveWindow.packageName` como fonte da verdade (o evento
pode chegar de um pacote e a árvore já ser de outro durante a transição).

`viewIdResourceName` existe no Uber Driver e é estável — é nele que o parser vai
se ancorar, não no texto. Ids confirmados na home do motorista: `go_online_button`,
`header_text_view`, `paragraph_text_view`, `map_marker_title`,
`glide_bottom_nav_home`, `glide_bottom_nav_earnings`, `glide_bottom_nav_inbox`.

Diagnóstico: além do prefs, cada captura vai para
`/sdcard/Android/data/br.com.copiloto.app/files/dumps.jsonl` (teto de 400
linhas), o que permite puxar por `adb` sem depender da UI do app.
