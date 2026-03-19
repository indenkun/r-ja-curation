# r-ja-curation（Shinylive 白画面修正・最小差分）

- `bslib::bs_theme()` の引数を `bootswatch = "flatly"` の **み**に変更し、
  `preset` との同時指定エラー（起動直後に停止）を解消しました。
- そのほかは前回の修正（CSS パス `www/` 明示、JSON 読み込み tryCatch）を維持しています。
