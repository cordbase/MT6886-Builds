#!/bin/bash
# Lunaris OS Bringup + Build Script for Crave

set -e

rm -rf device/nothing/Aerodactyl
rm -rf device/nothing/Aerodactyl-kernel
rm -rf vendor/nothing/Aerodactyl
rm -rf vendor/nothing/Pacman
rm -rf device/mediatek/sepolicy_vndr
rm -rf hardware/mediatek
rm -rf hardware/nothing
rm -rf kernel/nothing/mt6886
rm -rf kernel/nothing/mt6886-modules

# List of patches to revert
# Format: "<repo_path>|<commit_sha>"
PATCHES=(
  "packages/apps/Aperture|36c9507ecf2a1a798d2e7931d9019bacc3cc6052"
  "hardware/lineage_compat|60729c841a8b447896aa8108d2c0cfc0a5327041"
  "frameworks/base|79b3ae0b06ffdbadde3d2106a2bbf895b074ffb2"
  "system/core|8ff6e7a68523c3b870d8dcd5713c71ea15b43dd2"
  "system/core|0d5990a96c5e6a404887f5575c5d00bcbbaaef74"
)

echo "[*] Reverting all patches automatically..."

for entry in "${PATCHES[@]}"; do
  IFS="|" read -r REPO_PATH COMMIT_SHA <<< "$entry"
  echo -e "\n[*] Processing: $REPO_PATH → $COMMIT_SHA"

  if [ ! -d "$REPO_PATH" ]; then
    echo "[!] ERROR: Path $REPO_PATH not found in your tree."
    exit 1
  fi

  pushd "$REPO_PATH" > /dev/null

  # Revert without committing (-n) and resolve conflicts automatically by favoring current changes
  git revert -n "$COMMIT_SHA" || git revert --abort
  git add -A

  popd > /dev/null
done

# Commit all reverts in each repo
for entry in "${PATCHES[@]}"; do
  IFS="|" read -r REPO_PATH COMMIT_SHA <<< "$entry"
  pushd "$REPO_PATH" > /dev/null
  git commit -m "Revert patch $COMMIT_SHA automatically"
  popd > /dev/null
done

echo -e "\n[✔] All patches reverted and committed automatically!"

echo "======== Initializing repo ========"
repo init -u https://github.com/Lunaris-AOSP/android -b 16 --git-lfs

echo "======== Adding Trees ========"

git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_device_nothing_Aerodactyl.git device/nothing/Aerodactyl

git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_device_nothing_Aerodactyl.git device/nothing/Aerodactyl

git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_Aerodactyl.git vendor/nothing/Aerodactyl
git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_Pacman.git vendor/nothing/Pacman
git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_PacmanPro.git vendor/nothing/PacmanPro

git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_hardware_mediatek.git hardware/mediatek
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_hardware_nothing.git hardware/nothing

git clone https://github.com/Nothing-2A/android_kernel_nothing_mt6886.git kernel/nothing/mt6886
git clone https://github.com/Nothing-2A/android_kernel_modules_nothing_mt6886.git kernel/nothing/mt6886-modules


# Define a list of patches to apply
# Each line: "<repo_path>|<remote_repo_url>|<commit_sha>"
PATCHES=(
  # Aperture
  "packages/apps/Aperture|https://github.com/Nothing-2A/android_packages_apps_Aperture.git|36c9507ecf2a1a798d2e7931d9019bacc3cc6052"

  # hardware/lineage_compat
  "hardware/lineage_compat|https://github.com/LineageOS/android_hardware_lineage_compat.git|60729c841a8b447896aa8108d2c0cfc0a5327041"

  # frameworks/base
  "frameworks/base|https://github.com/Nothing-2A/android_frameworks_base.git|79b3ae0b06ffdbadde3d2106a2bbf895b074ffb2"

  # system/core (2 commits)
  "system/core|https://github.com/Nothing-2A/android_system_core.git|8ff6e7a68523c3b870d8dcd5713c71ea15b43dd2"
  "system/core|https://github.com/Nothing-2A/android_system_core.git|0d5990a96c5e6a404887f5575c5d00bcbbaaef74"
)

echo "[*] Applying all patches..."

for entry in "${PATCHES[@]}"; do
  IFS="|" read -r REPO_PATH REMOTE_URL COMMIT_SHA <<< "$entry"
  echo -e "\n[*] Processing: $REPO_PATH → $COMMIT_SHA"

  if [ ! -d "$REPO_PATH" ]; then
    echo "[!] ERROR: Path $REPO_PATH not found in your tree."
    exit 1
  fi

  pushd "$REPO_PATH" > /dev/null

  # Ensure the remote exists
  REMOTE_NAME="patch_remote"
  if ! git remote get-url $REMOTE_NAME &> /dev/null; then
    git remote add $REMOTE_NAME "$REMOTE_URL"
  fi
  
  # Fetch the commit object directly
  git fetch $REMOTE_NAME $COMMIT_SHA

  if git cherry-pick $COMMIT_SHA; then
    echo "[✔] Cherry-picked $COMMIT_SHA successfully."
  else
    echo "[!] Conflict while cherry-picking $COMMIT_SHA in $REPO_PATH."
    echo "    Resolve conflicts, then run:"
    echo "    cd $REPO_PATH && git add . && git cherry-pick --continue"
    exit 1
  fi

  popd > /dev/null
done

echo -e "\n[✔] All patches applied successfully!"

echo "===========All repositories cloned successfully!==========="

echo "======== Syncing sources (Crave optimized) ========"
/opt/crave/resync.sh
echo "======== Synced Successfully ========"

# ──────────────────────────────
# Build flags
# ──────────────────────────────
export WITH_BCR=true
export WITH_GMS=true
export TARGET_USES_CORE_GAPPS=true
export TARGET_USE_LOWRAM_PROFILE=true

# ──────────────────────────────
# Bringup properties (for Settings > About > Bringup)
# These go into build.prop at compile time
# ──────────────────────────────
export LUNARIS_MAINTAINER="Himanshu"
export LUNARIS_DEVICE="rhode"
export LUNARIS_SOURCE="cordbase"

# Add props to system.prop overlay so they get picked up
mkdir -p vendor/lunaris/overlay
cat <<EOF > vendor/lunaris/overlay/bringup.prop
ro.lunaris.maintainer=${LUNARIS_MAINTAINER}
ro.lunaris.device=${LUNARIS_DEVICE}
ro.lunaris.source=${LUNARIS_SOURCE}
EOF

echo "======== Environment setup ========"
. build/envsetup.sh

# ──────────────────────────────
# Lunch & Build
# ──────────────────────────────
echo "======== Lunching target ========"
lunch lineage_rhode-userdebug

echo "======== Starting build ========"
m lunaris

echo "✅ Build finished! Check out/target/product/rhode/ for output zip."
