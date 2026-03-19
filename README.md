# r-ja-curation（CSS適用 & QiitaタグRSS & はてなキーワードRSS 版）

この版では以下を修正しています：

- Shiny の CSS を `includeCSS("www/styles.css")` で**インライン展開**し、Shinylive 環境でも確実にスタイルが適用されるようにしました（`tags$link` から変更）。
- Qiita のタグRSSを**正しいフォーマット** `https://qiita.com/tags/r/feed.atom` に修正しました。
- はてなブックマークの IT ホッテントリを廃止し、**キーワード検索RSS**（例：`https://b.hatena.ne.jp/q/R言語?mode=rss`）に置き換えてノイズを削減しました。

## 使い方（既存リポジトリに上書き）
1. この ZIP を展開し、既存リポジトリの同名ファイルを置き換え
2. コミット & Push
3. Actions の `build-site` を手動実行（初回は推奨）
4. 公開 URL をハードリロード（Service Worker のキャッシュを回避）

## 変更ファイル
- `app/app.R`：`includeCSS` 採用、テーマは `bs_theme(bootswatch = "flatly")` のみ
- `R/fetch_articles.R`：フィード集合の見直し（QiitaタグRSS、ZennトピックRSS、はてなキーワードRSS）
