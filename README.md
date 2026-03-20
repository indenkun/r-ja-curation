
# R言語 × 日本語記事のキュレーション / R Language × Japanese-language Article Curation

このパッケージは、以下の3点を一括反映した差し替え用 ZIP です。

1. **ブラウザタブのタイトル**をサイト名に合わせる（UIの`<head>`に`<title>`を明示）。
2. **カードの3〜4列グリッド表示**（CSS Grid）。
3. **どの検索語でヒットしたか**をJSON (`hit_keywords`) に保存し、カード下部にタグ表示。

> 補足：Shinylive でエクスポートする場合は、`shinylive::export(..., template_params=list(title="サイト名"))` を併用すると、出力HTMLの`<title>`が確実に上書きされます（UI側の`<title>`も併用しています）。

---

## 置き換え対象
- `app/app.R`
- `app/www/styles.css`
- `R/fetch_articles.R`

`app/data/articles.json` はプレースホルダです（初回ビルドで上書きされます）。

---

## 反映手順
1. 本 ZIP を展開し、既存リポジトリの同名ファイルを**上書き**。
2. Commit & Push。
3. GitHub Actions の `build-site` を実行。
4. 公開サイトをハードリロード（Service Worker キャッシュ回避）。

