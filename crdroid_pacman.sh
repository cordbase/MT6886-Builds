

# Repo Init & Sync
repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --no-clone-bundle
/opt/crave/resync.sh

# Cleanup
rm -rf hardware/lineage/interfaces/sensors

# Set up build environment
export BUILD_USERNAME=Himanshu
export BUILD_HOSTNAME=crave

# env setup & brunch
. build/envsetup.sh
make installclean
brunch Pacman
