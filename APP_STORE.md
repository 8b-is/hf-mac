# App Store Connect · Xcode Cloud · Blacksmith

Operational guide for shipping **hf.app** to the Mac App Store (via Xcode Cloud)
and cutting the notarized OSS DMG faster (via Blacksmith runners). The higher-level
"two distribution paths" overview lives in [`PUBLISHING.md`](PUBLISHING.md); this is
the step-by-step.

## Who builds what

| Path | Runner | Signing | Output | For |
|---|---|---|---|---|
| **Developer-ID DMG** | Blacksmith GH Actions — [`release.yml`](.github/workflows/release.yml) | Developer ID + notarytool | notarized `.dmg` on GitHub Releases | OSS / direct download |
| **Mac App Store** | **Xcode Cloud** | Apple-managed (cloud) | TestFlight → App Store | store distribution |
| _MAS (alt)_ | Blacksmith GH Actions — [`mas.yml`](.github/workflows/mas.yml) | Apple Distribution + Installer | `.pkg` upload | self-hosted fallback to Xcode Cloud |

The app is one codebase two ways: **SwiftPM** (`Package.swift`) drives the DMG build;
an **Xcode project** generated from [`project.yml`](project.yml) drives Xcode Cloud
(the store wants a real `.xcodeproj` + shared scheme). Both compile the *same*
`Sources/HFMac`. The `.xcodeproj` is git-ignored — `project.yml` is the source of truth.

Bundle id: **`dev.peterl.hfmac`** · Category: Developer Tools · min macOS 14.0 · sandboxed.

---

## A · App Store Connect (one-time)

Prerequisites: an **Apple Developer Program** membership (the org or your individual
account) and all Agreements/Tax/Banking accepted in ASC — a "Paid Apps" or "Free Apps"
agreement in *Pending* state silently blocks submission.

> **Status (checked via ASC API 2026-07-26):** the **Identifier** `dev.peterl.hfmac` is
> ✅ registered (Team **`7CFQYBX575`**, UNIVERSAL) — step 1 done. The **app record**
> (step 2) is ⛔ **not created yet**; that's the one remaining store gate. Steps 1 and 2
> are different things — the Identifier lives in developer.apple.com, the app record in
> appstoreconnect.apple.com → Apps.

1. **Register the App ID.** [developer.apple.com](https://developer.apple.com/account) →
   Certificates, IDs & Profiles → Identifiers → **+** → App ID → App → Bundle ID
   **explicit** `dev.peterl.hfmac`. Capabilities: App Sandbox needs no toggle here
   (it's an entitlement, already in `Packaging/hf-mac.entitlements`); the outgoing-network
   entitlement needs nothing registered.
2. **Create the app record.** [App Store Connect](https://appstoreconnect.apple.com) →
   Apps → **+** → New App → Platform **macOS**, Name **hf.app**, Primary language,
   Bundle ID `dev.peterl.hfmac`, SKU (any stable string, e.g. `hfmac`). Set the primary
   category to **Developer Tools**.
3. **App Store Connect API key** (used by notarytool for the DMG *and* by CI uploads).
   ASC → Users and Access → **Integrations** → App Store Connect API → **Generate API Key**
   (Access: *Developer* is enough to upload; *App Manager* to also edit metadata). Then:
   - **Key ID** → the release secret `NOTARY_KEY_ID`
   - **Issuer ID** (top of the same page) → `NOTARY_ISSUER_ID`
   - the downloaded **`AuthKey_XXXX.p8`** (base64) → `NOTARY_KEY`

   > These three already exist in `entheai`'s secrets from the same key and are set on
   > `8b-is/hf-mac` (`NOTARY_KEY_ID` / `NOTARY_ISSUER_ID` came from `entheai/.env`'s
   > `MACOS_KEY_ID` / `MACOS_ISSUER_ID`). Same `.p8` works for both notarization and ASC.

Only step 2 (the app record) gates the store — until it exists, Xcode Cloud has nothing
to upload to.

---

## B · Xcode Cloud (the Mac App Store path)

Xcode Cloud is Apple-native CI: it does **cloud-managed signing** (no cert/profile
wrangling), archives, and hands builds straight to TestFlight / App Store. That's why
it's the recommended store path over the `mas.yml` scaffold.

### Already wired in this repo
- **[`project.yml`](project.yml)** — XcodeGen spec: macOS app target `HFMac`, `Sources/HFMac`,
  our `Packaging/Info.plist` + entitlements, bundle id `dev.peterl.hfmac`, a **shared** scheme
  named `HFMac`.
- **[`ci_scripts/ci_post_clone.sh`](ci_scripts/ci_post_clone.sh)** — runs first on every
  Xcode Cloud build: `brew install xcodegen` + `xcodegen generate` (the `.xcodeproj` is
  git-ignored, so it's regenerated in the cloud).
- **[`ci_scripts/ci_pre_xcodebuild.sh`](ci_scripts/ci_pre_xcodebuild.sh)** — stamps
  `CFBundleVersion = $CI_BUILD_NUMBER` so every upload has a unique build number.

### Set it up (once)
1. **Generate + open locally** so Xcode can see the shared scheme:
   ```bash
   brew install xcodegen           # if needed
   xcodegen generate
   open HFMac.xcodeproj
   ```
2. In Xcode: **Product → Xcode Cloud → Create Workflow**. Pick the **`HFMac`** scheme.
3. **Grant repo access.** Xcode Cloud will prompt to install its GitHub App on **`8b-is`**
   and authorize **`8b-is/hf-mac`** (org owner approval may be needed).
4. **Configure the workflow:**
   - **Environment:** latest Xcode, macOS.
   - **Start condition:** tag `v*` (matches the DMG release) or branch `main`.
   - **Actions:** **Archive** — Platform **macOS**, scheme `HFMac`, Release config.
   - **Post-action:** TestFlight (Internal Testing) and/or App Store Connect.
5. **Signing:** choose **"Xcode Cloud managed"** signing. It provisions the *Apple
   Distribution* cert + Mac App Store profile automatically — this is the win over the
   manual `mas.yml` certs. `DEVELOPMENT_TEAM` is injected from the ASC context, so it's
   intentionally unset in `project.yml`.
6. **Run.** First build: clone → `ci_post_clone.sh` (generate project) →
   `ci_pre_xcodebuild.sh` (stamp build #) → archive → upload. It appears under
   TestFlight / the app's Activity in ASC.

### Local archive check (optional, needs your signing set)
```bash
xcodegen generate
xcodebuild -project HFMac.xcodeproj -scheme HFMac -configuration Release \
  -destination 'generic/platform=macOS' archive \
  -archivePath build/HFMac.xcarchive DEVELOPMENT_TEAM=7CFQYBX575   # your Apple Team ID
```
> Unsigned compile sanity check (no team needed):
> `xcodebuild -project HFMac.xcodeproj -scheme HFMac build CODE_SIGNING_ALLOWED=NO`
> — this is the exact command used to verify `project.yml` (BUILD SUCCEEDED).

---

## C · Blacksmith (faster GitHub Actions for the DMG)

[Blacksmith](https://blacksmith.sh) is a drop-in GitHub Actions runner fleet — ~2× faster
at ~half the cost, selected purely by the `runs-on` label. Their macOS runners are
**Apple Silicon (M4)**, which is native for our `--arch arm64` build.

### Already changed
`release.yml` and `mas.yml` now use:
```yaml
runs-on: blacksmith-6vcpu-macos-15
```
Pinned macOS-15 image (also available: `blacksmith-6vcpu-macos-26`; sizes run 2–32 vCPU).

### Turn it on (once)
1. Install the **Blacksmith GitHub App** on the **`8b-is`** org: [blacksmith.sh](https://blacksmith.sh)
   → sign in with GitHub → add the org → authorize **`hf-mac`**.
2. That's it — the next tag push routes to Blacksmith hardware. Nothing else in the
   workflow changes; all 7 release secrets stay as-is.

> **Fallback:** if the app isn't installed yet, a `blacksmith-*` job just queues with no
> runner. To ship immediately without Blacksmith, revert the two `runs-on:` lines to
> `macos-15` — the workflows are otherwise identical.

---

## The honest state

- ✅ **DMG path** is complete: tag `v*` → notarized DMG on Releases (on Blacksmith once the
  org app is installed, else swap back to `macos-15`).
- ✅ **Xcode project + Xcode Cloud scripts** are in the repo and the project is verified to
  **build** (`xcodebuild … BUILD SUCCEEDED`).
- ⛔ **Store submission** needs *you*: the ASC **app record** (§A.2) and, once, granting
  **Xcode Cloud** + **Blacksmith** their GitHub App access to `8b-is/hf-mac`. None of that
  can be scripted from here — it's account-owner clicks.

🜂 *ahogy lennie kell* — the project builds today; the store opens the moment the record's live.

Sources for the Blacksmith runner labels:
[Blacksmith quickstart](https://docs.blacksmith.sh/introduction/quickstart) ·
[ARM/x86/macOS support](https://info.blacksmith.sh/task/blog/github-actions-runner-providers-arm-x86-support)
