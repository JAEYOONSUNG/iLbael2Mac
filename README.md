# iLabel2Mac
<img width="5128" height="2830" alt="image" src="https://github.com/user-attachments/assets/d5e5a715-598e-4bdb-a431-95a3d428d587" />

`iLabel2Mac` is a clean-room macOS MVP inspired by the Windows-only `iLabel2` workflow.

Included in this build:

- Native `SwiftUI` desktop app for macOS
- Official `label.kr` format catalog sync pipeline
- Sheet presets plus fully editable custom page and label geometry
- Text, shape, image, QR, and Code128 elements
- CSV merge tokens using `{{Column}}`
- Serial tokens using `{{serial}}`
- Page preview with per-slot merge rendering
- JSON project save/load
- PDF, PNG, and print output for the current page

Not included yet:

- Proprietary `iLabel2` file compatibility
- Excel `.xlsx` import
- Database connectors such as Access
- Printer calibration profiles
- Advanced draw tools, snapping, layers, or resize handles

## Run

```bash
cd /Users/JaeYoon/iLabel2Mac
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run iLabel2Mac
```

## Build App Bundle

```bash
cd /Users/JaeYoon/iLabel2Mac
./scripts/sync_label_formats.py
./scripts/build_app.sh
open dist/iLabel2Mac.app
```

## Sync Official Formats

```bash
cd /Users/JaeYoon/iLabel2Mac
./scripts/sync_label_formats.py
```

The sync script downloads the official `label.kr` format pages and writes `Resources/official_formats.json`.

## Notes

- CSV import accepts comma, tab, semicolon, and pipe-delimited text files.
- Dynamic tokens supported in text, QR, and barcode fields:
  - `{{serial}}`
  - `{{page}}`
  - `{{slot}}`
  - `{{row}}`
- `{{date}}`
- `{{ColumnName}}`
