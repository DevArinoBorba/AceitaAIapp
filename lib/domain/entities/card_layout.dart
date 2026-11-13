/// Quais números o card flutuante mostra.
///
/// As chaves são as mesmas do lado nativo (`reader/CardLayout.kt`): quem monta
/// o card é o serviço de acessibilidade, com o Aceita AI fechado, então mudar
/// aqui sem mudar lá deixa a opção sem efeito.
enum CardField {
  value('valor', 'Valor da oferta'),
  verdict('veredito', 'Veredito'),
  perKm('rkm', 'R\$ por km'),
  perHour('rh', 'R\$ por hora'),
  profit('lucro', 'Lucro estimado'),
  distance('km', 'Distância'),
  time('tempo', 'Tempo'),
  uberEstimate('uber', 'Estimativa do Uber'),
  rating('nota', 'Nota do passageiro');

  const CardField(this.key, this.label);

  /// Chave gravada nas preferências e lida pelo nativo.
  final String key;

  /// Rótulo mostrado na tela de ajustes.
  final String label;

  static CardField? fromKey(String key) {
    for (final field in CardField.values) {
      if (field.key == key) return field;
    }
    return null;
  }
}

/// O essencial para decidir em 3 segundos: R$/km, R$/h, nota e veredito.
///
/// O valor da oferta fica de fora de propósito — ele já está em letras grandes
/// no app de corrida, e repetir no card só ocupa espaço.
const Set<CardField> cardSimplePreset = <CardField>{
  CardField.perKm,
  CardField.perHour,
  CardField.rating,
  CardField.verdict,
};

/// Tudo o que o parser consegue ler — o que o card mostra por padrão.
final Set<CardField> cardDetailedPreset =
    Set<CardField>.unmodifiable(CardField.values);

/// Como o conjunto escolhido aparece na tela.
enum CardMode { simple, detailed, custom }

/// Conjunto efetivo a partir das chaves que vieram do nativo.
Set<CardField> cardFieldsFrom(List<String> keys) {
  if (keys.isEmpty) return cardDetailedPreset;
  final parsed = keys.map(CardField.fromKey).whereType<CardField>().toSet();
  return parsed.isEmpty ? cardDetailedPreset : parsed;
}

/// Diz se o conjunto atual é um preset ou uma escolha pessoal.
CardMode cardModeOf(Set<CardField> fields) {
  if (fields.isEmpty) return CardMode.detailed;
  if (fields.length == cardSimplePreset.length &&
      fields.containsAll(cardSimplePreset)) {
    return CardMode.simple;
  }
  if (fields.length == cardDetailedPreset.length) return CardMode.detailed;
  return CardMode.custom;
}

/// Opções de tempo (em segundos) que o card de oferta fica visível na tela.
const List<int> cardDurationOptions = <int>[5, 8, 10, 14, 20];

/// Tempo padrão (em segundos) de exibição do card de oferta.
const int defaultCardDurationSeconds = 10;
