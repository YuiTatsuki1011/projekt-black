# Item Authoring

この文書は、アイテム追加と性能調整の手順です。

## 基本

アイテムは `resources/items/` の `.tres` ファイルで管理します。
GodotエディタのFileSystemから `.tres` をクリックすると、Inspectorで名前、サイズ、色、スタック数、武器データ参照を編集できます。

現在の主なアイテム:

- `resources/items/pistol_ammo.tres`: 拳銃弾
- `resources/items/basic_pistol.tres`: 初期拳銃アイテム
- `resources/items/heavy_pistol.tres`: 重い拳銃アイテム
- `resources/items/field_knife.tres`: 初期ナイフアイテム

## アイテム表示を変える

`resources/items/*.tres` を編集します。

- `display_name`: 詳細パネルに出る正式名。
- `short_name`: グリッド内やドロップ表示に出る短い名前。
- `size`: インベントリの占有マス。例: `Vector2i(2, 1)` は横2、縦1。
- `stackable`: 1枠に複数個をまとめられるか。
- `max_stack`: 1枠に入る最大数。
- `color`: 仮表示の色。
- `item_type`: `item` / `ranged_weapon` / `melee_weapon`。
- `weapon_resource`: 武器アイテムの場合、対応する `resources/weapons/*.tres`。

## 武器性能を変える

武器の性能は `resources/weapons/` の `.tres` ファイルで編集します。

- 銃: `damage`, `magazine_size`, `reload_time`, `fire_cooldown`, `recoil_amount` など。
- 近接武器: `combo_damages`, `stamina_cost`, `min_stamina_to_use`, `lunge_speed` など。

インベントリ上の見た目やサイズは `resources/items/`、攻撃性能は `resources/weapons/` と考えると分かりやすいです。

## 新しい武器アイテムを追加する

1. `resources/weapons/` で既存武器 `.tres` を複製します。
2. 複製した武器Resourceの `weapon_id` と性能を編集します。
3. `resources/items/` で既存の武器アイテム `.tres` を複製します。
4. 複製したアイテムResourceの `item_id` を、武器Resourceの `weapon_id` と同じ値にします。
5. `display_name`, `short_name`, `size`, `color`, `item_type` を編集します。
6. `weapon_resource` に、手順1で作った武器Resourceを指定します。

重要: 武器Resourceの `weapon_id` と、アイテムResourceの `item_id` は同じにしてください。
装備を外してインベントリに戻す時、このIDで対応するアイテムを探します。

## 新しい通常アイテムを追加する

1. `resources/items/pistol_ammo.tres` などを複製します。
2. `item_id` を一意の名前にします。
3. `display_name`, `short_name`, `size`, `stackable`, `max_stack`, `color` を編集します。
4. `item_type` は `item` にします。
5. `weapon_resource` は空のままにします。

`resources/items/` に置かれた `.tres` は起動時に自動で読み込まれます。
