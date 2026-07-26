# Publishing hf.app

Two independent distribution paths. The first is a direct/OSS download; the second
is the Mac App Store. They use *different* Apple certificates.

---

## 1. Developer-ID notarized DMG  (direct download / OSS)  — **nearly done**

Workflow: `.github/workflows/release.yml` — on a `v*` tag it builds (SwiftPM) →
bundles `HFMac.app` → Developer-ID signs (hardened runtime + our sandbox
entitlements) → **notarizes + staples** → makes a DMG → cuts a GitHub Release.

**Secrets (7). 5 are already set** from `entheai/.env`:

| secret | status | source |
|---|---|---|
| `MACOS_CERTIFICATE` (base64 Developer-ID `.p12`) | ✅ set | `.env MACOS_CERTIFICATE_SECRET` |
| `MACOS_CERTIFICATE_PWD` | ✅ set | `.env` |
| `MACOS_SIGN_IDENTITY` | ✅ set | `.env` |
| `NOTARY_KEY` (base64 App Store Connect `.p8`) | ✅ set | `.env MACOS_NOTARY_KEY` |
| `KEYCHAIN_PWD` | ✅ set | generated |
| **`NOTARY_KEY_ID`** | ⛔ **add it** | your ASC API key's Key ID |
| **`NOTARY_ISSUER_ID`** | ⛔ **add it** | ASC → Users & Access → Integrations → Issuer ID |

> These two live in **entheai's** GitHub secrets already (the same `.p8`), but
> secret *values* can't be read across repos. Copy them, or grab from App Store
> Connect. Then:

```bash
gh secret set NOTARY_KEY_ID    --repo peterlodri-sec/hf-mac
gh secret set NOTARY_ISSUER_ID --repo peterlodri-sec/hf-mac
git tag v0.1.0 && git push --tags     # → notarized DMG on Releases
```

---

## 2. Mac App Store  — a separate, bigger track

MAS needs *different* certs than Developer-ID, plus an app record. The app is
already **sandboxed** (`Packaging/hf-mac.entitlements`: app-sandbox +
network.client — enough for the HF API and Osaurus on localhost), so the code is
MAS-ready. What's still required (yours to create — none of this is in `.env`):

1. **App Store Connect app record** — bundle id **`dev.peterl.hfmac`**, category
   Developer Tools.
2. **Certs:** *Apple Distribution* (signs the `.app`) + *Mac Installer
   Distribution* (signs the `.pkg`).
3. **Provisioning profile:** a Mac App Store profile for the bundle id, embedded
   at `Contents/embedded.provisionprofile`.
4. Build → sign → **`productbuild`** a `.pkg` → upload with **`xcrun altool
   --upload-app`** / Transporter. Scaffold: `.github/workflows/mas.yml`.

**Recommendation:** MAS is cleanest from an **Xcode project** (it embeds the
provisioning profile and handles the archive/upload). The SwiftPM setup here is
ideal for the Developer-ID DMG + OSS; for MAS, wrap it in a thin Xcode app target
pointing at the same `Sources/`. I can generate that when the app record exists.

🜂 *ahogy lennie kell* — ship the honest DMG now; the store when the record's live.
