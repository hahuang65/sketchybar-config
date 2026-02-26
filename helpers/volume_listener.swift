import Cocoa
import Foundation

/// Listens for BetterDisplay OSD distributed notifications and triggers
/// sketchybar bd_volume_change events with the volume percentage as INFO.
///
/// BetterDisplay must have "OSD integration notifications" enabled in:
///   Settings > Application > Integration
///
/// Notification: com.betterdisplay.BetterDisplay.osd
/// Payload (JSON in notification.object):
///   { "controlTarget": "volume"|"mute", "value": 0-maxValue, "maxValue": N, ... }

struct OsdNotification: Codable {
    var displayID: Int?
    var systemIconID: Int?
    var controlTarget: String?
    var value: Double?
    var maxValue: Double?
    var lock: Bool?
    var text: String?
}

let sketchybarPath = "/opt/homebrew/bin/sketchybar"

func triggerSketchybar(volume: Int) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: sketchybarPath)
    task.arguments = ["--trigger", "bd_volume_change", "INFO=\(volume)"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try? task.run()
}

class OsdObserver: NSObject {
    func start() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleOsd(_:)),
            name: NSNotification.Name("com.betterdisplay.BetterDisplay.osd"),
            object: nil
        )
    }

    @objc func handleOsd(_ notification: Notification) {
        guard let json = notification.object as? String,
              let data = json.data(using: .utf8),
              let osd = try? JSONDecoder().decode(OsdNotification.self, from: data)
        else { return }

        switch osd.controlTarget {
        case "volume":
            let maxVal = osd.maxValue ?? 1.0
            let pct = Int(((osd.value ?? 0.0) / maxVal) * 100.0)
            triggerSketchybar(volume: pct)
        case "mute":
            let muted = (osd.value ?? 0.0) > 0.5
            if muted {
                triggerSketchybar(volume: 0)
            } else {
                // Unmuted — trigger without INFO so volume.sh does a full update
                let task = Process()
                task.executableURL = URL(fileURLWithPath: sketchybarPath)
                task.arguments = ["--trigger", "bd_volume_change"]
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                try? task.run()
            }
        default:
            break
        }
    }
}

let observer = OsdObserver()
observer.start()

// Keep the run loop alive
RunLoop.main.run()
