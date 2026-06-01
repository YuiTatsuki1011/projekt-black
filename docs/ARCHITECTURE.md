# Architecture

この文書は、プロジェクトの構造とコードの分け方を説明します。

## 基本方針

このゲームは要素が多いため、最初から巨大な万能スクリプトを作りません。プレイヤー、武器、弾、敵、アイテム、UIなどを分けます。

## ディレクトリ

```text
res://
  scenes/
    player/
    enemies/
    weapons/
    interaction/
    levels/
    ui/
    vfx/
  scripts/
    player/
    enemies/
    core/
    combat/
    ui/
    inventory/
    interaction/
    generation/
  resources/
    weapons/
    enemies/
    items/
    skills/
  assets/
    sprites/
    audio/
    vfx/
    fonts/
  docs/
  tools/
```

## Scenes

`Scene` はGodotで使う「ゲーム内の部品」です。プレイヤー、敵、弾、UI、部屋などをシーンにできます。

- `scenes/player/`: プレイヤー本体と関連部品。
- `scenes/enemies/`: 敵キャラクター。
- `scenes/weapons/`: 銃や近接武器の見た目、発射位置。
- `scenes/interaction/`: ボタン、ドア、アイテムなど、Fキーで操作できる部品。
- `scenes/levels/`: テストマップや部屋。
- `scenes/ui/`: HUD、メニュー、インベントリ画面。
- `scenes/vfx/`: 命中、死亡、煙、火花などの演出。

## Scripts

`Script` はシーンに動きを与えるコードです。

- `scripts/core/`: 共通処理。
- `scripts/player/`: プレイヤーの移動、照準、入力処理。
- `scripts/enemies/`: 敵の移動、攻撃、死亡処理。
- `scripts/combat/`: ダメージ、弾、武器、命中処理。
- `scripts/ui/`: 照準、HUD、メニューなどの表示処理。
- `scripts/inventory/`: アイテム所持、弾薬所持、装備スロット。
- `scripts/interaction/`: ドア、アイテム取得、会話など。
- `scripts/generation/`: ランダムマップ生成。

## Resources

`Resource` はGodotのデータファイルです。武器や敵の数値をコードから分離するために使います。

例:

- 武器名
- ダメージ
- 装弾数
- リロード時間
- 発射間隔
- レアリティ

現在は `resources/weapons/basic_pistol.tres` と `resources/weapons/field_knife.tres` を初期装備データとして使います。

## Autoload

`Autoload` は、どのシーンからでも使える常駐スクリプトです。便利ですが、増やしすぎると依存関係が見えにくくなります。

使う候補:

- `GameState`: 現在のゲーム状態。
- `SaveManager`: セーブとロード。
- `EventBus`: 離れたシステム同士の通知。

最初の縦切りでは、必要になるまでAutoloadを増やしません。

## Collision Layers

`Collision Layer` は「その物体が何者か」、`Collision Mask` は「何に当たるか」を表す設定です。

- Layer 1 `world`: 床、壁。
- Layer 2 `player`: プレイヤー。
- Layer 3 `player_projectile`: プレイヤーの弾。
- Layer 4 `enemy`: 敵。
- Layer 5 `interaction`: Fキーで操作できるボタンなど。

## Combat Feedback

戦闘の反応は、まず仮素材で分かりやすく作ります。

- `Health`: HP管理と、HP変化、被ダメージ、死亡の通知。
- `Projectile`: 命中した相手の `Health` を探してダメージを与える。
- `PlayerController`: 移動、照準、射撃、近接攻撃、ステップ、スタミナを扱う。
- 敵スクリプト: 命中時の点滅、ノックバック、VFX生成、死亡処理を担当する。
- `BurstVfx`: 仮の赤い破片演出。正式な血液スプライトに差し替える前の確認用。

## Player Combat Actions

プレイヤーの攻撃手段は、いまは銃と近接攻撃の2つです。

- 銃: マウス照準へ撃つ。装備中の銃データからダメージ、装弾数、リロード時間、対応弾薬を読む。
- 近接攻撃: Eキーで発動する。装備中の近接武器データからコンボ威力、スタミナ消費、踏み込み時間を読む。
- ステップ: Shiftキーで発動する。短距離移動と短時間無敵を持つが、地上でしか使えない。

スタミナはプレイヤー側の資源です。3回ナイフを振ると0になり、最大まで戻るまで近接攻撃できません。

## Equipment

`Equipment` は、プレイヤーが今なにを装備しているかを持つ部品です。
現在はプレイヤーの `Equipment` ノードに、銃スロット `ranged_weapon` と近接武器スロット `melee_weapon` があります。

- 銃スロット: 初期値は `basic_pistol.tres`。
- 近接武器スロット: 初期値は `field_knife.tres`。
- `PlayerController` は起動時と装備変更時に、装備データを読み込んで射撃と近接攻撃の数値へ反映します。

これにより、あとで武器ドロップ、装備変更UI、ランダム性能、レアリティを追加しやすくします。

## Inventory

`Inventory` は、アイテムID、所持数、グリッド上の配置を記録する部品です。
現在はプレイヤーの `Inventory` ノードで10x6マスのグリッドを管理し、`pistol_ammo` を2x1マスのアイテムとして配置します。
リロード時はグリッド上の `pistol_ammo` から弾薬を消費します。

- `get_quantity(item_id)`: 指定アイテムの所持数を返す。
- `add_item(item_id, quantity)`: アイテムを増やす。
- `remove_item(item_id, quantity)`: 持っている分だけ減らし、実際に減らせた数を返す。
- `move_entry(entry_id, position)`: グリッド上のアイテムを移動する。
- `can_place(entry_id, position)`: 指定位置に置けるかを確認する。

`InventoryScreen` はTabキーで開くUIです。グリッドの描画とドラッグ移動を担当し、実際の配置判定は `Inventory` に任せます。
今は弾薬だけに使っていますが、同じ入口を回復アイテム、素材、クエスト品へ広げられます。
インベントリ枠外へドラッグして離したアイテムは `DroppedItem` としてマップへ生成され、Fキーで拾い直せます。

## Enemy Melee Attacks

接近敵の近接攻撃は、範囲予兆を表示しません。敵自身の停止、構え、攻撃、硬直で読み取れるようにします。

- `CHASE`: プレイヤーへ近づく。
- `WINDUP`: 一瞬止まり、構える。
- `ACTIVE`: 短い攻撃判定を出す。
- `RECOVERY`: 攻撃後に硬直する。

遠距離攻撃やAOEは、将来的に弾道や範囲表示を出せる設計にします。
