#!/bin/bash
# Lunaris OS Bringup + Build Script for Crave

set -e

rm -rf device/nothing/Aerodactyl
rm -rf device/nothing/Aerodactyl-kernel
rm -rf vendor/nothing/Aerodactyl
rm -rf vendor/nothing/Pacman
rm -rf vendor/nothing/PacmanPro
rm -rf device/mediatek/sepolicy_vndr
rm -rf hardware/mediatek
rm -rf hardware/nothing
rm -rf kernel/nothing/mt6886
rm -rf kernel/nothing/mt6886-modules
rm -rf hardware/lineage_compat
rm -rf device/nothing/Aerodactyl-ntcamera
rm -rf vendor/nothing/Aerodactyl-ntcamera

echo "======== Initializing repo ========"
repo init -u https://github.com/Lunaris-AOSP/android -b 16 --git-lfs

echo "======== Adding Trees ========"

# devuce tree bringup
git clone --branch lineage-23.0 https://github.com/cordbase/android_device_nothing_Aerodactyl.git device/nothing/Aerodactyl

# vendor bringup
git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_Aerodactyl.git vendor/nothing/Aerodactyl
git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_Pacman.git vendor/nothing/Pacman
git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_PacmanPro.git vendor/nothing/PacmanPro

# Hardware bringup
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_hardware_mediatek.git hardware/mediatek
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_hardware_nothing.git hardware/nothing

# kernel bringup
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_device_nothing_Aerodactyl-kernel.git device/nothing/Aerodactyl-kernel
git clone https://github.com/Nothing-2A/android_kernel_nothing_mt6886.git kernel/nothing/mt6886
git clone https://github.com/Nothing-2A/android_kernel_modules_nothing_mt6886.git kernel/nothing/mt6886-modules

# Nothing Cmaera bringup
git clone https://github.com/Nothing-2A/android_device_nothing_Aerodactyl-ntcamera.git device/nothing/Aerodactyl-ntcamera
git clone https://github.com/cordbase/proprietary_vendor_nothing_Aerodactyl-ntcamera.git vendor/nothing/Aerodactyl-ntcamera
# compat bringup
git clone https://github.com/LineageOS/android_hardware_lineage_compat.git hardware/lineage_compat

# set username
git config --global user.name "cordbase"
git config --global user.email "cordbase@users.noreply.github.com"

# List of patches: "<repo_path>|<commit_sha>|<remote_url>"
PATCHES=(
  "packages/apps/Aperture|36c9507ecf2a1a798d2e7931d9019bacc3cc6052|https://github.com/Nothing-2A/android_packages_apps_Aperture.git"
  "hardware/lineage_compat|60729c841a8b447896aa8108d2c0cfc0a5327041|https://github.com/LineageOS/android_hardware_lineage_compat.git"
  "frameworks/base|79b3ae0b06ffdbadde3d2106a2bbf895b074ffb2|https://github.com/Nothing-2A/android_frameworks_base.git"
  "system/core|8ff6e7a68523c3b870d8dcd5713c71ea15b43dd2|https://github.com/Nothing-2A/android_system_core.git"
  "system/core|0d5990a96c5e6a404887f5575c5d00bcbbaaef74|https://github.com/Nothing-2A/android_system_core.git"
  "frameworks/base|6909a748157404e9150586b9c0860fdb81dd54cc|https://github.com/AxionAOSP/android_frameworks_base.git"
  "frameworks/base|f89e8fa592233d86ad2cabf81df245c4003587cb|https://github.com/AxionAOSP/android_frameworks_base.git"
)

echo "[*] Applying all patches automatically..."

for entry in "${PATCHES[@]}"; do
  IFS="|" read -r REPO_PATH COMMIT_SHA REMOTE_URL <<< "$entry"
  echo -e "\n[*] Applying patch $COMMIT_SHA in $REPO_PATH"

  if [ ! -d "$REPO_PATH" ]; then
    echo "[!] ERROR: Path $REPO_PATH not found in your tree."
    exit 1
  fi

  pushd "$REPO_PATH" > /dev/null

  REMOTE_NAME="patch_remote"
  if ! git remote get-url $REMOTE_NAME &> /dev/null; then
    git remote add $REMOTE_NAME "$REMOTE_URL"
  fi

  # Special handling for orphan commit in hardware/lineage_compat
  if [ "$REPO_PATH" == "hardware/lineage_compat" ]; then
    echo "[*] Fetching orphan commit directly..."
    git fetch "$REMOTE_URL" "$COMMIT_SHA"
  else
    git fetch $REMOTE_NAME $COMMIT_SHA
  fi

  # Cherry-pick with automatic conflict resolution (favor current tree)
  if ! git cherry-pick -X ours $COMMIT_SHA; then
    echo "[!] Conflict detected, aborting cherry-pick for $COMMIT_SHA"
    git cherry-pick --abort
  fi

  git remote remove $REMOTE_NAME
  popd > /dev/null
done

echo -e "\n[✔] All patches applied successfully (auto-resolved conflicts)!"

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
export TARGET_OPTIMIZED_DEXOPT := true

# ──────────────────────────────
# Bringup properties (for Settings > About > Bringup)
# These go into build.prop at compile time
# ──────────────────────────────
export LUNARIS_MAINTAINER="Himanshu"
export LUNARIS_DEVICE="Pacman"
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
lunch lineage_pacman-userdebug

echo "======== Starting build ========"
m lunaris

echo "✅ Build finished! Check out/target/product/rhode/ for output zip."
