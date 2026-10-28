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
`/sdcard/Android/data/br.com.aceitaai.app/files/dumps.jsonl` (teto de 400
linhas), o que permite puxar por `adb` sem depender da UI do app.

## 8. Oferta → card (out/2026)

Três peças, cada uma testável sozinha:

| Peça | Arquivo | Papel |
|---|---|---|
| `OfferParser` | `reader/OfferParser.kt` | texto da tela → `ParsedOffer` (valor, busca, viagem) |
| `EarningsEngine` | `reader/EarningsEngine.kt` | `ParsedOffer` + metas → `Verdict` (R$/km, R$/h, lucro, semáforo) |
| `OfferCardView` | `reader/OfferCardView.kt` | janela flutuante com a conta, 14 s |

**Parser por texto, não por id.** Id do Uber muda entre versões, e 99/inDrive
usam outro conjunto; o texto da oferta não muda. Três padrões resolvem as duas
formas conhecidas:

- radar: `R$ 7,15` · `4 min • 0.9 km` · `5 minutos • 1.2 km`
- solicitação: `R$ 12,34` · `3 min (1,2 km) de distância` · `Viagem de 12 min (5,4 km)`

Regras que evitam falso positivo: ignora `R$` seguido de `/km` ou `/min`
(estimativa), ignora linha com `%` ou começando com `+` (bônus no mapa), exige
pelo menos um par tempo+distância e exige valor > 0.

**Total = busca + viagem.** É a mesma conta que o Uber imprime em
`Est. de R$/km`: 7,15 ÷ (0,9 + 1,2) = 3,40. O teste
`OfferParserTest.a conta fecha com a estimativa do proprio Uber` trava isso.

**Cálculo duplicado de propósito.** O card precisa aparecer com o Aceita AI
fechado — só o serviço está vivo —, então o motor existe em Kotlin também. As
metas vêm do prefs (`min_per_km`, `good_per_km`, ...), gravadas pelo app; os
valores padrão são os mesmos do Dart. A tela de veredito continua usando o
motor Dart.

**Leitura janela por janela.** O card da oferta é uma janela própria sobre o
mapa. Misturar as duas fazia o parser pegar bônus do mapa; agora cada janela é
tentada isolada e, se nenhuma render, tenta-se o conjunto. O log diz em qual
janela a oferta foi lida (`oferta uber janela=2 ...`).

Testes: `android/app/src/test/kotlin/.../OfferParserTest.kt` roda com
`gradlew :app:testDebugUnitTest` (JVM puro, sem aparelho).

**O card é montado, não fixo.** Cada motorista decide com números diferentes —
um olha R$/km, outro o lucro depois do custo, outro só quer o semáforo. Então
o card desenha apenas os campos escolhidos em `/leitura → Card da oferta`
(`reader/CardLayout.kt` no nativo, `domain/entities/card_layout.dart` na tela,
chaves iguais nos dois):

| Campo | Chave | No card |
|---|---|---|
| Valor da oferta | `valor` | manchete grande |
| Veredito | `veredito` | canto do topo |
| R$ por km | `rkm` | fileira de números |
| R$ por hora | `rh` | fileira de números |
| Lucro estimado | `lucro` | fileira de números |
| Distância | `km` | linha de rota |
| Tempo | `tempo` | linha de rota |
| Estimativa do Uber | `uber` | linha de rota |
| Nota do passageiro | `nota` | linha de rota |

Dois presets em cima disso: **Simples** (`valor + veredito + rkm`, o essencial
em 3 segundos) e **Detalhada** (tudo, o padrão). Os presets não são estado
guardado — são só conjuntos de campos; mexer num chip qualquer tira a seleção
dos dois e a tela mostra "personalizado".

Duas regras que evitam card quebrado:

- **Sempre há uma manchete.** Valor desligado? O próximo mais decisivo (R$/km,
  R$/h, lucro) assume o lugar grande — e sai da fileira de baixo, para o mesmo
  número não aparecer duas vezes.
- **Nunca fica vazio.** Desligar o último campo é recusado com um aviso; sem
  isso o card viraria uma tira só com o nome do app.

**O card de exemplo é o único sem `FLAG_SECURE`.** Ele existe para ser olhado,
então precisa sair nas capturas de tela; em troca, `setAppInForeground(false)`
o fecha na hora — se sobrevivesse por cima do Uber, o OCR poderia ler a nossa
própria conta como se fosse oferta (foi o que aconteceu no primeiro teste).
Oferta real continua sempre protegida.

## 9. Leitura por imagem (OCR) — o card do Uber não está na árvore

Medido no aparelho em 27/10/2026: durante 3 minutos com ofertas reais na tela,
23 capturas voltaram **só o mapa** (13–25 nós, 1 janela). O card de oferta do
Uber não entra na árvore de acessibilidade — não é janela separada nem id
diferente: o texto simplesmente não existe para o serviço. Ler nós nunca ia
funcionar para o Uber.

O caminho que funciona é imagem:

| Peça | Arquivo | Papel |
|---|---|---|
| `ScreenOcr` | `reader/ScreenOcr.kt` | `takeScreenshot()` (API 30+, sem diálogo) → ML Kit on-device → linhas de texto |
| `tryOcr` | `reader/OfferReaderService.kt` | dispara o OCR quando a leitura por nós não acha oferta |
| batimento | `reader/OfferReaderService.kt` | a cada 4 s, se um app lido está na frente |

Decisões que custaram caro para descobrir:

- **`android:canTakeScreenshot="true"`** no XML do serviço. Sem isso o
  `takeScreenshot()` falha em silêncio com `SecurityException: Services don't
  have the capability of taking the screenshot`.
- **R8 não pode ofuscar o ML Kit.** Em release o serviço morria no
  `onServiceConnected` com `NullPointerException: Attempt to read from field ...
  on a null object reference` — o ML Kit se registra por reflexão e o R8
  removia as classes. `isMinifyEnabled = false` no `release`.
- **O card não pode aparecer na foto.** Primeiro teste, o OCR leu o próprio
  card na leitura seguinte e realimentou o parser (valor virou `R$ 715`, km
  2,0). `FLAG_SECURE` na janela do card resolve: ele fica fora da captura.
- **O batimento não pode depender de evento.** Se a oferta aparece numa tela
  que não muda, nenhum evento chega. Um `postDelayed` de 4 s confere
  `rootInActiveWindow` e só fotografa se for um app lido (senão OCR de outro
  app viraria oferta falsa).

O texto do OCR é o mesmo insumo do parser, com dois cuidados a mais:

- **Valor pela vizinhança.** A tela inteira entra na leitura, então o topo do
  Uber (`-R$ 628,82`, ganhos do dia) e o `R$ 3,40` da coluna `R$/km` são
  candidatos. O parser escolhe o valor mais próximo do primeiro par km/min e
  descarta linha com `+`/`-` e número colado num rótulo `R$/km` sem número.
- **Número trocado por letra.** OCR lê `l.2 km` no lugar de `1.2 km`; sem
  normalizar, o trecho da viagem desaparece e o R$/km sai errado. `fixOcrNumbers`
  troca `l/I/|`→`1` e `O/o`→`0` só em tokens isolados.

Diagnóstico: cada leitura vai inteira para `ocr.jsonl` (o diag guarda só as
primeiras linhas). É o insumo para ajustar o parser com ofertas reais.

Validação de ponta a ponta: foto da oferta de radar aberta na galeria com
"capturar qualquer app" ligado → card com `R$ 7,15 · busca 0,9 · viagem 1,2 ·
9 min · R$ 3,40/km`, igual à estimativa do próprio Uber.

**Oferta real (23:01, 27/10/2026)** — Uber online, card do Uber na tela:

```
oferta uber fonte=ocr janela=todas valor=17.04 km=13.2 min=24
       buscaKm=5.4 viagemKm=7.8 rkm=1,29 rh=43 uber=1.29 veredito=AVERAGE
```

Bate com a tela do Uber: `R$ 17,04`, `Est. de R$1,29/km`, `10 min • 5.4 km`
(busca) e `14 minutos • 7.8 km` (viagem). O `uber=1.29` é a estimativa que o
próprio Uber imprime; nosso R$/km saiu idêntico, que é o teste que importa —
a conta não é nossa opinião, é a mesma do app.

Duas lições de campo:

- **Offline não recebe oferta.** Um teste de 3 minutos "sem card" era só o
  motorista offline: o OCR leu `Você está offline` em 34 leituras seguidas,
  todas do mapa. Antes de acusar o leitor, procurar essa linha no `ocr.jsonl`.
- **Guardar a foto, não só o texto.** Quando não sai card, o log diz o que o
  OCR leu mas não o que ele *deixou* de ver. Com "capturar qualquer app" ligado,
  `ScreenOcr.saveSnapshot` grava a imagem exata que foi para o OCR
  (`files/shots/tela_HHmmss.jpg`, últimas 8). Foi assim que ficou claro que o
  problema era a tela, e não o parser. Ligado só no modo de descoberta, porque
  são ~500 KB por leitura.

## 10. Oferta lida → histórico (out/2026)

Até aqui a oferta existia só no card: o histórico e o "Lucro analisado hoje" da
home continuavam zerados, porque só entravam ofertas avaliadas à mão. Agora toda
oferta lida é gravada — inclusive com o app fechado, que é justamente quando o
card aparece.

| Peça | Arquivo | Papel |
|---|---|---|
| `OfferHistory` | `reader/OfferHistory.kt` | grava a oferta na chave `history_v1` do `FlutterSharedPreferences` |
| `maybeShowOffer` | `reader/OfferReaderService.kt` | chama `OfferHistory.record` depois de desenhar o card |
| `HistoryRepository.reload` | `data/history_repository.dart` | relê o arquivo (o `SharedPreferences` guarda tudo em memória) |
| `_reportVisibility` | `app.dart` | ao voltar para a frente, relê o histórico |

Detalhes que evitam dado errado:

- **Mesmo formato do Dart.** O nativo escreve `{"offer": {...}, "goals": {...}}`
  igual a `OfferVerdict.toJson()`. As metas são copiadas inteiras do JSON do
  Flutter (`goals_v1`), não reconstruídas: margem e metas de faturamento não
  existem no lado nativo, e a oferta precisa ser reavaliada com as metas da
  hora em que foi lida.
- **Assinatura contra duplicata.** O card se redesenha a cada 8 s enquanto a
  oferta está na tela; sem isso a mesma corrida entraria dezenas de vezes.
  `appId|valor|km|min` iguais dentro de 5 minutos = mesma oferta.
- **Gravar antes de apagar.** `add`/`removeAt` releem o arquivo antes de salvar;
  senão uma ação na tela apagaria as ofertas que o serviço gravou enquanto o
  app estava em segundo plano.
- **`commit()`, não `apply()`.** A oferta pode ser a última coisa antes de o
  sistema matar o processo do serviço.
- **Teste sem oferta real.** No modo dev, "Registrar oferta de exemplo" chama o
  mesmo `OfferHistory.record` por um método de diagnóstico — é assim que a
  integração é conferida sem depender de uma corrida na rua.

---

## 11. Aceitou ou recusou? (out/2026)

A meta diária somava **todas** as ofertas lidas: se o motorista recebia 20
ofertas e aceitava 5, a barra somava 20. Faltava a informação que só existe
depois da decisão — e ela não está na oferta.

Decisão de produto: descobrir pela **tela seguinte** do app de corrida, sem
pedir toque nenhum ao motorista (ele já está dirigindo/decidindo).

| Peça | Arquivo | Papel |
|---|---|---|
| `AcceptanceParser` | `reader/AcceptanceParser.kt` | frases de aceite e de mapa de espera, texto normalizado (sem acento) |
| `AcceptanceWatch` | `reader/OfferReaderService.kt` | guarda a oferta recém-lida e observa o mesmo app por 45 s |
| `OfferHistory.markLatest` | `reader/OfferHistory.kt` | grava `accepted` na entrada 0, se a assinatura ainda for a mesma |
| `OfferVerdict.accepted` | `domain/entities/verdict.dart` | `true` / `false` / `null` (indefinida) |
| `HistoryNotifier.setAccepted` | `data/history_repository.dart` | correção à mão pelo histórico |

Assimetria proposital:

- **Aceite é conclusivo.** "A caminho do passageiro", "Iniciar viagem",
  "Deslize para iniciar", "Finalizar viagem" só existem depois de aceitar.
  Uma leitura basta.
- **Recusa é inferência.** O mapa de espera ("Procurando viagens") também
  aparece *antes* da oferta, e continua atrás do card. Então ela exige duas
  condições: o valor da corrida não está mais na leitura (o card saiu) e o mapa
  se mantém por ≥ 3 s. Duas observações separadas por 3 s.
- **Janela de 45 s.** Depois disso a oferta fica `null` e o motorista pode
  corrigir à mão (histórico → toque → Aceitei/Recusei). Sem essa saída, uma
  falha de leitura viraria dado errado para sempre.
- **Só o mesmo app responde.** `OfferParser.appIdOf(pkg)` tem que bater com o
  app da oferta; um "A caminho do passageiro" no WhatsApp não conta.
- **O card fecha no aceite**, senão ficaria por cima da navegação.

Efeito na home: "Ganho confirmado hoje" soma só as aceitas (é o que move a barra
da meta); o total lido continua visível como "Analisado: R$ X em N ofertas".


