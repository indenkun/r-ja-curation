# R 日本語記事・キュレーション（Shiny + Shinylive + GitHub Pages）

**R 言語の日本語記事**を毎日自動収集し、**はてなブックマーク数**をスコアとして並べ替えて表示する
静的 Shiny サイトの雛形です。

- 収集: R スクリプト（RSS + はてブ数）
- 表示: Shiny（Shinylive で静的化）
- ホスト: GitHub Pages（`docs/`）
- 更新: GitHub Actions（1日1回）

---

## ✨ できること
- Qiita / Zenn / はてな IT ホッテントリなどから R 関連の日本語記事を取得
- はてブ数でランキング（人気順・新着順の切替）
- キーワード検索、ドメイン/ソースでの絞り込み
- 完全静的（Shinylive）なのでサーバー不要、Pages にそのまま置けます

## 📁 リポジトリ構成
```
.
├─ app/
│  ├─ app.R                 # Shiny アプリ本体（Shinylive 対応）
│  ├─ data/
│  │  └─ articles.json      # 収集結果（Actions が日次で更新）
│  └─ www/
│     └─ styles.css         # はてブ風の簡易スタイル
├─ R/
│  └─ fetch_articles.R      # RSS 収集 + はてブ数 + JSON 生成
├─ docs/                    # Shinylive の出力（Actions が自動生成）
├─ .github/
│  └─ workflows/
│     └─ build.yml          # 毎日ビルド & Pages 用コミット
├─ README.md
├─ LICENSE
└─ .gitignore
```

## 🚀 セットアップ手順
1. **この雛形を GitHub に作成**
   - リポジトリ名例: `r-ja-curation`
   - もしくはローカルで `git init` → GitHub に push

2. **GitHub Pages を有効化**
   - Settings → Pages → **Branch: `main` / Folder: `/docs`** を選択

3. **Actions の権限確認**
   - Settings → Actions → General → Workflow permissions →
     **"Read and write permissions"** を選択（`EndBug/add-and-commit` で push するため）

4. **Actions が自動実行**
   - 毎日（JST 0:00 相当）に自動ビルドされます
   - 手動実行は、Actions → `build-site` → **Run workflow**

> 初回は `app/data/articles.json` の空データで表示されます。Actions 実行後にリストが埋まります。

## 🧰 ローカルで試す
```bash
# R パッケージを入れて JSON を生成
Rscript R/fetch_articles.R

# shinylive で静的出力（docs/ に書き出し）
R -e 'install.packages("shinylive", repos="https://cloud.r-project.org"); shinylive::export("app", "docs")'
```

## 🔧 収集先の追加・調整
- 収集元は `R/fetch_articles.R` の `feeds` に追記してください
- R 関連の判定は `r_keywords` を編集
- 日本語判定（簡易）は `is_japanese()`。必要なら `cld3` 等で強化可能

## 🧮 ランキングの調整
`hb_count`（はてブ数）に新鮮さを掛け合わせたスコア例：
```r
mutate(score = hb_count / (1 + as.numeric(difftime(Sys.time(), published, units = "days"))))
```
Shiny 側のソートを `score` ベースに変えるだけで反映できます。

## 📝 ライセンス
MIT License（`LICENSE` を参照）

