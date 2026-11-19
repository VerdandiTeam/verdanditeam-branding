# verdanditeam-branding

VerdandiTeam branding for Sailfish OS devices, in one package:

- **Settings → System → Battery**: live charge/discharge rate, time remaining, battery health, cycle count and charger details
- **Settings → System → Temperatures**: every thermal sensor with a per-device label, grouped by component, shown against its throttling limit
- **Sailfish Browser**: VerdandiTeam bookmarks and search engines (replaces `sailfish-content-browser-default`)

Package: `verdanditeam-branding`. It replaces the earlier `verdanditeam-settings-battery` and `sailfish-content-browser-verdanditeam` packages (Obsoletes).
It is built per architecture, not noarch, because the browser search engines install under `%{_libdir}` (`/usr/lib` on armv7hl, `/usr/lib64` on aarch64).

## Layout

```
rpm/verdanditeam-branding.spec
settings/entries/              → /usr/share/jolla-settings/entries/
  verdanditeam-battery.json    redefines the stock battery page entry
  verdanditeam-thermal.json    adds the Temperatures entry after Battery
settings/battery/              → /usr/share/jolla-settings/pages/verdanditeam-battery/
  BatteryMainPage.qml          stock battery page plus one BatteryDetails item under the header
  BatteryDetails.qml           level circle, health circle and readings; owns the BatteryInfo poller
  BatteryInfo.qml              polls sysfs every 2 s, only while the page is active and the app is in the foreground
  batteryinfo.js               all interpretation logic, pure ES5 (Qt 5.6), runnable with node
  BatteryLevelHeader.qml       level circle; uses DiskUsageCircle/DiskUsageLabelGroup via import "../storage"
  BatteryHealthCircle.qml      health % circle (full charge left, design right), same storage widgets
settings/thermal/              → /usr/share/jolla-settings/pages/verdanditeam-thermal/
  ThermalPage.qml              sensor tables per device, polling and UI
browser/search-engines/        → %{_libdir}/mozembedlite/chrome/embedlite/content/
browser/default-content/       → /usr/share/sailfish-browser/default-content/
```

Build: `sfdk build`.

## Battery page

### How it hooks into Settings

This works the same way as verdandiupdater, whose `verdandiupdater-settings.json` redefines `system_settings/system/sailfishos` from the stock `sailfishos.json`. `settings/entries/verdanditeam-battery.json` redefines `system_settings/system/battery` with our page as `source`. Settings uses the entry from the file that sorts later, and `verdanditeam-…` sorts after `battery.json`, so keep the file name starting with something later in the alphabet than "battery".

No `jolla-settings-system` files are modified. `rpm -V` stays clean, and Jolla updates and package removal need no scripts. The stock `battery_saving_switch` (top menu toggle) entry is left alone.

Verified on miami on 2026-11-17: stock page restored, entry plus page dir installed, and Settings opened our page.

Known couplings:

- `BatteryMainPage.qml` is the stock 1.2.95.5 page plus one `BatteryDetails {}` item. After a Jolla update, refresh it by copying the new stock page and re-adding those 3 lines.
- The storage widgets are imported from `../storage`, not copied. If Jolla renames them, the page fails to load.
- Licence: `BatteryMainPage.qml` is derived from Jolla's proprietary page. Check that before publishing the package outside the team.

### How the data is read and why

No C++ is needed. QML lists `/sys/class/power_supply` (FolderListModel) and reads each `uevent` with a file:// XHR, which gets all standard properties in one read per supply. Sailfish 5.2 has no statefs and `BatteryStatus` exposes neither current nor capacity.

Drivers don't follow the ABI consistently, so `batteryinfo.js` assumes nothing:

| Problem seen | Handling |
|---|---|
| `TYPE` is unreliable (Moto `bms`, `mmi_battery` claim `Mains`) | Battery-like = TYPE Battery/BMS, **or** name matches bat/bms/fg/gauge and it has capacity props. `SCOPE=Device` (BT/HID peripherals) excluded. Primary = best score (TYPE Battery, name `battery`/`BAT0`), others fill gaps. |
| Current sign differs between drivers, even on one phone (Moto `battery` +, `bms` −, both charging) | Magnitude only; direction from `STATUS` (fallback: online charger). |
| Units: µV/µA/µAh per ABI, mV/mA on some drivers; tenths °C vs m°C | Range-based detection per value (see the unit functions). mA detected via mV voltage or < 2000 raw. |
| `charge_full` copied from design (Xperia 10 IV: 4934000 = 4934000) | Treated as "not measured". Health % is shown only from a value that differs from design, and only if the ratio is between 30 and 130%. |
| Vendor health outside the ABI | Checked once, polled only if present: `<bat>/age` (Motorola, matches charge_full ratio), `<bat>/fg_asoc` (Samsung), `<bat>/soh`, `state_of_health`, `battery_soh`, `/sys/class/battchg_ext/learned_capacity` (Sony; unit guessed against design, 0 = not learned). |
| Placeholder cycle counts (Moto `battery`=1, `bms`=689) | Highest value across battery-like supplies. |
| Placeholder text values (G2: `MANUFACTURER=UNKNOWN`) | `Unknown`, `N/A`, `None`, `null` in any case count as empty for manufacturer, model, technology, condition and charge type. The first real value across battery-like supplies wins. |
| Inputs vs charger ICs (Moto: wireless input `dc` reports 0.047 V; the IC `charger` is TYPE=Unknown, ONLINE=1) | Every online non-battery supply counts. The kind comes from the best-typed one (Wireless/USB*/Mains beat Unknown). Voltage, current and limit fall back across online supplies, and voltages outside 2–25 V are dropped. |
| Laptop/PinePhone-style energy reporting | ENERGY_* / POWER_NOW supported; capacities then shown in Wh. |
| `CHARGE_COUNTER` that isn't remaining charge (G2: ~30000 at 88% of 2362 mAh, read as 30 mAh or 30,000 mAh depending on which side of the unit threshold it lands) | `CHARGE_NOW`/`CHARGE_COUNTER` are used only if they agree with `CAPACITY` within 15 points. Otherwise remaining charge is level × full capacity. |
| Time remaining | Driver's TIME_TO_FULL/EMPTY if present, else linear from smoothed current (EMA, reset when direction changes). Shown with "≈". |

Health priority: `charge_full`≠design → `energy_full`≠design → vendor file → none. With none, the page says the device doesn't report it instead of showing a fake 100%.

### Device workarounds

Fixes that are only right for one device live in `DEVICE_WORKAROUNDS` in `batteryinfo.js`, keyed by the codename from `MER_HA_DEVICE` in `/etc/hw-release`. Other devices get the generic behaviour above.

| Codename | Device | Workaround | Why |
|---|---|---|---|
| `enchilada`, `fajita` | OnePlus 6, 6T | `designFromBatteryTypeName` | `charge_full_design` is 2878000 on both phones, but the batteries are 3300 and 3700 mAh, as `bms` `BATTERY_TYPE` says (`OP_3300mah`, `OP_3700mAh`). Design comes from the mAh figure in `BATTERY_TYPE`. |
| `enchilada`, `fajita` | OnePlus 6, 6T | `chargeFullIsPlaceholder` | `charge_full` is also 2878000 on both: a kernel constant, not a measurement. Health is shown as not reported. |
| `xqcc72` | Sony Xperia 10 IV | `batteryModelNameIsPlaceholder` | `MODEL_NAME=MURRAY_BATTERY` is the Sony platform name (murray), not a battery model, and nothing else in sysfs names the cell maker (`battchg_ext/batt_id` is only a number). The model name is dropped, so the Manufacturer row is hidden. |
| `thea`, `titan` | Moto G 2014 LTE, Moto G 2014 | `chargeFullIsPlaceholder` | `charge_full` stays at 2362000 against a 2366000 design (99.8%) on old, well-used batteries, so it isn't a measurement. Health is shown as not reported. |
| `pipa` | Xiaomi Pad 6 | `powerFromVoltageTimesCurrent` | `POWER_NOW=67753699` while drawing ~2.5 W. Power is V × I instead. |
| `pipa` | Xiaomi Pad 6 | `cycleCountFromChargeBandCounters` | `CYCLE_COUNT=1` is a placeholder. The average of the Qualcomm per-charge-band `CYCLE_COUNTS` (the figure Qualcomm's driver reports) gives ~150. |

To add one: give the device's codename an entry with a descriptive flag name, then check for that flag where the value is computed.

### Status / not done

- `batteryinfo.js` is tested against the Motorola (live dump) and a reconstruction of the Xperia 10 IV readings (only the keys the user pasted).
- The page runs on miami (Edge 30 Neo, SFOS 5.2) in the packaged layout, but copied by hand. The `verdanditeam-branding` RPM has not been built yet.
- New strings use `qsTr()` (no translation catalogue). `qsTrId` without a `.qm` would display raw ids.

On miami the hand-copied files are not owned by any package: `pages/verdanditeam-battery/` and `settings/entries/verdanditeam-battery.json`. Installing the RPM over them is fine; the package simply takes ownership of the same paths.

## Temperatures page

Lists `/sys/class/thermal/thermal_zone*` (FolderListModel), reads each zone's `type` once and its `temp` every 2 s while the page is active, with file:// XHR like the battery page.
Zone names are device-tree node names and mean nothing to users, so labels come from tables in `ThermalPage.qml` picked by `MER_HA_DEVICE`.
A zone no table matches is shown under Other with its raw name.

| Rule | Why |
|---|---|
| Hidden by name everywhere: `ibat`, `vbat`, `vph`, `bcl`, `soc`, `socd`, `lmh-dcvs`, `zeroc-`, `-lowf`, `max-step` | Qualcomm battery-limit and throttling zones: currents in mA, voltages in mV, 0/1 triggers, constant 75 °C thresholds, or copies of other zones. |
| Readings outside −30…150 °C or empty are hidden | Disconnected thermistors (−274 °C, 1874 °C), disabled zones. |
| Zones with the same group and label are merged | `-usr` and `-step` zones read the same sensor under different governors. The merged row keeps the lowest real limit. |
| Limit = lowest `passive`/`hot` trip between 30 and 125 °C | Most `-usr` zones carry a 125 °C placeholder trip. Without a real trip, the group default is used: 95 °C, battery and surface 45 °C. |
| Bar runs from 20 °C to the limit, red within 5 °C of it | |

Per-device notes:

| Codename | Device | Notes |
|---|---|---|
| `victara` | Moto X 2014 (mainline) | 13 clean zones with real trips. Also reads the `tmp108` board sensor from hwmon, which is not a thermal zone. |
| `miami`, `xqcc72`, `xqdc72` | Moto Edge 30 Neo, Xperia 10 IV, Xperia 10 V (zambezi) | Same SM6375 (blair) SoC zones, different board thermistors; one shared table. `beamer-*` and `modem-mmw*` are hidden: no mmWave hardware, placeholder or impossible readings. miami's `modem-streamer-usr` is a 2 °C placeholder and is hidden there only. xqcc72's `rear-cam-therm-usr`, `camera-therm-usr` and `sony_cam_back0` read garbage and are hidden; xqdc72's `rear-cam-therm-usr` and `flash-cam-therm-usr` read −40 °C and are hidden too. xqdc72's `socd` is a battery-limit zone (74 with a 90 trip), hidden everywhere with `soc`. |
| `pipa` | Xiaomi Pad 6 | SM8250. All modem zones are disabled (Wi-Fi only). `batt_therm` reads tenths of a degree and duplicates `battery`, so it is hidden. |
| `enchilada`, `fajita` | OnePlus 6, 6T | SDM845, identical tables. |
| `thea`, `titan` | Moto G 2014 LTE, Moto G 2014 | Old kernel: `tsens_tz_sensor*` and `pa_therm0` report whole °C, `pm8226_tz` m°C. The tsens sensors are only "SoC sensor N": thermal-engine names them `cpu0-1`, `cpu2-3`, `pop_mem`, but the mapping to sensor numbers is inside its binary. titan's `pa_therm0` reads 125 °C and is hidden there. |

## Browser content

`browser/search-engines/*.xml` and `browser/default-content/bookmarks.json`, unchanged from `sailfish-content-browser-verdanditeam`.
The package Provides `sailfish-content-browser` and Conflicts/Obsoletes `sailfish-content-browser-default`, like that package did.
