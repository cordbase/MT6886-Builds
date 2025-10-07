#!/bin/bash
# LunarisAOSP Bringup + Build Script for Crave
echo "Starting!"
# Cleanup
rm -rf prebuilts/clang/host/linux-x86
em -rf .repo/local_manifests

# Init Rom Manifest
repo init -u https://github.com/PixelOS-AOSP/manifest.git -b fifteen --git-lfs

# Device Manifest
git clone https://github.com/cordbase/local_manifest.git -b pos .repo/local_manifests

# Sync the repositories  
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags


# set username
git config --global user.name "cordbase"
git config --global user.email "cordbase@users.noreply.github.com"

# List of patches: "<repo_path>|<commit_sha>|<remote_url>"
PATCHES=(
  "packages/apps/Aperture|36c9507ecf2a1a798d2e7931d9019bacc3cc6052|https://github.com/Nothing-2A/android_packages_apps_Aperture"
  "hardware/lineage/compat|60729c841a8b447896aa8108d2c0cfc0a5327041|https://github.com/LineageOS/android_hardware_lineage_compat"
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

echo "All patches processed!"

# Set up build environment
source build/envsetup.sh

# Variables
export BUILD_USERNAME=Himanshu
export BUILD_HOSTNAME=crave

# Lunch
lunch aosp_Pacman-bp2a-userdebug
make installclean

# Build
mka bacon
