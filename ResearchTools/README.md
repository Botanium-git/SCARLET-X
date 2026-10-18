# ResearchTools — アプリから独立した解析用プログラム

このフォルダは **Scarlet Xアプリのコードではない**。Theos Makefileのビルド対象には含めず、GitHub ActionsのIPA作成からも切り離す。

## macho_db_search.py

既存の `scarlet_macho.sqlite` を読み取り専用で検索する。Python 3標準ライブラリのみ必要。バイナリ・IPAやSQLiteを書き換えない。

```bash
python3 ResearchTools/macho_db_search.py --db /path/to/scarlet_macho.sqlite --query TFNAttributedTextModel
python3 ResearchTools/macho_db_search.py --db /path/to/scarlet_macho.sqlite --table objc_methods --query sizeThatFits --binary T1Twitter
python3 ResearchTools/macho_db_search.py --db /path/to/scarlet_macho.sqlite --query _t1_attributedTextModelForStatusViewModel --json
```

- `--table`: `all`（既定）/ `objc_methods` / `symbols` / `functions` / `strings` / `imports`
- `--query`: SQLではなく**文字列の部分一致**。LIKEのワイルドカードはエスケープ
- `--binary`: 任意の対象バイナリ名
- `--limit`: 全テーブル合計、1〜1000（既定40）
- `--json`: JSON Lines出力。数値アドレスに `*_hex` も追加

## 既存インデクサの位置付け

過去に提供された `SCARLET_MachO_Indexer(1).zip` には `scarlet_macho_index.py` とREADMEが同梱されている。新CLIは**既存DBを検索するもの**で、全IPA自動解析や関数逆アセンブル機能を新たに実装したわけではない。

現在のDBは `T1Twitter` と `XAppLibraries` の2バイナリだけを収録している。発見済みの `XServiceLibraries` を調べるには、そのバイナリを既存インデクサで追加解析するか、拡張版インデクサを検証する必要がある。

## 調査結果の保存

- 入口: [Diagnostics/README.md](../Diagnostics/README.md)
- 証拠台帳: [Diagnostics/OfficialXFindingsLedger.md](../Diagnostics/OfficialXFindingsLedger.md)
- 不明な項目を憶測で確定せず、SQL/逆アセンブル/実機ログで出典を残す。
