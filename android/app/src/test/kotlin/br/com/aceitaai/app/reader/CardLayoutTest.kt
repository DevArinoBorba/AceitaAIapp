package br.com.aceitaai.app.reader

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * O card enxuto decide se a oferta vira uma faixa fina no topo ou um bloco de
 * três linhas por cima do mapa.
 *
 * A regra precisa ser previsível: o preset Simples sempre cabe em uma linha, e
 * qualquer campo de rota (distância, tempo, nota, estimativa do app) obriga a
 * empilhar — senão o texto estoura a largura da tela em aparelho pequeno.
 */
class CardLayoutTest {

    @Test
    fun `preset simples cabe em uma linha`() {
        assertTrue(CardLayout.isCompact(CardLayout.SIMPLE))
    }

    @Test
    fun `preset detalhado empilha`() {
        assertFalse(CardLayout.isCompact(CardLayout.DETAILED))
    }

    @Test
    fun `campo de rota obriga empilhar`() {
        assertFalse(CardLayout.isCompact(setOf(CardField.VALUE, CardField.DISTANCE)))
        assertFalse(CardLayout.isCompact(setOf(CardField.VALUE, CardField.TIME)))
        assertFalse(CardLayout.isCompact(setOf(CardField.VALUE, CardField.RATING)))
        assertFalse(CardLayout.isCompact(setOf(CardField.VALUE, CardField.UBER)))
    }

    @Test
    fun `escolha pessoal de ate tres numeros continua enxuta`() {
        assertTrue(CardLayout.isCompact(setOf(CardField.VALUE, CardField.PER_HOUR)))
        assertTrue(
            CardLayout.isCompact(
                setOf(CardField.VALUE, CardField.PER_KM, CardField.VERDICT),
            ),
        )
    }

    @Test
    fun `quatro numeros empilham`() {
        assertFalse(
            CardLayout.isCompact(
                setOf(
                    CardField.VALUE,
                    CardField.PER_KM,
                    CardField.PER_HOUR,
                    CardField.VERDICT,
                ),
            ),
        )
    }
}
