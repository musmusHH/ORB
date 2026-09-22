# Horizon Tactical Session Pro DZ — ORB EA

MT4 Expert Advisor with a dashboard UI matching the HORIZON TACTICAL mockup.
Live session clocks (DST-aware London/NY time) and a live equity curve drawn
from real closed-trade history.

---

## 📦 Installation (MT4)

1. In MetaTrader 4: **File → Open Data Folder → MQL4**
2. Copy files like this:

```
MQL4\
└── Experts\
    ├── Horizon Tactical Session Pro DZ Trader WITH EQUITY CURVE.mq4
    └── HorizonAssets\              ← must sit NEXT TO the .mq4
        └── logo_card.bmp
```

3. Open the `.mq4` in MetaEditor (F4) and press **Compile (F7)**.
   - The BMP assets are embedded into the `.ex4` via `#resource` — after
     compiling, the EA carries its images inside itself.
4. Drag the EA onto a chart, enable **Auto Trading**, keep the input
   `UseCreativeAuroraUI = true` (default).

### What renders live (no image files needed)
- **Session clocks** — hands show real London / New York local time using the
  EA's Auto-DST engine; the green/orange arc marks the actual session window.
  Redrawn every minute via `ResourceCreate` (in-memory bitmap).
- **Equity curve** — built from your actual closed trades (respects the
  `GlobalHistory` / magic-number filter). Blue above starting balance, orange
  below. Redrawn whenever a trade closes.

---

## 🎨 How to add a new image asset

**Step A** — Create a **24-bit BMP** at the exact pixel size you want on screen
and save it into the `HorizonAssets\` folder, e.g. `HorizonAssets\my_icon.bmp`.
(MT4 `#resource` wants BMP, not PNG. 24-bit, no compression.)

**Step B** — Register it at the top of the `.mq4` (next to the logo resource):

```mql4
#resource "HorizonAssets\\my_icon.bmp"
```

**Step C** — Display it inside `AuroraBuild()` using the existing helper:

```mql4
AuroraResBitmap("MyIcon", "my_icon.bmp", x, y, width, height);
```

- `x, y` — pixels from the chart's top-left corner
- `width, height` — must equal the BMP's real dimensions (MT4 crops, it does
  not stretch)

Recompile (F7) — done.

Converting PNG → BMP with ImageMagick:

```
convert my_icon.png -resize 265x86! -type TrueColor -compress None BMP3:HorizonAssets/my_icon.bmp
```

---

## 📁 Repository layout

| Path | Purpose |
|---|---|
| `Horizon Tactical Session Pro DZ Trader WITH EQUITY CURVE.mq4` | The EA |
| `HorizonAssets/` | BMP assets compiled into the EA (add new assets here) |
| `asset_gen/` | High-resolution PNG originals of the generated artwork |
| `mockup.png` | The design mockup the UI is based on |
| `preview_layout.png` | Composite preview of the asset layout |
