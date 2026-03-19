# R 日本語記事・キュレーション（A案・安定化版：Shiny + Shinylive + GitHub Pages）

**R 言語の日本語記事**を毎日自動収集し、**はてなブックマーク数**でランキング表示する
静的 Shiny サイトの雛形（A案：`tidyRSS` 継続 + 例外安全化 + Actions 安定化）です。

- 収集: R スクリプト（RSS + はてブ数）
- 表示: Shiny（Shinylive で静的化）
- ホスト: GitHub Pages（`docs/`）
- 更新: GitHub Actions（1日1回、**pak + sysreqs 解決**）

---

## 主な違い（A案の安定化）
- `tidyRSS` の列名差を吸収する **安全な `fetch_one()`** 実装
- `is_japanese()` / `is_r_related()` を **ベクトル対応** に修正
- GitHub Actions を **`setup-r-dependencies@v2`** で安定化（`pak` + システム依存を自動解決）
- Node.js 24 へ **先行 opt-in**（非推奨警告を回避）

## フォルダ構成
```
.
├─ app/
│  ├─ app.R                 # Shiny アプリ本体（Shinylive対応）
│  ├─ data/
│  │  └─ articles.json      # 収集結果（Actionsで日次更新）
│  └─ www/
│     └─ styles.css         # はてブ風スタイル
├─ R/
│  └─ fetch_articles.R      # RSS収集 + はてブ数 + JSON生成（A案の修正）
├─ docs/                    # Shinyliveの出力（Actionsで自動生成）
│  └─ .nojekyll
├─ .github/
│  └─ workflows/
│     └─ build.yml          # 1日1回のビルド&コミット（pak + sysreqs）
├─ README.md
├─ LICENSE (MIT)
└─ .gitignore
```

## セットアップ（最短）
1. このテンプレートを新規リポジトリにアップロード（例：`r-ja-curation`）
2. Settings → Pages → **Branch: `main` / Folder: `/docs`**
3. Settings → Actions → General → Workflow permissions → **Read and write permissions**
4. Actions → `build-site` → **Run workflow**（初回手動実行推奨）

## ローカル試行（任意）
```bash
Rscript R/fetch_articles.R
R -e 'install.packages("shinylive", repos="https://cloud.r-project.org"); shinylive::export("app", "docs")'
```

## 収集源の追加
`R/fetch_articles.R` の `feeds` に RSS を追記してください。

## ランキング調整（例）
```r
mutate(score = hb_count / (1 + as.numeric(difftime(Sys.time(), published, units = "days"))))
```
Shiny 側を `score` でソートするように変更すれば反映されます。
