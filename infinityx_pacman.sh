#!/bin/bash
# Clover Bringup + Build Script for Crave

# Cleanup
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

# Init Rom Manifest
repo init -u https://github.com/ProjectInfinity-X/manifest -b 16 --git-lfs

# Sync the repositories  
/opt/crave/resync.sh 

#Cleanup
rm -rf hardware/lineage/interfaces/sensors

# device tree bringup
git clone --branch infinityx https://github.com/cordbase/android_device_nothing_Aerodactyl.git device/nothing/Aerodactyl

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

# Dolby BringUP
git clone --branch Dolby-Vision-1.1 https://github.com/swiitch-OFF-Lab/hardware_dolby.git hardware/dolby

# set username
git config --global user.name "cordbase"
git config --global user.email "cordbase@users.noreply.github.com"

# List of patches: "<repo_path>|<commit_sha>|<remote_url>"
PATCHES=(
  "packages/apps/Aperture|36c9507ecf2a1a798d2e7931d9019bacc3cc6052|https://github.com/Nothing-2A/android_packages_apps_Aperture"
  "hardware/lineage/compat|60729c841a8b447896aa8108d2c0cfc0a5327041|https://github.com/LineageOS/android_hardware_lineage_compat"
  "system/core|8ff6e7a68523c3b870d8dcd5713c71ea15b43dd2|https://github.com/Nothing-2A/android_system_core"
  "system/core|0d5990a96c5e6a404887f5575c5d00bcbbaaef74|https://github.com/Nothing-2A/android_system_core"
  "frameworks/base|f89e8fa592233d86ad2cabf81df245c4003587cb|https://github.com/AxionAOSP/android_frameworks_base"
  "frameworks/base|6909a748157404e9150586b9c0860fdb81dd54cc|https://github.com/AxionAOSP/android_frameworks_base"
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

echo -e "All patches processed!"

# Removing conflicts @ directories

# Lists of Directories
DIRS=(
    # gsi target
    "target/product/gsi"
    # generic device
    "device/sample"
    "device/amlogic/yukawa"
    "device/amlogic/yukawa-kernel"
    "device/google/atv"
    "device/google/cuttlefish"
    "device/linaro/dragonboard"
    "device/linaro/dragonboard-kernel"
    "device/linaro/hikey"
    "device/linaro/hikey-kernel"
    # tests
    "cts"
    "test/mts"
    "test/vts"
    "test/vts-testcase/hal"
    "test/vts-testcase/kernel"
    "test/vts-testcase/security"
    "test/vts-testcase/vndk"
    "test/mlts/benchmark"
    "test/mlts/models"
    "test/suite_harness"
    "test/vts/tests/kernel_proc_file_api_test"
    "test/mlts/models"
    "test/vts-testcase/hal/treble/platform_version"
    "test/suite_harness"
    "test/vts-testcase/kernel/checkpoint"
    # kernel & other stuffs
    "test/vts-testcase/security/system_property"
    "tools/test/connectivity"
    "test/vts-testcase/kernel/fuse_bpf"
    "external/linux-kselftest"
    "packages/apps/DeviceDiagnostics/TradeInModeTests"
    # kernel & other stuffs
    "tools/test/connectivity"
    "external/linux-kselftest"
    "kernel/tests"
    # test apps
    "packages/apps/DeviceDiagnostics"
    "packages/apps/DevCamera"
    "packages/apps/Test/connectivity"
    "packages/apps/SampleLocationAttribution"
    "packages/apps/SpareParts"
)

for DIR in "${DIRS[@]}"; do
    TARGET_PATH="$DIR/Android.bp"

    if [ ! -d "$DIR" ]; then
        echo "Directory '$DIR' not found — skipping."
        continue
    fi

    # Remove original Android.bp if it exists
    if [ -f "$TARGET_PATH" ]; then
        echo "Removing original '$TARGET_PATH'"
        rm -f "$TARGET_PATH"
    fi

    # Write minimal fake Android.bp
    cat > "$TARGET_PATH" <<'EOF'
// Fake Android.bp to bypass Soong parsing errors
soong_namespace {
}
EOF

    echo "Stub Android.bp created at '$TARGET_PATH'"
done

# Variables
export BUILD_USERNAME=Himanshu
export BUILD_HOSTNAME=crave

# Set up build environment
. build/envsetup.sh

# lunch
lunch infinity_Pacman-userdebug

# Build
m bacon
