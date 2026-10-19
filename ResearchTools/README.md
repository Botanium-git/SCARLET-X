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

## validate_imp_index.py — IMP実行領域の検証

`objc_methods.imp` に実装アドレスでなく `__objc_methlist` の値が混在していたため、**元DBを変更せず** 検証済みSQLiteを新規作成する。

```bash
python3 ResearchTools/validate_imp_index.py \
  --db XServiceLibraries.sqlite \
  --macho XServiceLibraries \
  --binary XServiceLibraries \
  --output XServiceLibraries_validated.sqlite
```

実物検証（2026-10-19）: 25,530 → 18,600件（6,930件除外）。同件数を持つ検証済みDBを別ファイルとして作成済み。対象Mach-Oは *thin 64-bit little-endian* を要求。IMPが実行領域にあることは、呼び出し経路や正しいowner classの証明ではない。

元の `SCARLET_MachO_Indexer` 自体は変更していない。新しい検証ツールで不適切なアドレスを除いた検索用コピーを作る。今後は生成直後の検証を必須とする。


## repair_macho_indexer.py — 元インデクサの再現可能な修正

元の `scarlet_macho_index.py` を残したまま、実行領域外のIMPを生成時に除外する修正版を作成する。

```bash
python3 ResearchTools/repair_macho_indexer.py --original scarlet_macho_index.py --output scarlet_macho_index_repaired.py
python3 scarlet_macho_index_repaired.py build original.ipa -o XServiceLibraries_rebuilt.sqlite --framework XServiceLibraries
```

実物検証: XServiceLibrariesの再走査で18,600件。以前の `XServiceLibraries_validated.sqlite` との `(selector,imp)` 集合の差は0件だった。**修正スクリプトは元インデクサの該当文字列パターンが1回ずつ存在する場合だけ動く**。別版には無理にパッチを当てない。クラス所有者の抽出は未実装。

## extract_class_methods.py — クラスからメソッドを直接引く

公式X v12.25の `XServiceLibraries` のObjective-Cクラス構造（relative method_list_t）を、元のMach-Oから読み取り専用で抽出する研究用ツール。

```bash
python3 ResearchTools/extract_class_methods.py --macho XServiceLibraries --class-address 0x4422590 --expected-class TFNAttributedTextModel
python3 ResearchTools/extract_class_methods.py --macho XServiceLibraries --class-address 0x442A3A8 --expected-class TFNSizeThatFitsHelper
```

入力したクラス名との照合とMach-Oセグメント範囲検証を行う。ポインタ形式・relative method listに関して**この特定のIPAで観測した構成**に依存し、他バージョンでの動作は保証しない。コードは追加済みだが、このGitHub登録版の実行テストは別途必要。検証済みの抽出結果は `Diagnostics/OfficialXClassResolution.md` に保存。

## inspect_text_sizing.py — arm64実命令・スタブ解決

Capstone 5.0.7が必要。thin arm64 Mach-Oを読み取り専用で解析し、unslid VM address指定範囲のバイト・命令・直接branch先を出す。nlistとindirect symbol tableでCスタブ、実命令と__objc_selrefsでObjCスタブのselectorを解決する。今回の32-byte ObjCスタブ、low-36-bit pointer target形式に限定した研究ツールで、任意Mach-Oへの汎用対応や動的dispatch先クラスの保証ではない。

```bash
python3 -m pip install capstone==5.0.7
python3 ResearchTools/inspect_text_sizing.py --macho XServiceLibraries --range 0xc9ed74 0xc9efd4
```

2026-10-19実行済み: 4つの主要関数範囲を全命令デコード、未解決6スタブを解決。extract_class_methods.pyの間接selector誤読も修正し、37+7件を再抽出・IMP実行領域照合。上記の「GitHub登録版の実行テストは別途必要」は、この特定IPA/2クラスについては本検証で更新された。詳細・根拠はDiagnostics/OfficialXTextSizingDisassembly.mdとOfficialXTextSizingEvidence.txtを参照。
