#!/bin/bash
# Infinity X Build Script + Build Script for Crave

# Remove old directories
rm -rf prebuilts/clang/host/linux-x86
rm -rf out/soong/.intermediates/system/sepolicy
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
repo init --depth=1 --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault
echo "======== Syncing sources (Crave optimized) ========"
/opt/crave/resync.sh

    # remove all issue causing dirs (@safety)
dirs_to_remove=(
    hardware/qcom-caf/msm8953
    hardware/qcom-caf/msm8996
    hardware/qcom-caf/msm8998
    hardware/qcom-caf/sdm660
    hardware/qcom-caf/sdm845
    hardware/qcom-caf/sm8150
    hardware/qcom-caf/sm8250
    hardware/qcom-caf/sm8350
    hardware/qcom-caf/sm8450
    hardware/qcom-caf/sm8550
    hardware/qcom-caf/sm8650
    hardware/qcom/display/msm8996
    hardware/qcom/sdm845
    hardware/qcom/sm7250/display
    hardware/qcom/sm8150/display
    vendor/qcom/opensource/commonsys-intf/display
    vendor/qcom/opensource/display
    hardware/qcom-caf/sm8350/display/qmaa/*.cpp
    out/host/linux-x86/bin/go/soong-display_defaults/pkg/android/soong/hardware/qcom/sm8150/display.a
    hardware/qcom/sm8150/display/display_defaults.go
)
rm -rf "${dirs_to_remove[@]}"

echo "======== Adding Trees ========"

# device tree bringup
git clone --branch lineage-23.0 https://github.com/cordbase/android_device_nothing_Aerodactyl.git device/nothing/Aerodactyl

# vendor bringup
git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_Aerodactyl.git vendor/nothing/Aerodactyl
git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_Pacman.git vendor/nothing/Pacman
git clone --branch lineage-23.0 https://gitlab.com/nothing-2a/proprietary_vendor_nothing_PacmanPro.git vendor/nothing/PacmanPro

# Hardware bringup
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_hardware_mediatek.git hardware/mediatek
git clone --branch lineage-23.0 https://github.com/cordbase/android_hardware_nothing.git hardware/nothing

# kernel bringup
git clone --branch lineage-23.0 https://github.com/Nothing-2A/android_device_nothing_Aerodactyl-kernel.git device/nothing/Aerodactyl-kernel
git clone https://github.com/Nothing-2A/android_kernel_nothing_mt6886.git kernel/nothing/mt6886
git clone https://github.com/Nothing-2A/android_kernel_modules_nothing_mt6886.git kernel/nothing/mt6886-modules

# Nothing Camera bringup
git clone https://github.com/Nothing-2A/android_device_nothing_Aerodactyl-ntcamera.git device/nothing/Aerodactyl-ntcamera
git clone --branch lineage-23.0 https://github.com/cordbase/proprietary_vendor_nothing_Aerodactyl-ntcamera.git vendor/nothing/Aerodactyl-ntcamera

# compat bringup
git clone https://github.com/LineageOS/android_hardware_lineage_compat.git hardware/lineage_compat

# set username
git config --global user.name "cordbase"
git config --global user.email "cordbase@users.noreply.github.com"

# List of patches: "<repo_path>|<commit_sha>|<remote_url>"
PATCHES=(
  "packages/apps/Aperture|36c9507ecf2a1a798d2e7931d9019bacc3cc6052|https://github.com/Nothing-2A/android_packages_apps_Aperture"
  "hardware/lineage_compat|60729c841a8b447896aa8108d2c0cfc0a5327041|https://github.com/LineageOS/android_hardware_lineage_compat"
  "frameworks/base|79b3ae0b06ffdbadde3d2106a2bbf895b074ffb2|https://github.com/Nothing-2A/android_frameworks_base"
  "system/core|8ff6e7a68523c3b870d8dcd5713c71ea15b43dd2|https://github.com/Nothing-2A/android_system_core"
  "system/core|0d5990a96c5e6a404887f5575c5d00bcbbaaef74|https://github.com/Nothing-2A/android_system_core"
  "frameworks/base|f89e8fa592233d86ad2cabf81df245c4003587cb|https://github.com/AxionAOSP/android_frameworks_base"
  "frameworks/base|6909a748157404e9150586b9c0860fdb81dd54cc|https://github.com/AxionAOSP/android_frameworks_base"
  "build|c6be68fdc8d3d6f2d68b3152185aae9fadfd57f8|https://github.com/cordbase/build"
  "build|2d02b9cabe4c23a5d0bf2763c842f8669d063c4b|https://github.com/cordbase/build"
)

echo "[*] Applying all patches automatically..."

for entry in "${PATCHES[@]}"; do
  IFS="|" read -r REPO_PATH COMMIT_SHA REMOTE_URL <<< "$entry"
  echo -e "\n[*] Applying patch $COMMIT_SHA in $REPO_PATH"

  # Clone repo if missing
  if [ ! -d "$REPO_PATH" ]; then
    echo "[*] Path $REPO_PATH not found, cloning..."
    git clone --depth=1 "$REMOTE_URL" "$REPO_PATH"
  fi

  pushd "$REPO_PATH" > /dev/null

  PATCH_URL="$REMOTE_URL/commit/$COMMIT_SHA.patch"

  # Skip if already applied
  if git log --oneline | grep -q "$COMMIT_SHA"; then
    echo "[✔] Skipping $COMMIT_SHA (already applied)."
    popd > /dev/null
    continue
  fi

  echo "[*] Downloading patch from $PATCH_URL"
  if curl -fsSL "$PATCH_URL" | git am -3; then
    echo "[✔] Applied $COMMIT_SHA successfully."
  else
    echo "[!] Conflict detected for $COMMIT_SHA, aborting safely..."
    git am --abort || true
  fi

  popd > /dev/null
done

echo -e "\n[✔] All patches processed!"

echo "===========All repositories cloned successfully!==========="

# ====== Build Flags ======
export INFINITY_BUILD_TYPE=UNOFFICIAL
export INFINITY_MAINTAINER="Himanshu"
export TARGET_HAS_UDFPS=false
export WITH_GAPPS=true

# ====== Inject Infinity props ======
export PRODUCT_SYSTEM_PROPERTIES+=" \
    ro.product.marketname=Nothing Phone (2a) \
    ro.infinity.soc=Dimensity 7200 Pro (4 nm) \
    ro.infinity.battery=5000 mAh \
    ro.infinity.display=AMOLED, 120Hz, 2160Hz PWM, HDR10+ \
    ro.infinity.camera=50MP + 50MP \
    ro.infinity.maintainer=$INFINITY_MAINTAINER \
"
echo "======== flags setup complete ========"

echo "======== Environment setup ========"
. build/envsetup.sh
echo "======== Environment setup complete ========"
# ──────────────────────────────
# Lunch & Build
# ──────────────────────────────
echo "======== Lunching target ========"
lunch infinity_pacman-user
m bacon
echo "✅ Build finished!"
