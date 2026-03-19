# R 日本語記事・キュレーション（Shinylive修正パッチ版）

Shinylive の初回表示で白画面になるケースに対処した修正パッチ版です。

## 変更点
- `app/app.R` の CSS 参照を `www/styles.css` に変更
- `articles.json` の読み込みに try-catch を追加し、失敗時もアプリを落とさず通知表示
- そのほか構成は A 案（tidyRSS 継続 + GitHub Actions で日次更新）のまま

## セットアップ手順（概要）
1. 本テンプレートを GitHub に push
2. Settings → Pages → Source: `main` / Folder: `/docs`
3. Settings → Actions → General → Workflow permissions → **Read and write permissions**
4. Actions → `build-site` → **Run workflow**（初回）

## ローカル確認（任意）
```bash
Rscript R/fetch_articles.R
R -e 'install.packages("shinylive", repos="https://cloud.r-project.org"); shinylive::export("app", "docs")'
```
