package br.com.aceitaai.app.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * O card enxuto decide se a oferta vira uma faixa fina no topo ou um bloco de
 * três linhas por cima do mapa.
 *
 * A regra precisa ser previsível: o preset Simples sempre cabe em uma linha, e
 * qualquer campo de rota (distância, tempo, estimativa do app) obriga a
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
        assertFalse(CardLayout.isCompact(setOf(CardField.VALUE, CardField.UBER)))
    }

    @Test
    fun `nota cabe na faixa fina`() {
        assertTrue(CardLayout.isCompact(setOf(CardField.RATING, CardField.VERDICT)))
        assertTrue(
            CardLayout.isCompact(
                setOf(CardField.PER_KM, CardField.PER_HOUR, CardField.RATING),
            ),
        )
    }

    @Test
    fun `escolha pessoal de ate quatro numeros continua enxuta`() {
        assertTrue(CardLayout.isCompact(setOf(CardField.VALUE, CardField.PER_HOUR)))
        assertTrue(
            CardLayout.isCompact(
                setOf(CardField.VALUE, CardField.PER_KM, CardField.PER_HOUR, CardField.RATING),
            ),
        )
    }

    @Test
    fun `cinco numeros empilham`() {
        assertFalse(
            CardLayout.isCompact(
                setOf(
                    CardField.VALUE,
                    CardField.PER_KM,
                    CardField.PER_HOUR,
                    CardField.PROFIT,
                    CardField.VERDICT,
                ),
            ),
        )
    }

    @Test
    fun `preset simples e rkm rh nota e veredito`() {
        assertEquals(
            setOf(
                CardField.PER_KM,
                CardField.PER_HOUR,
                CardField.RATING,
                CardField.VERDICT,
            ),
            CardLayout.SIMPLE,
        )
    }

    @Test
    fun `preset simples antigo migra para o novo`() {
        assertEquals(
            CardLayout.SIMPLE,
            CardLayout.fromKeys(listOf("valor", "veredito", "rkm")),
        )
    }

    @Test
    fun `sem chaves gravadas o card e o detalhado`() {
        assertEquals(CardLayout.DETAILED, CardLayout.fromKeys(emptyList()))
    }
}
