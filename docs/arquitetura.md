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
