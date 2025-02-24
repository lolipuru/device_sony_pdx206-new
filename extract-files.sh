#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=pdx206
VENDOR=sony

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
    -n | --no-cleanup)
        CLEAN_VENDOR=false
        ;;
    -k | --kang)
        KANG="--kang"
        ;;
    -s | --section)
        SECTION="${2}"
        shift
        CLEAN_VENDOR=false
        ;;
    *)
        SRC="${1}"
        ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
    system_ext/lib64/libwfdnative.so | vendor/lib64/libvpplibrary.so | vendor/lib64/libswiqisettinghelper.so | /vendor/lib64/vendor.somc.hardware.swiqi@1.0-impl.so)
        sed -i "s/android.hidl.base@1.0.so/libhidlbase.so\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00/" "${2}"
        ;;
    product/lib64/libdpmframework.so)
        sed -i "s/libhidltransport.so/libcutils-v29.so\x00\x00\x00/" "${2}"
        ;;
    vendor/lib64/vendor.somc.camera* | vendor/bin/hw/vendor.somc.hardware.camera.*)
        "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
        "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${2}"
        if ! "${PATCHELF}" --print-needed "${2}" | grep "libbinder.so" > /dev/null; then
            "${PATCHELF}" --add-needed "libbinder-v32.so" "${2}"
        else
            "${PATCHELF}" --replace-needed "libbinder.so" "libbinder-v32.so" "${2}"
        fi
        ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"