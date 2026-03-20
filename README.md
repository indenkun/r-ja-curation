
# R言語 × 日本語記事のキュレーション

日々の R 関連（日本語）記事を RSS から収集し、はてなブックマーク数などで整列して Shinylive で公開するリポジトリ。

## 収集・ビルドの流れ

1. `R/fetch_articles.R` が RSS を収集して `app/data/articles.json` を生成。
2. `build.R` が Shinylive へエクスポートし、`docs/` に静的サイトを出力。ここで **`template_params$title`** により `<title>` を確実に上書きします（デフォルトは "Shiny app" ）。citeturn23search88
3. GitHub Actions（`.github/workflows/site.yml`）が毎日・手動・`main` への push で 1→2 を実行し、Pages にデプロイします。

> Shinylive の `export()` はテンプレートに `title` を渡せます。assets > 0.4.1 ではデフォルトテンプレートが `title` をサポートしており、未指定時は **"Shiny app"** が入ります。citeturn23search88turn23search92

## ローカルで実行

```bash
# 1) JSON 生成
Rscript R/fetch_articles.R
# 2) Shinylive へエクスポート（<title> を同時に上書き）
Rscript build.R
# 3) docs/ をローカルサーバで配信（任意）
#   e.g., python -m http.server -d docs 8080
```

## 依存パッケージ（R）
- shiny, bslib, shinylive
- jsonlite, dplyr, purrr, stringr, lubridate, tibble, xml2, rvest, urltools, httr2, tidyRSS

## 補足：タイトルが更新されない時
Shinylive はアプリを iframe で表示するため、UI 側の `<title>` より**エクスポートのテンプレート側の `<title>`** が決定版です。`build.R` の `template_params$title` で上書きしたうえで、**ハードリロードや Service Worker の更新**も試してください。citeturn23search100turn23search98

