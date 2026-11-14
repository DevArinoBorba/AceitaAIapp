package br.com.aceitaai.app.reader

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * Atualização direta pelo GitHub Releases.
 *
 * O app não está na loja: quando sai uma versão nova, ele consulta o último
 * release de `DevArinoBorba/AceitaAIapp`, baixa o APK para `cache/updates/`,
 * confere o SHA-256 (quando disponível na release) e chama o instalador do
 * sistema via `FileProvider`.
 */
object AppUpdater {

    const val GITHUB_LATEST_RELEASE_URL =
        "https://api.github.com/repos/DevArinoBorba/AceitaAIapp/releases/latest"

    private const val CONNECT_TIMEOUT_MS = 10_000
    private const val READ_TIMEOUT_MS = 10_000
    private const val DOWNLOAD_READ_TIMEOUT_MS = 30_000
    private const val PROGRESS_THROTTLE_MS = 150L
    private const val UPDATES_DIR = "updates"
    private const val APK_FILENAME = "AceitaAI-update.apk"

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }

    /**
     * Normaliza uma string de versão removendo espaços, prefixo `v`/`V`,
     * sufixo `+build` e sufixo `-pre` eventual (ex.: `"v0.1.10+12"` -> `"0.1.10"`).
     */
    fun normalizeVersion(raw: String): String {
        val trimmed = raw.trim().removePrefix("v").removePrefix("V").trim()
        val withoutBuild = trimmed.substringBefore('+').substringBefore('-').trim()
        return withoutBuild
    }

    /**
     * Compara os segmentos numéricos separados por `.` e retorna `true` se
     * `remote` for estritamente mais nova que `installed`.
     */
    fun isNewerVersion(installed: String, remote: String): Boolean {
        val normInstalled = normalizeVersion(installed)
        val normRemote = normalizeVersion(remote)
        if (normRemote.isBlank()) return false
        if (normInstalled.isBlank()) return true

        val installedParts = normInstalled.split('.').map { it.trim().toIntOrNull() ?: 0 }
        val remoteParts = normRemote.split('.').map { it.trim().toIntOrNull() ?: 0 }
        val maxLen = maxOf(installedParts.size, remoteParts.size)

        for (i in 0 until maxLen) {
            val inst = installedParts.getOrElse(i) { 0 }
            val rem = remoteParts.getOrElse(i) { 0 }
            if (rem > inst) return true
            if (rem < inst) return false
        }
        return false
    }

    /**
     * Extrai os metadados da resposta JSON de `/releases/latest` do GitHub.
     *
     * Ignora releases marcados como `draft` ou `prerelease` (retorna `null`).
     */
    fun parseReleaseJson(jsonText: String, installedVersion: String): Map<String, Any?>? {
        if (jsonText.isBlank()) return null
        val json = try {
            JSONObject(jsonText)
        } catch (_: Exception) {
            return null
        }

        if (json.optBoolean("draft", false) || json.optBoolean("prerelease", false)) {
            return null
        }

        val tagName = json.optString("tag_name", "").trim()
        if (tagName.isBlank()) return null

        val title = json.optString("name", "").trim().ifBlank { tagName }
        val notes = json.optString("body", "").trim()
        val htmlUrl = json.optString("html_url", "").trim()

        val assets = json.optJSONArray("assets") ?: JSONArray()
        var chosenAsset: JSONObject? = null
        for (i in 0 until assets.length()) {
            val asset = assets.optJSONObject(i) ?: continue
            val name = asset.optString("name", "")
            if (!name.endsWith(".apk", ignoreCase = true)) continue
            if (chosenAsset == null) {
                chosenAsset = asset
            } else if (name.contains("universal", ignoreCase = true) &&
                !chosenAsset.optString("name", "").contains("universal", ignoreCase = true)
            ) {
                chosenAsset = asset
            }
        }

        val downloadUrl = chosenAsset?.optString("browser_download_url", "")?.trim().orEmpty()
        val assetName = chosenAsset?.optString("name", "")?.trim().orEmpty()
        val assetSize = chosenAsset?.optLong("size", 0L) ?: 0L
        val rawDigest = chosenAsset?.optString("digest", "")?.trim().orEmpty()
        val sha256 = if (rawDigest.startsWith("sha256:", ignoreCase = true)) {
            rawDigest.substringAfter(':').trim().lowercase().takeIf { it.isNotBlank() }
        } else {
            null
        }

        val normInstalled = normalizeVersion(installedVersion)
        val latestVersion = normalizeVersion(tagName)
        val hasUpdate = isNewerVersion(normInstalled, latestVersion) && downloadUrl.isNotBlank()

        return mapOf(
            "installedVersion" to normInstalled,
            "latestVersion" to latestVersion,
            "tagName" to tagName,
            "title" to title,
            "notes" to notes,
            "downloadUrl" to downloadUrl,
            "htmlUrl" to htmlUrl,
            "assetName" to assetName,
            "assetSize" to assetSize,
            "sha256" to sha256,
            "hasUpdate" to hasUpdate,
        )
    }

    /** Lê o `versionName` instalado via `PackageManager`. */
    fun installedVersion(context: Context): String {
        return try {
            val pm = context.packageManager
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(context.packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(context.packageName, 0)
            }
            info.versionName?.let { normalizeVersion(it) } ?: "0.0.0"
        } catch (_: Exception) {
            "0.0.0"
        }
    }

    /** Verifica se o app tem permissão para disparar instalação de APK. */
    fun canInstallPackages(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /**
     * Consulta o último release no GitHub em segundo plano e devolve o mapa de
     * estado na thread principal.
     */
    fun checkForUpdate(context: Context, callback: (Map<String, Any?>?, String?) -> Unit) {
        val appContext = context.applicationContext
        executor.execute {
            var connection: HttpURLConnection? = null
            try {
                val url = URL(GITHUB_LATEST_RELEASE_URL)
                connection = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    instanceFollowRedirects = true
                    connectTimeout = CONNECT_TIMEOUT_MS
                    readTimeout = READ_TIMEOUT_MS
                    setRequestProperty("Accept", "application/vnd.github+json")
                    setRequestProperty("User-Agent", "AceitaAI-Android")
                }

                val code = connection.responseCode
                if (code !in 200..299) {
                    val errMsg = "Falha ao consultar GitHub Releases (HTTP $code)"
                    mainHandler.post { callback(null, errMsg) }
                    return@execute
                }

                val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val currentInstalled = installedVersion(appContext)
                val parsed = parseReleaseJson(body, currentInstalled)
                val result = if (parsed != null) {
                    parsed + ("canInstallPackages" to canInstallPackages(appContext))
                } else {
                    mapOf(
                        "installedVersion" to currentInstalled,
                        "latestVersion" to currentInstalled,
                        "tagName" to "",
                        "title" to "",
                        "notes" to "",
                        "downloadUrl" to "",
                        "htmlUrl" to "",
                        "assetName" to "",
                        "assetSize" to 0L,
                        "sha256" to null,
                        "hasUpdate" to false,
                        "canInstallPackages" to canInstallPackages(appContext),
                    )
                }
                mainHandler.post { callback(result, null) }
            } catch (error: Exception) {
                mainHandler.post {
                    callback(null, error.message ?: "Erro de rede ao buscar atualização")
                }
            } finally {
                connection?.disconnect()
            }
        }
    }

    /**
     * Baixa o APK da release, valida o hash SHA-256 quando informado e inicia
     * o instalador do Android (ou abre a tela de permissão de fontes desconhecidas).
     */
    fun downloadAndInstall(
        context: Context,
        downloadUrl: String,
        expectedSha256: String?,
        onProgress: (Map<String, Any?>) -> Unit,
        callback: (Map<String, Any?>?, String?) -> Unit,
    ) {
        val appContext = context.applicationContext
        if (downloadUrl.isBlank()) {
            callback(null, "URL de download vazia")
            return
        }

        executor.execute {
            var connection: HttpURLConnection? = null
            val updatesDir = File(appContext.cacheDir, UPDATES_DIR)
            if (!updatesDir.exists()) updatesDir.mkdirs()
            val apkFile = File(updatesDir, APK_FILENAME)
            if (apkFile.exists()) apkFile.delete()

            try {
                var currentUrl = downloadUrl
                var redirects = 0
                while (redirects < 5) {
                    val url = URL(currentUrl)
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        instanceFollowRedirects = true
                        connectTimeout = CONNECT_TIMEOUT_MS
                        readTimeout = DOWNLOAD_READ_TIMEOUT_MS
                        setRequestProperty("User-Agent", "AceitaAI-Android")
                    }
                    val code = conn.responseCode
                    if (code in 300..399) {
                        val location = conn.getHeaderField("Location")
                        conn.disconnect()
                        if (location.isNullOrBlank()) {
                            throw IllegalStateException("Redirecionamento sem destino (HTTP $code)")
                        }
                        currentUrl = URL(url, location).toString()
                        redirects++
                        continue
                    }
                    connection = conn
                    break
                }

                val activeConn = connection
                    ?: throw IllegalStateException("Excesso de redirecionamentos ao baixar APK")

                val code = activeConn.responseCode
                if (code !in 200..299) {
                    activeConn.disconnect()
                    mainHandler.post {
                        callback(null, "Falha ao baixar APK (HTTP $code)")
                    }
                    return@execute
                }

                val totalBytes = activeConn.contentLengthLong
                val digest = MessageDigest.getInstance("SHA-256")
                var bytesRead = 0L
                var lastEmitTime = 0L
                var lastPercent = -1

                activeConn.inputStream.use { input ->
                    FileOutputStream(apkFile).use { output ->
                        val buffer = ByteArray(16 * 1024)
                        while (true) {
                            val read = input.read(buffer)
                            if (read <= 0) break
                            output.write(buffer, 0, read)
                            digest.update(buffer, 0, read)
                            bytesRead += read

                            val percent = if (totalBytes > 0L) {
                                ((bytesRead * 100L) / totalBytes).toInt().coerceIn(0, 100)
                            } else {
                                -1
                            }
                            val now = System.currentTimeMillis()
                            val shouldEmit = (now - lastEmitTime >= PROGRESS_THROTTLE_MS) ||
                                (percent >= 0 && kotlin.math.abs(percent - lastPercent) >= 2) ||
                                (totalBytes > 0L && bytesRead >= totalBytes)

                            if (shouldEmit) {
                                lastEmitTime = now
                                lastPercent = percent
                                val progressMap = mapOf<String, Any?>(
                                    "status" to "downloading",
                                    "percent" to percent,
                                    "bytesRead" to bytesRead,
                                    "totalBytes" to totalBytes,
                                )
                                mainHandler.post { onProgress(progressMap) }
                            }
                        }
                        output.flush()
                    }
                }

                val expectedClean = expectedSha256
                    ?.trim()
                    ?.removePrefix("sha256:")
                    ?.trim()
                    ?.lowercase()
                    .orEmpty()

                if (expectedClean.isNotBlank()) {
                    val actualHex = digest.digest().joinToString("") { "%02x".format(it) }
                    if (!actualHex.equals(expectedClean, ignoreCase = true)) {
                        apkFile.delete()
                        mainHandler.post { callback(null, "Hash SHA-256 inválido") }
                        return@execute
                    }
                }

                mainHandler.post {
                    try {
                        if (!canInstallPackages(appContext)) {
                            openUnknownSourcesSettings(appContext)
                            callback(
                                mapOf(
                                    "status" to "permission_required",
                                    "apkPath" to apkFile.absolutePath,
                                ),
                                null,
                            )
                        } else {
                            launchInstaller(appContext, apkFile)
                            callback(
                                mapOf(
                                    "status" to "installer_launched",
                                    "apkPath" to apkFile.absolutePath,
                                ),
                                null,
                            )
                        }
                    } catch (installError: Exception) {
                        callback(
                            null,
                            installError.message ?: "Não foi possível abrir o instalador do APK",
                        )
                    }
                }
            } catch (error: Exception) {
                if (apkFile.exists()) apkFile.delete()
                mainHandler.post {
                    callback(null, error.message ?: "Erro ao baixar atualização")
                }
            } finally {
                connection?.disconnect()
            }
        }
    }

    /**
     * Retoma a instalação de um APK já baixado em `cache/updates/AceitaAI-update.apk`
     * (por exemplo, quando o motorista volta da tela de permissão de fontes desconhecidas).
     */
    fun installPendingUpdate(context: Context): Map<String, Any?> {
        val appContext = context.applicationContext
        val apkFile = File(File(appContext.cacheDir, UPDATES_DIR), APK_FILENAME)
        if (!apkFile.exists() || apkFile.length() <= 0L) {
            return mapOf("status" to "missing_file")
        }
        return if (!canInstallPackages(appContext)) {
            openUnknownSourcesSettings(appContext)
            mapOf(
                "status" to "permission_required",
                "apkPath" to apkFile.absolutePath,
            )
        } else {
            launchInstaller(appContext, apkFile)
            mapOf(
                "status" to "installer_launched",
                "apkPath" to apkFile.absolutePath,
            )
        }
    }

    /** Abre uma URL externa no navegador padrão do aparelho. */
    fun openBrowserUrl(context: Context, url: String): Boolean {
        if (url.isBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openUnknownSourcesSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return
            } catch (_: Exception) {
                // fallback abaixo
            }
        }
        try {
            val fallback = Intent(
                Settings.ACTION_SECURITY_SETTINGS,
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(fallback)
        } catch (_: Exception) {
            // Aparelho sem atalho direto
        }
    }

    private fun launchInstaller(context: Context, apkFile: File) {
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
