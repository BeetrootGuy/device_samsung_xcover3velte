# Vendor blob extraction — next steps

`proprietary-files.txt` in this directory is a **draft**, adapted from
`android_device_samsung_j1xlte`. It is good enough to start a build tree
with, but must be corrected against real SM-G389F data before it's trusted.

## Why this can't be finished without your hardware/firmware

`extract-files.sh` calls `vendor/lineage/build/tools/extract_utils.sh`,
which only exists inside a synced LineageOS build tree (`repo sync` against
a full manifest), and it reads from either:

- a rooted, ADB-reachable SM-G389F running stock firmware, or
- a mounted/extracted stock firmware image (system.img + vendor partition
  equivalent, since this is a pre-Treble device so it's likely just
  system.img containing both)

Neither of those exists in this sandboxed environment, so the extraction
itself has to run on your machine (or a build server), not here.

## How to run it for real

1. Get a full LineageOS 14.1 source tree synced (`repo sync`), with this
   device tree placed at `device/samsung/xcover3velte`, the kernel tree at
   `kernel/samsung/exynos3475`, matching the earlier steps in this project.

2. Get a stock G389F firmware (a Marshmallow-era `.tar.md5` from a site
   like SamMobile or Frija/Samloader), extract `system.img`, and mount it
   read-only (e.g. `simg2img` then loop-mount, or use `imjtool`/`ext4fuse`
   depending on image format).

3. From `device/samsung/xcover3velte`, run:
   ```
   ./extract-files.sh /path/to/mounted/system
   ```
   or, if you have a rooted physical device connected via adb:
   ```
   ./extract-files.sh adb
   ```

4. This regenerates `proprietary-files.txt`-driven blobs into
   `vendor/samsung/xcover3velte/proprietary/`, and `setup-makefiles.sh`
   (called automatically at the end) generates:
   - `vendor/samsung/xcover3velte/xcover3velte-vendor.mk`
   - `vendor/samsung/xcover3velte/Android.mk`
   - `vendor/samsung/xcover3velte/BoardConfigVendor.mk`

   These three files are exactly what `BoardConfig.mk` and `device.mk` in
   this device tree already reference — the build will not work without
   them existing.

## What to double check once you have real system/vendor contents

- **NFC**: search the extracted `/system` for anything under
  `lib/hw/nfc*`, `lib/*pn547*`, `lib/*nfc*`, and `etc/permissions/*nfc*`.
  Confirm exact filenames — the placeholders in `proprietary-files.txt`
  are guesses only.
- **Grip sensor (SX9310)**: check whether it's handled inside the existing
  `lib/hw/sensors.universal3475.so` blob (most likely, since j1xlte's own
  sensor set — K2HH/GP2A/AK09916C — all live in that one blob) or has a
  separate library.
- **Audience ES705 codec files** (`es305_fw*.bin`): CONFIRMED absent —
  matches `libLifevibes_lvverx.so`/`lvvetx.so` also being absent from
  the real firmware, consistent with no `SND_SOC_ES*` codec enabled in
  the kernel and no matching dts node. No action needed.

## Findings from the actual SM-G389F extraction (first pass)

- **Bluetooth firmware**: real file is
  `vendor/firmware/BCM4345C0_003.001.025.0147.0245.hcd` (BCM4345C0 chip,
  not the BCM43438A1 assumed from j1xlte). Corrected in
  `proprietary-files.txt`.
- **`libbt-vendor.so`**: lives at plain `lib/libbt-vendor.so`, not
  `vendor/lib/libbt-vendor.so`. Corrected.
- **`libSEF.so`**: lives at plain `lib/libSEF.so`, not `vendor/lib/libSEF.so`.
  Corrected.
- **`libfloatingfeature.so`**: CONFIRMED NOT PRESENT as a shared library on
  this device/firmware build. Only an XML config file exists instead.
  Removed from `proprietary-files.txt` as a placeholder comment — the
  real XML path/filename still needs to be identified and added. Check
  the extracted tree for something like `etc/floating_feature.xml`,
  `etc/csc/*.xml`, or similar, and check what (if anything) in the
  framework/init flow actually reads it — it's possible this build
  doesn't rely on runtime feature-flag parsing the way later Samsung
  builds do, in which case it may not even need porting.
- **`fimc_is_lib_isp.bin` / `fimc_is_fd.bin`**: NOT bad guesses — both are
  real firmware filenames referenced directly in the fimc-is2 driver
  (`FIMC_IS_ISP_LIB` / logged in `fimc-is-device-ischain.c`). The driver
  hardcodes their load path as `/system/vendor/firmware/` (via an
  unconditional `#define VENDER_PATH` in `fimc-is-binary.h`, not gated by
  any Kconfig option). If `extract-files.sh` didn't find them under
  `vendor/firmware/` relative to your mounted system root, check
  specifically under a `system/vendor/firmware/` subdirectory inside the
  image — pre-Treble Samsung system.img files often embed this as a real
  subdirectory rather than a separate partition, and the exact mount
  root used can shift where "vendor/firmware/..." resolves to.
- **PLMN files**: `etc/plmn_delta.bin` CONFIRMED ABSENT on this firmware
  variant (commented out, not needed) — `etc/plmn_se13.bin` CONFIRMED
  PRESENT, kept as-is.
- **`libsec-ril-dsds.so`**: still unconfirmed — this is the dual-SIM RIL
  library. Its absence is expected if your specific unit is the
  single-SIM `SM-G389F`, but would be a real gap if you actually have
  the `SM-G389F/DS` dual-SIM variant. Worth checking which you have.

