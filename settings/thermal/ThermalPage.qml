import QtQuick 2.0
import Sailfish.Silica 1.0
import Qt.labs.folderlistmodel 2.1

Page {
    id: page

    readonly property string thermalRoot: "/sys/class/thermal"
    readonly property string hwmonRoot: "/sys/class/hwmon"
    readonly property string hwReleasePath: "/etc/hw-release"
    readonly property int refreshInterval: 2000
    readonly property int scanDelay: 200
    readonly property int maxTripPoints: 4
    readonly property real barFloorCelsius: 20
    readonly property real warningMarginCelsius: 5
    readonly property real minPlausibleCelsius: -30
    readonly property real maxPlausibleCelsius: 150
    readonly property real minTripCelsius: 30
    readonly property real placeholderTripCelsius: 125
    readonly property var limitTripTypes: ["passive", "hot"]

    property string deviceName
    property var sensorGroups: []
    property var temperatures: ({})
    property var _sensors: []
    property bool _refreshing

    readonly property var groups: [
        { id: "cpu", title: qsTr("Processor"), defaultLimit: 95 },
        { id: "gpu", title: qsTr("Graphics"), defaultLimit: 95 },
        { id: "memory", title: qsTr("Memory"), defaultLimit: 95 },
        { id: "modem", title: qsTr("Modem"), defaultLimit: 95 },
        { id: "wireless", title: qsTr("Wireless"), defaultLimit: 95 },
        { id: "media", title: qsTr("Multimedia"), defaultLimit: 95 },
        { id: "battery", title: qsTr("Battery and charging"), defaultLimit: 45 },
        { id: "surface", title: qsTr("Surface"), defaultLimit: 45 },
        { id: "board", title: qsTr("Board and power"), defaultLimit: 95 },
        { id: "other", title: qsTr("Other"), defaultLimit: 95 }
    ]

    readonly property var globalRules: [
        { match: "(^|-)(ibat|vbat|vph|bcl)", group: "hidden" },
        { match: "^socd?$", group: "hidden" },
        { match: "-lowf$", group: "hidden" },
        { match: "^lmh-dcvs", group: "hidden" },
        { match: "^zeroc-", group: "hidden" },
        { match: "max-step$", group: "hidden" }
    ]

    readonly property var msm8974Rules: [
        { match: "^cpu(\\d)-thermal$", group: "cpu", label: qsTr("Core %1") },
        { match: "^gpu-top-thermal$", group: "gpu", label: qsTr("GPU top") },
        { match: "^gpu-bottom-thermal$", group: "gpu", label: qsTr("GPU bottom") },
        { match: "^q6-dsp-thermal$", group: "modem", label: qsTr("Modem DSP") },
        { match: "^modemtx-thermal$", group: "modem", label: qsTr("Modem transmitter") },
        { match: "^video-thermal$", group: "media", label: qsTr("Video engine") },
        { match: "^wlan-thermal$", group: "wireless", label: qsTr("Wi-Fi") },
        { match: "^pm8941-thermal$", group: "board", label: qsTr("Main PMIC") },
        { match: "^pm8841-thermal$", group: "board", label: qsTr("CPU power PMIC") },
        { match: "^battery$", group: "battery", label: qsTr("Battery") }
    ]

    readonly property var msm8974HwmonRules: [
        { match: "^tmp108$", group: "board", label: qsTr("Board sensor") }
    ]

    readonly property var blairRules: [
        { match: "^cpu-0-(\\d)-(usr|step)$", group: "cpu", label: qsTr("Little core %1") },
        { match: "^cpu-1-(\\d)-(usr|step)$", group: "cpu", label: qsTr("Big cores, sensor %1") },
        { match: "^cpuss-(\\d)-usr$", group: "cpu", label: qsTr("CPU cluster %1") },
        { match: "^gpuss-(\\d)-usr$", group: "gpu", label: qsTr("GPU %1") },
        { match: "^ddr-usr$", group: "memory", label: qsTr("RAM") },
        { match: "^mdm-core(\\d)-(usr|step)$", group: "modem", label: qsTr("Modem core %1") },
        { match: "^mdm-vec-(usr|step)$", group: "modem", label: qsTr("Modem vector unit") },
        { match: "^(mdm|msm)-scl-(usr|step)$", group: "modem", label: qsTr("Modem scalar unit") },
        { match: "^modem-(\\d)-usr$", group: "modem", label: qsTr("Modem sensor %1") },
        { match: "^modem-streamer-usr$", group: "modem", label: qsTr("Modem streamer") },
        { match: "^modem-lte-sub6-pa(\\d)$", group: "modem", label: qsTr("LTE amplifier %1") },
        { match: "^pa[-_]therm(\\d)(-usr)?$", group: "modem", label: qsTr("Amplifier board sensor %1") },
        { match: "^modem-skin-usr$", group: "surface", label: qsTr("Skin near modem") },
        { match: "^(modem-mmw|beamer-)", group: "hidden" },
        { match: "^mapss-(\\d)-usr$", group: "board", label: qsTr("SoC subsystem MAPSS %1") },
        { match: "^cwlan-usr$", group: "wireless", label: qsTr("Wi-Fi") },
        { match: "^audio-usr$", group: "media", label: qsTr("Audio") },
        { match: "^video-usr$", group: "media", label: qsTr("Video engine") },
        { match: "^camera-usr$", group: "media", label: qsTr("Camera") },
        { match: "^q6-hvx-(usr|step)$", group: "media", label: qsTr("Compute DSP") },
        { match: "^cam_flash_therm$", group: "media", label: qsTr("Camera flash") },
        { match: "^pm6125_tz$", group: "board", label: qsTr("Main PMIC") },
        { match: "^pmr735a_tz$", group: "board", label: qsTr("RF PMIC") },
        { match: "^pm7250b_tz$", group: "battery", label: qsTr("Charger PMIC") },
        { match: "^msm_therm$", group: "board", label: qsTr("SoC board sensor") },
        { match: "^xo[-_]therm(-usr)?$", group: "board", label: qsTr("Crystal oscillator") },
        { match: "^chg_therm$", group: "battery", label: qsTr("Charger") },
        { match: "^chg_pump_therm$", group: "battery", label: qsTr("Charge pump") },
        { match: "^conn-therm-usr$", group: "battery", label: qsTr("USB connector") },
        { match: "^battery$", group: "battery", label: qsTr("Battery") },
        { match: "^(bms|mmi_battery)$", group: "hidden" },
        { match: "^quiet[-_]therm(-usr)?$", group: "surface", label: qsTr("Skin, quiet sensor") },
        { match: "^sdm-skin-therm-usr$", group: "surface", label: qsTr("Skin") },
        { match: "^chg-skin-therm-usr$", group: "surface", label: qsTr("Skin near charger") },
        { match: "^front_temp$", group: "surface", label: qsTr("Front") },
        { match: "^back_temp$", group: "surface", label: qsTr("Back") },
        { match: "^(rear-cam-therm-usr|flash-cam-therm-usr|camera-therm-usr|sony_cam_back0)$", group: "hidden" }
    ]

    readonly property var miamiOnlyRules: [
        { match: "^modem-streamer-usr$", group: "hidden" }
    ]

    readonly property var sm8250Rules: [
        { match: "^cpu-0-(\\d)-(usr|step)$", group: "cpu", label: qsTr("Little core %1") },
        { match: "^cpu-1-(\\d)-(usr|step)$", group: "cpu", label: qsTr("Big cores, sensor %1") },
        { match: "^cpuss-(\\d)-usr$", group: "cpu", label: qsTr("CPU cluster %1") },
        { match: "^gpuss-(\\d)-usr$", group: "gpu", label: qsTr("GPU %1") },
        { match: "^ddr-(usr|step)$", group: "memory", label: qsTr("RAM") },
        { match: "^pop-mem-step$", group: "memory", label: qsTr("RAM package") },
        { match: "^aoss-?(\\d)-usr$", group: "board", label: qsTr("Always-on subsystem %1") },
        { match: "^cwlan-(usr|step)$", group: "wireless", label: qsTr("Wi-Fi") },
        { match: "^wifi_therm$", group: "wireless", label: qsTr("Board near Wi-Fi") },
        { match: "^video-(usr|step)$", group: "media", label: qsTr("Video engine") },
        { match: "^q6-hvx-(usr|step)$", group: "media", label: qsTr("Compute DSP") },
        { match: "^camera-(usr|step)$", group: "media", label: qsTr("Camera") },
        { match: "^cmpss-(usr|step)$", group: "media", label: qsTr("Compute subsystem") },
        { match: "^npu-(usr|step)$", group: "media", label: qsTr("AI accelerator") },
        { match: "^flash_therm$", group: "media", label: qsTr("Camera flash") },
        { match: "^modem", group: "hidden" },
        { match: "^pm8150_tz$", group: "board", label: qsTr("Main PMIC") },
        { match: "^pm8150l_tz$", group: "board", label: qsTr("Secondary PMIC") },
        { match: "^xo_therm$", group: "board", label: qsTr("Crystal oscillator") },
        { match: "^cpu_therm$", group: "board", label: qsTr("Board near CPU") },
        { match: "^pm8150b_tz$", group: "battery", label: qsTr("Charger PMIC") },
        { match: "^charger_therm0$", group: "battery", label: qsTr("Charger") },
        { match: "^conn_therm$", group: "battery", label: qsTr("USB connector") },
        { match: "^battery$", group: "battery", label: qsTr("Battery") },
        { match: "^batt_slave_temp$", group: "battery", label: qsTr("Battery, second sensor") },
        { match: "^(batt_therm|bms)$", group: "hidden" },
        { match: "^quiet_therm$", group: "surface", label: qsTr("Skin, quiet sensor") },
        { match: "^backlight_therm$", group: "surface", label: qsTr("Display backlight") }
    ]

    readonly property var sdm845Rules: [
        { match: "^cpu(\\d)-silver-(usr|step)$", group: "cpu", label: qsTr("Little core %1") },
        { match: "^cpu(\\d)-gold-(usr|step)$", group: "cpu", label: qsTr("Big core %1") },
        { match: "^kryo-l3-(\\d)-usr$", group: "cpu", label: qsTr("L3 cache %1") },
        { match: "^gpu(\\d)-usr$", group: "gpu", label: qsTr("GPU %1") },
        { match: "^ddr-usr$", group: "memory", label: qsTr("RAM") },
        { match: "^pop-mem-step$", group: "memory", label: qsTr("RAM package") },
        { match: "^aoss(\\d)-usr$", group: "board", label: qsTr("Always-on subsystem %1") },
        { match: "^mdm-dsp-usr$", group: "modem", label: qsTr("Modem DSP") },
        { match: "^mdm-core-usr$", group: "modem", label: qsTr("Modem core") },
        { match: "^pa-therm1-adc$", group: "modem", label: qsTr("Amplifier board sensor 1") },
        { match: "^pa1-therml-adc$", group: "modem", label: qsTr("Amplifier board sensor 2") },
        { match: "^wlan-usr$", group: "wireless", label: qsTr("Wi-Fi") },
        { match: "^compute-hvx-usr$", group: "media", label: qsTr("Compute DSP") },
        { match: "^camera-usr$", group: "media", label: qsTr("Camera") },
        { match: "^mmss-usr$", group: "media", label: qsTr("Multimedia subsystem") },
        { match: "^pm8998_tz$", group: "board", label: qsTr("Main PMIC") },
        { match: "^pm8005_tz$", group: "board", label: qsTr("Secondary PMIC") },
        { match: "^xo-therm-adc$", group: "board", label: qsTr("Crystal oscillator") },
        { match: "^msm-therm-adc$", group: "board", label: qsTr("SoC board sensor") },
        { match: "^pmi8998_tz$", group: "battery", label: qsTr("Charger PMIC") },
        { match: "^battery$", group: "battery", label: qsTr("Battery") },
        { match: "^bms$", group: "hidden" },
        { match: "^quiet-therm-adc$", group: "surface", label: qsTr("Skin, quiet sensor") }
    ]

    readonly property var msm8226Rules: [
        { match: "^tsens_tz_sensor(\\d)$", group: "cpu", label: qsTr("SoC sensor %1"), wholeDegrees: true },
        { match: "^pm8226_tz$", group: "board", label: qsTr("PMIC") },
        { match: "^pa_therm(\\d)$", group: "modem", label: qsTr("Amplifier board sensor %1"), wholeDegrees: true }
    ]

    readonly property var titanOnlyRules: [
        { match: "^pa_therm0$", group: "hidden" }
    ]

    readonly property var mt8163Rules: [
        { match: "^mtktscpu$", group: "cpu", label: qsTr("CPU") },
        { match: "^mtkts(\\d)$", group: "cpu", label: qsTr("SoC sensor %1") },
        { match: "^mtktspmic$", group: "board", label: qsTr("PMIC") },
        { match: "^therm([0-2])_s$", group: "board", label: qsTr("Board sensor %1") },
        { match: "^(therm3_s|skin_virtual|case_virtual)$", group: "hidden" }
    ]

    readonly property var deviceZoneRules: ({
        "victara": msm8974Rules,
        "miami": miamiOnlyRules.concat(blairRules),
        "xqcc72": blairRules,
        "xqdc72": blairRules,
        "pipa": sm8250Rules,
        "enchilada": sdm845Rules,
        "fajita": sdm845Rules,
        "thea": msm8226Rules,
        "titan": titanOnlyRules.concat(msm8226Rules),
        "crown": mt8163Rules
    })

    readonly property var deviceHwmonRules: ({
        "victara": msm8974HwmonRules
    })

    function _read(path, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                callback(xhr.responseText || "")
        }
        xhr.open("GET", "file://" + path)
        xhr.send()
    }

    function _readAll(paths, callback) {
        var texts = new Array(paths.length)
        var remaining = paths.length

        if (remaining === 0) {
            callback(texts)
            return
        }

        paths.forEach(function(path, index) {
            _read(path, function(text) {
                texts[index] = text.trim()
                remaining -= 1

                if (remaining === 0)
                    callback(texts)
            })
        })
    }

    function _entries(model, prefix, root) {
        var dirs = []

        for (var i = 0; i < model.count; ++i) {
            var name = model.get(i, "fileName")
            if (name.indexOf(prefix) === 0)
                dirs.push(root + "/" + name)
        }

        return dirs
    }

    function _matchRule(rules, name) {
        for (var i = 0; i < rules.length; ++i) {
            var match = new RegExp(rules[i].match).exec(name)
            if (match) {
                return {
                    rule: rules[i],
                    order: i,
                    label: rules[i].label ? rules[i].label.arg(match[1] !== undefined ? match[1] : "") : name
                }
            }
        }

        return null
    }

    function _classifyZone(name) {
        var hidden = _matchRule(globalRules, name)
        if (hidden)
            return hidden

        var deviceMatch = _matchRule(deviceZoneRules[deviceName] || [], name)
        if (deviceMatch)
            return deviceMatch

        return { rule: { group: "other" }, order: 0, label: name }
    }

    function _groupFor(id) {
        for (var i = 0; i < groups.length; ++i) {
            if (groups[i].id === id)
                return groups[i]
        }

        return groups[groups.length - 1]
    }

    function _divisorFor(rule) {
        return rule.wholeDegrees ? 1 : 1000
    }

    function _tripLimit(texts, divisor) {
        var limit = NaN

        for (var i = 0; i + 1 < texts.length; i += 2) {
            var celsius = parseInt(texts[i], 10) / divisor
            var isLimitType = limitTripTypes.indexOf(texts[i + 1]) !== -1
            var isRealTrip = celsius >= minTripCelsius && celsius < placeholderTripCelsius

            if (isLimitType && isRealTrip && !(celsius >= limit))
                limit = celsius
        }

        return limit
    }

    function _tripPaths(dir) {
        var paths = []

        for (var i = 0; i < maxTripPoints; ++i) {
            paths.push(dir + "/trip_point_" + i + "_temp")
            paths.push(dir + "/trip_point_" + i + "_type")
        }

        return paths
    }

    function _scan() {
        var zoneDirs = _entries(thermalModel, "thermal_zone", thermalRoot)
        var hwmonDirs = (deviceHwmonRules[deviceName] || []).length > 0 ? _entries(hwmonModel, "hwmon", hwmonRoot) : []
        var namePaths = zoneDirs.map(function(dir) { return dir + "/type" })
            .concat(hwmonDirs.map(function(dir) { return dir + "/name" }))

        _readAll(namePaths, function(names) {
            var candidates = []

            zoneDirs.forEach(function(dir, index) {
                var classified = _classifyZone(names[index])
                if (classified.rule.group !== "hidden")
                    candidates.push({ dir: dir, tempPath: dir + "/temp", classified: classified })
            })

            hwmonDirs.forEach(function(dir, index) {
                var classified = _matchRule(deviceHwmonRules[deviceName], names[zoneDirs.length + index])
                if (classified && classified.rule.group !== "hidden")
                    candidates.push({ dir: dir, tempPath: dir + "/temp1_input", classified: classified })
            })

            _resolveLimits(candidates)
        })
    }

    function _resolveLimits(candidates) {
        var tripPaths = []

        candidates.forEach(function(candidate) {
            tripPaths = tripPaths.concat(_tripPaths(candidate.dir))
        })

        _readAll(tripPaths, function(texts) {
            var tripsPerSensor = maxTripPoints * 2

            candidates.forEach(function(candidate, index) {
                var sensorTrips = texts.slice(index * tripsPerSensor, (index + 1) * tripsPerSensor)
                candidate.tripLimit = _tripLimit(sensorTrips, _divisorFor(candidate.classified.rule))
            })

            _buildGroups(candidates)
        })
    }

    function _buildGroups(candidates) {
        var sensorsByKey = {}
        var sensors = []

        candidates.forEach(function(candidate) {
            var rule = candidate.classified.rule
            var key = rule.group + "/" + candidate.classified.label
            var existing = sensorsByKey[key]

            if (existing) {
                if (candidate.tripLimit < existing.tripLimit || isNaN(existing.tripLimit))
                    existing.tripLimit = candidate.tripLimit
                return
            }

            var sensor = {
                id: candidate.tempPath,
                group: rule.group,
                label: candidate.classified.label,
                order: candidate.classified.order,
                divisor: _divisorFor(rule),
                tripLimit: candidate.tripLimit
            }

            sensorsByKey[key] = sensor
            sensors.push(sensor)
        })

        sensors.forEach(function(sensor) {
            sensor.limit = isNaN(sensor.tripLimit) ? _groupFor(sensor.group).defaultLimit : sensor.tripLimit
        })

        sensors.sort(function(a, b) {
            return a.order - b.order || a.label.localeCompare(b.label)
        })

        var built = []

        groups.forEach(function(group) {
            var items = sensors.filter(function(sensor) { return sensor.group === group.id })
            if (items.length > 0)
                built.push({ title: group.title, items: items })
        })

        _sensors = sensors
        sensorGroups = built
        refresh()
    }

    function refresh() {
        if (_refreshing || _sensors.length === 0)
            return

        _refreshing = true

        _readAll(_sensors.map(function(sensor) { return sensor.id }), function(texts) {
            var updated = {}

            _sensors.forEach(function(sensor, index) {
                updated[sensor.id] = texts[index] === "" ? NaN : parseInt(texts[index], 10) / sensor.divisor
            })

            temperatures = updated
            _refreshing = false
        })
    }

    function _celsius(id) {
        var value = temperatures[id]
        return value === undefined ? NaN : value
    }

    function _isPlausible(celsius) {
        return celsius >= minPlausibleCelsius && celsius <= maxPlausibleCelsius
    }

    function _groupHasReadings(items) {
        for (var i = 0; i < items.length; ++i) {
            if (_isPlausible(_celsius(items[i].id)))
                return true
        }

        return false
    }

    function _loadDevice() {
        _read(hwReleasePath, function(text) {
            var match = /^MER_HA_DEVICE=["']?([^"'\n]+)/m.exec(text)
            deviceName = match ? match[1] : ""
            scanTimer.restart()
        })
    }

    Component.onCompleted: _loadDevice()

    FolderListModel {
        id: thermalModel

        folder: "file://" + page.thermalRoot
        showDirs: true
        showFiles: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onCountChanged: scanTimer.restart()
    }

    FolderListModel {
        id: hwmonModel

        folder: "file://" + page.hwmonRoot
        showDirs: true
        showFiles: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onCountChanged: scanTimer.restart()
    }

    Timer {
        id: scanTimer

        interval: page.scanDelay
        onTriggered: page._scan()
    }

    Timer {
        interval: page.refreshInterval
        repeat: true
        running: page.status === PageStatus.Active && Qt.application.active && page._sensors.length > 0
        onTriggered: page.refresh()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: content

            width: parent.width

            PageHeader {
                title: qsTr("Temperatures")
            }

            InfoLabel {
                visible: page.sensorGroups.length === 0
                text: qsTr("No temperature sensors found")
            }

            Repeater {
                model: page.sensorGroups

                Column {
                    id: groupColumn

                    property var group: modelData

                    width: content.width
                    visible: page._groupHasReadings(group.items)

                    SectionHeader {
                        text: groupColumn.group.title
                    }

                    Repeater {
                        model: groupColumn.group.items

                        Item {
                            id: sensorRow

                            property var sensor: modelData
                            property real celsius: page._celsius(sensor.id)
                            property real fillRange: sensor.limit - page.barFloorCelsius
                            property real fill: Math.max(0, Math.min(1, (celsius - page.barFloorCelsius) / fillRange))
                            property bool nearLimit: celsius >= sensor.limit - page.warningMarginCelsius

                            width: groupColumn.width
                            height: visible ? nameLabel.height + bar.height + limitLabel.height + Theme.paddingMedium * 2 : 0
                            visible: page._isPlausible(celsius)

                            Label {
                                id: nameLabel

                                anchors {
                                    top: parent.top
                                    topMargin: Theme.paddingMedium
                                    left: parent.left
                                    leftMargin: Theme.horizontalPageMargin
                                    right: valueLabel.left
                                    rightMargin: Theme.paddingMedium
                                }

                                text: sensorRow.sensor.label
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                id: valueLabel

                                anchors {
                                    baseline: nameLabel.baseline
                                    right: parent.right
                                    rightMargin: Theme.horizontalPageMargin
                                }

                                text: qsTr("%1 °C").arg(sensorRow.celsius.toFixed(1))
                                color: sensorRow.nearLimit ? Theme.errorColor : Theme.highlightColor
                            }

                            Rectangle {
                                id: bar

                                anchors {
                                    top: nameLabel.bottom
                                    topMargin: Theme.paddingSmall
                                    left: nameLabel.left
                                    right: valueLabel.right
                                }

                                height: Theme.paddingSmall
                                radius: height / 2
                                color: Theme.rgba(Theme.highlightBackgroundColor, Theme.opacityFaint)

                                Rectangle {
                                    width: parent.width * sensorRow.fill
                                    height: parent.height
                                    radius: parent.radius
                                    color: sensorRow.nearLimit ? Theme.errorColor : Theme.highlightColor
                                }
                            }

                            Label {
                                id: limitLabel

                                anchors {
                                    top: bar.bottom
                                    topMargin: Theme.paddingSmall
                                    left: bar.left
                                }

                                text: qsTr("Limit %1 °C").arg(sensorRow.sensor.limit)
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }
                        }
                    }
                }
            }
        }
    }
}
