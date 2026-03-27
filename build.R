
if(!requireNamespace("shinylive",quiet=TRUE)) stop("shinylive required")
ver <- shinylive::assets_version()
shinylive::export(appdir="app", destdir="docs", assets_version=ver,
 template_params=list(title="R言語 × 日本語記事のキュレーション"))
