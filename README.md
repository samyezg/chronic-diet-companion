# Chronic Disease Diet Companion（慢病餐伴侣）

Flutter source slice for a multi-disease meal companion: photo / text meal logging with rule-based red–yellow–green advice for gout, diabetes, and hypertension (heart-care).

This repository is a **core Dart + rule-engine sample for architecture review**. It is **not** a complete store-ready project.

**Not medical advice.** For dietary reference only; consult a clinician for clinical decisions.

## Scope

| | |
|:---|:---|
| **Included** | `lib/` (Flutter/Dart client), `engine/` (Python rule engine + JSON rule/food bases), `pubspec.yaml` |
| **Not included** | `android/`, `ios/`, cloud-function deploy tree, signing materials, store listing configs |
| **Store build** | Not produced from this repo alone (native projects omitted) |
| **API key** | Vision / LLM keys are supplied at runtime by the operator; **no hardcoded keys** in the repo |
| **SDK** | See `pubspec.yaml` (`^3.12.2`) |

## Features

- **Multi-disease modes** — gout (purine), diabetes (carb / GI), hypertension / heart-care (cholesterol primary; sodium qualitative)
- **Meal recognition client** — submit image / poll status / show result (vision backend outside this slice)
- **Manual text fallback** — type a dish name when camera recognition is unavailable
- **Red / yellow / green engine** — JSON rule bases + dish mapping; overall light is not forced green when unevaluated
- **Daily budget view** — intake vs disease-specific daily limits
- **Brand shell** — umbrella brand + per-disease sub-brand copy and theme

## Tech stack

- Flutter / Dart (`http`, `image_picker`, `image`, `shared_preferences`)
- Python rule engine (`engine/engine.py`) with JSON rules and food tables
- Backend vision / advice APIs are **not** packaged here (client talks to a configurable base URL)

## Layout

```
lib/
├── main.dart
├── api/          # HTTP client (recognize / advice / daily / nutrition)
├── models/
├── pages/        # home, recognize, result, manual input, daily, about, gate check
├── state/
└── theme/        # brand + shared copy

engine/
├── engine.py                 # gout / diabetes / hypertension engines
├── *_rules.json              # traffic-light rule bases
├── food_*.json               # nutrition lookup tables
├── vision_dish_mapping*.json # dish name mappings
└── _gen_*.py                 # rule-base generation helpers (optional)
```

## Disclaimer

See in-app about / gate copy and `LICENSE`. Traffic-light labels and AI dish guesses are references only—not diagnosis or treatment advice.

## License

See [`LICENSE`](./LICENSE) (**All Rights Reserved**).

Copyright (c) 2026 Chronic Disease Diet Companion / 慢病餐伴侣. All rights reserved.
