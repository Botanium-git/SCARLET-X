# 開発経過ログ

> このファイルは**意図・変更・ビルド・実機結果の時系列**。現在の作業は [ACTIVE_WORK](ACTIVE_WORK.md) を最初に確認する。

## 2026-11-09 — 日常利用優先への切替と引き継ぎ改善
- ユーザーが製品の原点を明示: iPhone 15の公式Xでいいね/リポストが機能しない。Scarlet Xを日常用に使いたい。
- 作業優先を一時的にホーム/DM・いいね/リポストの基本機能へ移す。文字表示計算の原作再現は一時停止で成果保持。
- `START_HERE.md`、`FEATURE_MAP.md`、`ACTIVE_WORK.md`を引き継ぎ入口とする。旧資料は維持。
- v1.4.171 build 353: `Browser/BrowserViewController.m`に共通WKWebViewの下側でホーム/DMの48pt切替バーを追加。URLは`https://x.com/home`と`https://x.com/messages`。commit `57680ad75`、版更新 `23cde07d9`。**実機検証前、ネイティブDM通信・独立タイムラインは未実装**。
- 引き継ぎ入口 `START_HERE.md`、機能一覧、ACTIVE_WORK、CHANGELOGを作成。README先頭に入口を追加。既存の設計方針・SXP解析は削除していない。
- Actionsは最新HEADの結果を参照。実機検証はユーザーのiPhone 15上で別途必要。

## 2026-11-04 — プロフィールBio v1.4.170
- `UI/NativeProfilePolish230.m`のXL/XXL/XXXLフォントサイズを実測値に合わせた。**原作の計算式は未移植**。ビルドSuccessと実機成功は別。
- Bio/文字式解析はSXP [ANALYSIS_RECORD](https://github.com/Botanium-git/SCARLET-X-Probe/blob/develop/ANALYSIS_RECORD.md)に記録。
