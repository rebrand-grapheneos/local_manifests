# rebrand-grapheneos

A sample/educational project demonstrating how to maintain a customized Android OS based on [GrapheneOS](https://grapheneos.org/) using a set of custom tools.

## What Is This?

Android OS source trees are 100+ GB. Forking entire repositories to GitHub is impractical without LFS. This project solves that problem with a **git2** system that tracks only modified files as a lightweight overlay on top of upstream repositories, combined with Android's **local_manifests** mechanism to seamlessly integrate custom changes into the build.

This is a complete, working example of:

- Managing large-scale Android OS customization with minimal storage
- Custom branding (boot logo, setup wizard icon)
- Build signing and release generation
- OTA update server deployment
- Multi-device key management

> **Note:** The OTA server (`ota-server`) is provided as a reference implementation. The Updater app (`packages/apps/Updater`) is not modified in this project. When you need to implement custom OTA functionality, use the OTA server as a starting point and modify the Updater app accordingly (see [OTA Server](#ota-server) and [Updater App Configuration](#updater-app-configuration)).

## Architecture Overview

```
GrapheneOS upstream repos (100+ GB)
        |
        v
   repo sync -----------> Full source tree
        |                      |
        |                      v
local_manifests/          .git2/ overlays
 default.xml              (only modified files)
        |                      |
        v                      v
  Override specific       Apply changes on top
  upstream projects       of upstream code
        |                      |
        +----------+-----------+
                   v
            Custom build output
                   |
                   v
         OTA server deployment
```

**Two-layer architecture:**

1. **local_manifests/default.xml** -- Tells `repo sync` to fetch custom repositories instead of upstream for specific projects
2. **git2** -- Within those repositories, tracks only the delta (modified files) versus the upstream tag

## Repository Map

| Repository | Description | Type |
|---|---|---|
| [local_manifests](https://github.com/rebrand-grapheneos/local_manifests) | Setup scripts, manifest, git2 tools (this repo) | Management |
| [script](https://github.com/rebrand-grapheneos/script) | Build and release scripts (key generation, signing) | git2 overlay |
| [platform_frameworks_base](https://github.com/rebrand-grapheneos/platform_frameworks_base) | Framework customizations (boot logo) | git2 overlay |
| [platform_packages_apps_SetupWizard2](https://github.com/rebrand-grapheneos/platform_packages_apps_SetupWizard2) | Setup wizard branding (icon) | git2 overlay |
| [platform_build](https://github.com/rebrand-grapheneos/platform_build) | Build system overrides (placeholder, no changes yet) | git2 overlay |
| [ota-server](https://github.com/rebrand-grapheneos/ota-server) | OTA update server reference implementation (Express.js) | Standalone |

## Supported Devices

Replace `<DEVICE>` in the commands below with your target device codename:

| Codename | Device | Codename | Device |
|---|---|---|---|
| `tokay` | Pixel 9 | `shiba` | Pixel 8 |
| `caiman` | Pixel 9 Pro | `husky` | Pixel 8 Pro |
| `komodo` | Pixel 9 Pro XL | `akita` | Pixel 8a |
| `comet` | Pixel 9 Pro Fold | `panther` | Pixel 7 |
| `tegu` | Pixel 9a | `cheetah` | Pixel 7 Pro |
| `felix` | Pixel Fold | `lynx` | Pixel 7a |
| `tangorpro` | Pixel Tablet | `oriole` | Pixel 6 |
| | | `raven` | Pixel 6 Pro |
| | | `bluejay` | Pixel 6a |

## Quick Start

### Prerequisites

- Linux (Ubuntu 22.04+ recommended)
- [Android build prerequisites](https://source.android.com/docs/setup/start/requirements)
- `repo` tool installed
- Node.js 18+ (for OTA server)
- ~300 GB disk space

### Step 1: Clone and Initialize

```bash
git clone git@github.com:rebrand-grapheneos/local_manifests.git rebrand-grapheneos
cd rebrand-grapheneos
./setup.sh
```

This runs `repo init` with the GrapheneOS manifest and moves the management files into `.repo/local_manifests/`.

### Step 2: Sync Source

```bash
repo sync -j$(nproc)
```

This downloads the full Android source tree (~100 GB). Projects listed in `default.xml` are fetched from the `rebrand-grapheneos` GitHub org instead of upstream.

### Step 3: Apply Custom Changes

```bash
.repo/local_manifests/git2-setup.sh
```

This finds all projects with `.git2config` files and runs `git2 start`, which:
1. Clones the original upstream repo based on `.git2config`
2. Overlays the modified files from the git2 repository

### Step 4: Create Build System Symlinks

```bash
.repo/local_manifests/link-setup.sh
```

This creates symlinks required by the Android build system (`WORKSPACE`, `build/core`, `build/envsetup.sh`, etc.).

### Step 5: Set Up Build Environment

```bash
# Copy signing keys (must be generated first - see Key Generation section)
# Keys should be at keys/<DEVICE>/ relative to workspace root

# Set up vendor tools
cd vendor/adevtool
yarn install
cd ../..

# Initialize build environment
source build/envsetup.sh

# Set build variables
export BUILD_DATETIME=$(date +%s)
export BUILD_NUMBER=$(date +%Y%m%d00)
export OFFICIAL_BUILD=true
```

### Step 6: Build

```bash
# Build SDK tools (required first)
lunch sdk_phone64_x86_64-cur-user
m -j16 arsclib

# Generate vendor files for your device
vendor/adevtool/bin/run generate-all -d <DEVICE>

# Build device images
lunch <DEVICE>-cur-userdebug
m -j16 vendorbootimage vendorkernelbootimage target-files-package

# Build OTA tools
m -j16 otatools-package
```

### Step 7: Finalize and Sign

```bash
# Stage build artifacts
script/finalize.sh

# Sign and generate release (OTA, factory images)
script/generate-release.sh <DEVICE> $BUILD_NUMBER
```

### Step 8: Deploy OTA

```bash
cd ota-server
npm install

# Register the build
npm run deploy -- --device <DEVICE> --version $BUILD_NUMBER --channel alpha

# Start the server
npm start
```

## The git2 System

### Concept

Each modified project contains a `.git2/` directory -- a separate git repository tracking only your changes. The parent project has `.git/` pointing to the full upstream repo. This means:

- You never fork the entire 100+ GB source
- Only changed files are stored in your custom repos
- Upstream updates can be applied cleanly

### Directory Structure

```
frameworks/base/           # Full upstream project (~2 GB)
├── .git/                  # Upstream git history
├── .git2/                 # Your changes only (~50 KB)
│   ├── .git/              # Git repo for your changes
│   ├── .git2config        # Upstream reference (remote, tag, commit)
│   ├── .git2removed       # Deleted files list
│   ├── .find-ignore       # Exclude from Android build system
│   ├── git2.sh            # git2 tool script
│   └── core/res/assets/   # Only the modified files
│       └── images/
│           └── android-logo-mask.png
├── core/
│   └── res/
│       └── assets/
│           └── images/
│               └── android-logo-mask.png  # Modified file (from .git2)
└── ...                    # Thousands of unchanged upstream files
```

### .git2config Format

```ini
# git2 config file
# Created: 2026-02-25T11:17:28+01:00

# remotes (name=url)
REMOTE['origin']='https://github.com/GrapheneOS/platform_frameworks_base.git'

# Current ref info
REF_TYPE='tag'
REF_NAME='2025110800'
REF_REMOTE=''

# HEAD commit
COMMIT='d697c573a824058f1067fc4b317a560d71ce937c'
```

### git2.sh Commands

| Command | Description |
|---|---|
| `git2 init` | Create `.git2/` folder, move `git2.sh` into it, save upstream config |
| `git2 start` | After cloning a git2 repo, reconstruct the full project (clone upstream + apply overlay) |
| `git2 set` | Save current upstream git state (remote, tag/branch/commit) to `.git2config` |
| `git2 get` | Restore upstream git state from `.git2config` (re-init `.git`, fetch, checkout) |
| `git2 push` | Sync changes from working tree to `.git2/` (detects modified/added/deleted files) |
| `git2 pull` | Sync changes from `.git2/` back to working tree |

git2.sh can be run from the project root, from inside `.git2/`, or via full path from any directory.

### git2-all.sh: Batch Operations

Located in `.repo/local_manifests/git2-all.sh`, this runs git2 commands across all projects:

```bash
# Sync all project changes to .git2/ directories
git2-all.sh push

# Sync all .git2/ changes back to projects
git2-all.sh pull

# Git operations in all .git2/ repos
git2-all.sh git status
git2-all.sh git add -A
git2-all.sh git commit -m "Update branding"
git2-all.sh git push

# Revert all project changes (preserves .git2/)
git2-all.sh reset

# Show changed .git2/ repos only
git2-all.sh status

# List all projects with .git2/
git2-all.sh list
```

### git2-setup.sh: Initialization After Sync

After `repo sync`, run `.repo/local_manifests/git2-setup.sh` to apply all git2 overlays. It finds projects with `.git2config` files and runs `git2 start` on each.

### Workflow: Making a New Change

```bash
# 1. Edit files in the project directory
vim frameworks/base/core/res/assets/images/android-logo-mask.png

# 2. Sync changes to .git2/
.repo/local_manifests/git2-all.sh push

# 3. Commit in .git2/ repos
.repo/local_manifests/git2-all.sh git add -A
.repo/local_manifests/git2-all.sh git commit -m "Custom boot logo"
.repo/local_manifests/git2-all.sh git push
```

### Workflow: Updating to a New Upstream Tag

```bash
# 1. Update TAG file
echo "2025120100" > .repo/local_manifests/TAG

# 2. Re-initialize with new tag
repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "refs/tags/2025120100"

# 3. Sync updated source
repo sync -j$(nproc)

# 4. Re-apply git2 overlays
.repo/local_manifests/git2-setup.sh

# 5. Resolve any conflicts, then push
.repo/local_manifests/git2-all.sh push
.repo/local_manifests/git2-all.sh git add -A
.repo/local_manifests/git2-all.sh git commit -m "Update to 2025120100"
.repo/local_manifests/git2-all.sh git push
```

### Workflow: Adding a New Project

```bash
# 1. Navigate to the upstream project in your repo workspace
cd packages/apps/SomeApp

# 2. Copy git2.sh to the project root
cp /path/to/git2.sh .

# 3. Initialize git2 (creates .git2/, moves git2.sh, saves config)
./git2.sh init

# 4. Make your changes
vim res/values/config.xml

# 5. Push changes to .git2/
.git2/git2.sh push

# 6. Initialize git repo in .git2/ and push to GitHub
cd .git2
git init
git remote add origin git@github.com:rebrand-grapheneos/platform_packages_apps_SomeApp.git
git add -A
git commit -m "init: git2 project"
git push -u origin main

# 7. Add to default.xml
# Add <remove-project> and <project> entries for the new project
```

## local_manifests and the Android Repo Tool

### How default.xml Works

The file `.repo/local_manifests/default.xml` overrides specific upstream projects:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="rebrand-grapheneos" fetch="git@github.com:rebrand-grapheneos/" />

  <remove-project name="platform_frameworks_base" />
  <project path="frameworks/base" name="platform_frameworks_base"
           remote="rebrand-grapheneos" revision="16"/>

  <!-- More project overrides... -->
</manifest>
```

- `<remote>` defines the GitHub organization as a fetch source
- `<remove-project>` removes the upstream project from the manifest
- `<project>` adds your custom repository in its place
- `revision="16"` refers to the branch on your custom repo

### Adding a New Project Override

1. Add `<remove-project>` and `<project>` entries to `default.xml`
2. Create the GitHub repository under the org
3. Push the git2 content to the repo
4. Run `repo sync` to verify

### make-repo.sh: Generating the Manifest

Automatically generates `default.xml` from discovered `.git2/` projects:

```bash
.repo/local_manifests/make-repo.sh 2025110800
```

This scans all projects with `.git2/`, maps paths to project names, extracts commit hashes, and generates the XML.

## Logo and Icon Asset Creation

### android-logo-mask.png (Boot Animation Logo)

Located at `frameworks/base/core/res/assets/images/android-logo-mask.png`.

**Specifications:**

- Format: PNG with alpha channel
- Background: Black (#000000)
- Foreground: Transparent (alpha channel cuts out the logo shape)
- Size: Must match the original file dimensions exactly
- The transparent area defines the visible logo shape during boot

**How to create:**

1. Design your logo in any image editor (Photoshop, GIMP, Inkscape)
2. Create a new image matching the original dimensions
3. Fill the entire image with black (#000000)
4. Cut out your logo shape (make it fully transparent)
5. Export as PNG with alpha channel preserved

### grapheneos_icon.xml (Setup Wizard Icon)

Located at `packages/apps/SetupWizard2/res/drawable/grapheneos_icon.xml`.

**Format:** Android Vector Drawable XML with 2000x2000dp viewport.

**How to create:**

1. Design your icon as an SVG file
2. Convert to Android Vector Drawable XML using [svg2vector.com](https://svg2vector.com/)
3. Test the output by converting XML to PNG at [coolutils.com](https://www.coolutils.com/online/XML-to-PNG)
4. Place the file at `res/drawable/grapheneos_icon.xml`

**Example structure:**

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="2000dp"
    android:height="2000dp"
    android:viewportWidth="2000"
    android:viewportHeight="2000">
  <path
      android:fillColor="#000000"
      android:fillAlpha="0.988"
      android:pathData="M..."/>
</vector>
```

## Key Generation and Management

### Generating Keys

Run from the workspace root (requires AOSP build tools):

```bash
script/generate-keys
```

This generates signing keys for all supported devices. Each device gets its own key directory under `keys/<DEVICE>/`.

**Keys generated per device:**

| Key | Purpose |
|---|---|
| `releasekey` | General APK signing |
| `platform` | Platform-level apps |
| `shared` | Shared UID apps |
| `media` | Media framework apps |
| `networkstack` | Network stack module |
| `bluetooth` | Bluetooth module |
| `sdk_sandbox` | SDK sandbox |
| `gmscompat_lib` | GMS compatibility library |
| `avb.pem` | Android Verified Boot key (RSA 4096-bit, scrypt-encrypted) |
| `avb_pkmd.bin` | AVB public key metadata |

**Directory structure after generation:**

```
keys/
├── <DEVICE>/
│   ├── releasekey.pk8
│   ├── releasekey.x509.pem
│   ├── platform.pk8
│   ├── platform.x509.pem
│   ├── shared.pk8
│   ├── shared.x509.pem
│   ├── media.pk8
│   ├── media.x509.pem
│   ├── networkstack.pk8
│   ├── networkstack.x509.pem
│   ├── bluetooth.pk8
│   ├── bluetooth.x509.pem
│   ├── sdk_sandbox.pk8
│   ├── sdk_sandbox.x509.pem
│   ├── gmscompat_lib.pk8
│   ├── gmscompat_lib.x509.pem
│   ├── avb.pem
│   └── avb_pkmd.bin
├── <DEVICE>/
│   └── ...
└── ...
```

### Key Security

- Keys are encrypted with scrypt for storage
- `script/decrypt-keys <dir>` decrypts keys to a directory (use `/dev/shm/` tmpfs for security)
- `script/encrypt-keys <dir>` re-encrypts keys
- The CN (Common Name) is set to `GrapheneOS` by default -- change it to your project name in `generate-keys`
- **Never commit unencrypted keys to git**

## Build and Release Workflow

### Complete Build Pipeline

Replace `<DEVICE>` with your target device codename (e.g., `cheetah`, `tokay`). See [Supported Devices](#supported-devices) for the full list.

```bash
# 1. Set up environment
source build/envsetup.sh
export BUILD_DATETIME=$(date +%s)
export BUILD_NUMBER=$(date +%Y%m%d00)
export OFFICIAL_BUILD=true

# 2. Build SDK tools (required once)
lunch sdk_phone64_x86_64-cur-user
m -j16 arsclib

# 3. Generate vendor files for your device
vendor/adevtool/bin/run generate-all -d <DEVICE>

# 4. Build device images
lunch <DEVICE>-cur-userdebug
m -j16 vendorbootimage vendorkernelbootimage target-files-package

# 5. Build OTA tools
m -j16 otatools-package

# 6. Stage artifacts
script/finalize.sh

# 7. Sign and package
script/generate-release.sh <DEVICE> $BUILD_NUMBER
```

### generate-release.sh: Signing and Packaging

This script performs the complete release process:

1. Decrypts signing keys to tmpfs (`/dev/shm/`) for security
2. Unpacks `otatools.zip` from the build
3. Signs all APKs and APEX packages with custom keys (169+ packages)
4. Generates signed OTA update zip with `--skip_compatibility_check`
5. Creates factory images
6. Creates install bundles
7. Cleans up decrypted keys

**The `--skip_compatibility_check` flag** is necessary when building a rebranded OS. Without it, `ota_from_target_files` fails because the OS fingerprint doesn't match the original GrapheneOS fingerprint.

**Output structure:**

```
releases/
└── <BUILD_NUMBER>/
    └── release-<DEVICE>-<BUILD_NUMBER>/
        ├── <DEVICE>-ota_update-<BUILD_NUMBER>.zip
        ├── <DEVICE>-img-<BUILD_NUMBER>.zip
        ├── <DEVICE>-install-<BUILD_NUMBER>.zip
        └── <DEVICE>-install-<BUILD_NUMBER>.zip.sig
```

## OTA Server

> **Note:** The OTA server is provided as a **reference implementation** for delivering updates. The Updater app is not modified in this project. When implementing custom OTA functionality, you will need to modify both the OTA server and the Updater app to match your infrastructure. See [Updater App Configuration](#updater-app-configuration) for the required changes.

### Setup

```bash
cd ota-server
npm install
npm start        # Production (port 80)
npm run dev      # Development (auto-reload)
```

### API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/api/health` | GET | Health check |
| `/api/devices` | GET | List registered devices from metadata |
| `/api/ota/<DEVICE>-<CHANNEL>` | GET | Serve metadata for Updater app |
| `/api/ota/<FILENAME>` | GET | Serve OTA files (.zip, .sig) |

### Deploying Updates

```bash
# Register a new build for a device+channel
npm run deploy -- --device <DEVICE> --version <BUILD_NUMBER> --channel <CHANNEL>

# Delete a device+channel registration
npm run deploy -- delete <DEVICE> <CHANNEL>

# Promote all devices from one channel to another
npm run deploy -- move <FROM_CHANNEL> <TO_CHANNEL>
```

**Examples:**

```bash
# Deploy cheetah (Pixel 7 Pro) to alpha channel
npm run deploy -- --device cheetah --version 2025110800 --channel alpha

# Deploy tokay (Pixel 9) to testing channel
npm run deploy -- --device tokay --version 2025110800 --channel testing

# Promote all devices from alpha to beta
npm run deploy -- move alpha beta

# Promote all devices from beta to stable
npm run deploy -- move beta stable

# Remove cheetah from testing
npm run deploy -- delete cheetah testing
```

### Channel System

| Channel | Purpose |
|---|---|
| `testing` | Internal testing |
| `alpha` | Early access |
| `beta` | Pre-release |
| `stable` | Production |

Each channel also has a `-security-preview` variant (e.g., `stable-security-preview`).

**Typical promotion flow:** `testing` -> `alpha` -> `beta` -> `stable`

### Updater App Configuration

> **Not implemented in this project.** The following describes the changes required when you implement custom OTA delivery. These modifications would be made to the `packages/apps/Updater` project using the git2 system.

To use a custom OTA server, you need to:

1. Add `packages/apps/Updater` as a new git2 project (see [Workflow: Adding a New Project](#workflow-adding-a-new-project))
2. Modify the following files:

**`packages/apps/Updater/res/values/config.xml`** -- Change the OTA URL:

```xml
<string name="url">https://your-server.example.com/api/ota/</string>
<string name="channel_default">stable</string>
```

**`packages/apps/Updater/res/xml/network_security_config.xml`** -- Update certificate pinning:

```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="false"/>
    <domain-config>
        <domain includeSubdomains="false">your-server.example.com</domain>
        <pin-set expiration="2026-01-01">
            <pin digest="SHA-256">YOUR_CERTIFICATE_PIN_HERE</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

Generate your certificate pin:

```bash
openssl s_client -connect your-server.example.com:443 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

3. Add `platform_packages_apps_Updater` to `default.xml`
4. Rebuild and the Updater app will connect to your OTA server

### Directory Structure

```
ota-server/
├── server.js          # Express.js server
├── deploy.js          # Deployment CLI
├── package.json
├── .gitignore         # Ignores node_modules/, files/, metadata/
├── files/             # OTA zip and sig files (created by deploy)
│   ├── <DEVICE>-ota_update-<BUILD_NUMBER>.zip
│   ├── <DEVICE>-install-<BUILD_NUMBER>.zip
│   └── <DEVICE>-install-<BUILD_NUMBER>.zip.sig
└── metadata/          # Channel metadata (created by deploy)
    ├── <DEVICE>-<CHANNEL>
    ├── <DEVICE>-<CHANNEL>-security-preview
    └── ...
```

**Metadata format** (plain text, single line):

```
<BUILD_NUMBER> <TIMESTAMP> <DEVICE> <CHANNEL>
```

Example: `2025110800 1730851200 cheetah stable`

## Utility Scripts

| Script | Description |
|---|---|
| `repo-helper.sh` | Multi-repo status, diff, and monitoring tool |
| `link-setup.sh` | Creates build system symlinks after `repo sync` |
| `make-repo.sh` | Generates `default.xml` from `.git2/` projects |
| `git2-setup.sh` | Runs `git2 start` on all modified projects |
| `git2-all.sh` | Batch git2 operations across all projects |

## Publishing to GitHub Organization

### Step 1: Create GitHub Organization

Create a new organization at [github.com/organizations/new](https://github.com/organizations/new) named `rebrand-grapheneos` (or your chosen name).

### Step 2: Create Repositories

Create these repositories in the org:

- `local_manifests`
- `platform_frameworks_base`
- `platform_packages_apps_SetupWizard2`
- `script`
- `platform_build`
- `ota-server`

### Step 3: Push local_manifests

This is a standard git repository (not a git2 repo):

```bash
cd .repo/local_manifests
git remote add origin git@github.com:rebrand-grapheneos/local_manifests.git
git add -A
git commit -m "init: rebrand-grapheneos setup"
git push -u origin main
```

### Step 4: Push git2 Repositories

For each git2 project, push the `.git2/` directory's git content:

```bash
# Example for platform_frameworks_base
cd frameworks/base/.git2
git remote set-url origin git@github.com:rebrand-grapheneos/platform_frameworks_base.git
git push -u origin main:16

# Or use git2-all to set remotes and push all at once
.repo/local_manifests/git2-all.sh git remote set-url origin git@github.com:rebrand-grapheneos/<PROJECT_NAME>.git
.repo/local_manifests/git2-all.sh git push -u origin main:16
```

### Step 5: Push ota-server

Standard git repository:

```bash
cd ota-server
git remote add origin git@github.com:rebrand-grapheneos/ota-server.git
git add -A
git commit -m "init: OTA server"
git push -u origin main
```

### Step 6: Verify

Test the full setup from scratch in a new directory:

```bash
git clone git@github.com:rebrand-grapheneos/local_manifests.git test-build
cd test-build
./setup.sh
repo sync -j$(nproc)
.repo/local_manifests/git2-setup.sh
.repo/local_manifests/link-setup.sh
```

## License

See individual repository licenses.
