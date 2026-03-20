
# build.R — Shinyliveのエクスポート時に<title>を確実に反映
# 実行例: Rscript build.R

if (!requireNamespace("shinylive", quietly = TRUE)) stop("shinylive が必要です")

shinylive::export(
  appdir = "app",
  destdir = "docs",
  template_params = list(
    title = "R言語 × 日本語記事のキュレーション"
  )
)
cat("Exported to docs/ with custom <title>\n")
