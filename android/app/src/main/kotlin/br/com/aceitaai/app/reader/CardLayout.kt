package br.com.aceitaai.app.reader

/**
 * Quais números o card mostra quando chega uma oferta.
 *
 * O card responde em 3 segundos "isso paga?", mas cada motorista decide com
 * números diferentes: um olha R$/km, outro o lucro depois do custo, outro só
 * quer o semáforo. Em vez de uma tela fixa, o card monta só as linhas que
 * estiverem ligadas.
 *
 * As chaves são gravadas nas preferências e lidas pelo Flutter — mudar uma
 * aqui exige mudar `CardField` no Dart (`lib/domain/entities/card_layout.dart`).
 */
enum class CardField(val key: String) {
    /** O valor da oferta, a manchete do card. */
    VALUE("valor"),

    /** VALE A PENA / NO LIMITE / RECUSAR. */
    VERDICT("veredito"),

    PER_KM("rkm"),
    PER_HOUR("rh"),

    /** O que sobra depois do custo por km. */
    PROFIT("lucro"),

    /** Busca + viagem em km. */
    DISTANCE("km"),
    TIME("tempo"),

    /** O R$/km que o próprio app do motorista imprime. */
    UBER("uber"),

    RATING("nota"),
    ;

    companion object {
        fun fromKey(key: String): CardField? = values().firstOrNull { it.key == key }
    }
}

object CardLayout {

    /** O essencial: valor, R$/km e veredito. */
    val SIMPLE: Set<CardField> = setOf(
        CardField.VALUE,
        CardField.VERDICT,
        CardField.PER_KM,
    )

    /** Tudo o que o parser consegue ler. */
    val DETAILED: Set<CardField> = CardField.values().toSet()

    /**
     * O padrão é o detalhado: é o card que já foi aprovado em campo, e quem
     * quiser menos escolhe "Simples" em dois toques.
     */
    val DEFAULT: Set<CardField> = DETAILED

    /** Conjunto efetivo a partir das chaves gravadas. */
    fun fromKeys(keys: Collection<String>?): Set<CardField> {
        if (keys.isNullOrEmpty()) return DEFAULT
        val parsed = keys.mapNotNull { CardField.fromKey(it) }.toSet()
        return parsed.ifEmpty { DEFAULT }
    }

    /**
     * Campos que pedem uma segunda linha (rota, tempo, nota, estimativa do
     * app). Com qualquer um deles o card precisa empilhar; sem nenhum, cabe
     * tudo lado a lado.
     */
    private val STACKED_FIELDS = setOf(
        CardField.DISTANCE,
        CardField.TIME,
        CardField.UBER,
        CardField.RATING,
    )

    /**
     * Diz se o card cabe em uma linha só.
     *
     * É o caso do preset Simples (valor + R$/km + veredito): uma faixa fina
     * no topo da tela em vez de um bloco de três linhas por cima do mapa.
     * Vale para qualquer escolha pessoal com até três números e sem rota.
     */
    fun isCompact(fields: Set<CardField>): Boolean =
        fields.size <= 3 && fields.none { it in STACKED_FIELDS }
}
