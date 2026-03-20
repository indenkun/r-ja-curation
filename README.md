
# r-ja-curation-design-v2

- タイトル `<title>` を UI 側で明示。Shinylive エクスポート時は `template_params$title` を併用推奨。
- カード 3〜4 列の CSS Grid。
- `hit_keywords` を JSON に保存してカードに表示。
- はてな・Bing の検索語を更新：**Shiny を除外**、**tidymodels / readr / stringr / rlang** を追加。

## 注意
- Shinylive の出力 HTML によっては、`template_params$title` がないと `<title>` が "shiny app" になることがあります。ワークフロー側で次のように指定してください：

```r
shinylive::export(appdir = "app", destdir = "docs", template_params = list(title = "R言語 × 日本語記事のキュレーション"))
```

その上で、公開後に **ハードリロード** や **Service Worker の更新**を行ってください。
