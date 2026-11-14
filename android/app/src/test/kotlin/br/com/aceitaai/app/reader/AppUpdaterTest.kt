package br.com.aceitaai.app.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AppUpdaterTest {

    @Test
    fun `normalizeVersion remove prefixo v e sufixo de build`() {
        assertEquals("0.1.10", AppUpdater.normalizeVersion("v0.1.10"))
        assertEquals("0.1.10", AppUpdater.normalizeVersion("V0.1.10+12"))
        assertEquals("0.2.0", AppUpdater.normalizeVersion(" 0.2.0+1 "))
        assertEquals("1.0.0", AppUpdater.normalizeVersion("v1.0.0-beta1"))
    }

    @Test
    fun `isNewerVersion compara segmentos numericos corretamente`() {
        assertTrue(AppUpdater.isNewerVersion("0.1.10", "0.1.11"))
        assertTrue(AppUpdater.isNewerVersion("v0.1.10+11", "v0.1.11"))
        assertTrue(AppUpdater.isNewerVersion("0.1.19", "0.2.0"))
        assertTrue(AppUpdater.isNewerVersion("0.9.9", "1.0.0"))

        assertFalse(AppUpdater.isNewerVersion("0.1.10", "0.1.10"))
        assertFalse(AppUpdater.isNewerVersion("v0.1.10+12", "v0.1.10"))
        assertFalse(AppUpdater.isNewerVersion("0.1.11", "0.1.10"))
        assertFalse(AppUpdater.isNewerVersion("0.2.0", "0.1.99"))
    }

    @Test
    fun `parseReleaseJson extrai metadados, asset universal e sha256`() {
        val sampleJson = """
            {
              "tag_name": "v0.1.12",
              "name": "Aceita AI v0.1.12",
              "draft": false,
              "prerelease": false,
              "html_url": "https://github.com/DevArinoBorba/AceitaAIapp/releases/tag/v0.1.12",
              "body": "Correções de leitura em tempo real e atualização pelo app.",
              "assets": [
                {
                  "name": "app-arm64-v8a-release.apk",
                  "size": 18500000,
                  "browser_download_url": "https://github.com/DevArinoBorba/AceitaAIapp/releases/download/v0.1.12/app-arm64-v8a-release.apk",
                  "digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111"
                },
                {
                  "name": "AceitaAI-v0.1.12-universal.apk",
                  "size": 24123456,
                  "browser_download_url": "https://github.com/DevArinoBorba/AceitaAIapp/releases/download/v0.1.12/AceitaAI-v0.1.12-universal.apk",
                  "digest": "sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
                }
              ]
            }
        """.trimIndent()

        val result = AppUpdater.parseReleaseJson(sampleJson, "0.1.11+12")
        assertNotNull(result)
        result!!

        assertEquals("0.1.11", result["installedVersion"])
        assertEquals("0.1.12", result["latestVersion"])
        assertEquals("v0.1.12", result["tagName"])
        assertEquals("Aceita AI v0.1.12", result["title"])
        assertEquals("Correções de leitura em tempo real e atualização pelo app.", result["notes"])
        assertEquals(
            "https://github.com/DevArinoBorba/AceitaAIapp/releases/download/v0.1.12/AceitaAI-v0.1.12-universal.apk",
            result["downloadUrl"],
        )
        assertEquals(
            "https://github.com/DevArinoBorba/AceitaAIapp/releases/tag/v0.1.12",
            result["htmlUrl"],
        )
        assertEquals("AceitaAI-v0.1.12-universal.apk", result["assetName"])
        assertEquals(24123456L, result["assetSize"])
        assertEquals(
            "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
            result["sha256"],
        )
        assertEquals(true, result["hasUpdate"])
    }

    @Test
    fun `parseReleaseJson marca hasUpdate false quando versao instalada e igual ou maior`() {
        val sampleJson = """
            {
              "tag_name": "v0.1.12",
              "name": "v0.1.12",
              "draft": false,
              "prerelease": false,
              "html_url": "https://github.com/DevArinoBorba/AceitaAIapp/releases/tag/v0.1.12",
              "body": "Notas",
              "assets": [
                {
                  "name": "app-release.apk",
                  "size": 1024,
                  "browser_download_url": "https://example.com/app-release.apk"
                }
              ]
            }
        """.trimIndent()

        val same = AppUpdater.parseReleaseJson(sampleJson, "0.1.12")!!
        assertEquals(false, same["hasUpdate"])

        val newerInstalled = AppUpdater.parseReleaseJson(sampleJson, "0.1.13")!!
        assertEquals(false, newerInstalled["hasUpdate"])
    }

    @Test
    fun `parseReleaseJson ignora draft e prerelease`() {
        val draftJson = """
            {
              "tag_name": "v0.2.0",
              "draft": true,
              "prerelease": false,
              "assets": []
            }
        """.trimIndent()
        assertNull(AppUpdater.parseReleaseJson(draftJson, "0.1.10"))

        val prereleaseJson = """
            {
              "tag_name": "v0.2.0-rc1",
              "draft": false,
              "prerelease": true,
              "assets": []
            }
        """.trimIndent()
        assertNull(AppUpdater.parseReleaseJson(prereleaseJson, "0.1.10"))
    }
}
