# Menu import sample

Use **`menu_items_import_sample.csv`** in Excel (File → Open) or Google Sheets, then save as `.xlsx` if you prefer.

## Columns

| Column | Required | Values |
|--------|----------|--------|
| name | Yes | Item name |
| category | Yes | `beverage`, `drink`, `food`, `game` |
| price | Yes | Number (e.g. `60` or `2.50`) |
| unit | Yes | `per_item` or `per_minute` (games use `per_minute`) |
| track_stock | No | `true` / `false` (default: true except games) |
| stock_quantity | No | Integer when tracking stock |
| low_stock_threshold | No | Integer (default `5`) |
| is_active | No | `true` / `false` (default `true`) |

Import in the app: **Settings → Menu Items → Import Excel** (admin only).
