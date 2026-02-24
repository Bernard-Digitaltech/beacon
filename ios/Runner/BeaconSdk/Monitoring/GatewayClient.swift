import Foundation
import UIKit

class GatewayClient {

  private var config: BeaconConfig?
  private let session: URLSession
  private let sdkTracker = SdkTracker()
  private let prefs = PreferenceStore()
  
  typealias JSONCallback = ([String: Any]) -> Void
  typealias BeaconsCallback = ([String: String]) -> Void
  typealias GatewayCallback = (Result<[String: Any], Error>) -> Void

  init() {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 10.0
    sessionConfig.timeoutIntervalForResource = 10.0
    self.session = URLSession(configuration: sessionConfig)
  }

  func configure(_ config: BeaconConfig) {
    self.config = config
  }

  func fetchBeacons(completion: @escaping BeaconsCallback) {
    guard let dataUrlString = config?.dataUrl.trimmingCharacters(in: .whitespacesAndNewlines),
          let url = URL(string: dataUrlString),
          dataUrlString.hasPrefix("http") else {
      Logger.e("Invalid data URL")
      completion(prefs.getTargetBeacons())
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let task = session.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self else { return }

      if let error = error {
        self.handleNetworkError(error, context: "Fetch Beacons")
        completion(self.prefs.getTargetBeacons())
        return
      }

      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data else {
        Logger.e("Failed to fetch beacons, status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        completion(self.prefs.getTargetBeacons())
        return
      }

      do {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let dataArray = json["data"] as? [[String: Any]] {
          
          var beaconMap: [String: String] = [:]
          
          for item in dataArray {
            if let uuid = item["beacon_uuid"] as? String,
               let name = item["location_name"] as? String {
                let major = item["beacon_major"] as? Int
                let minor = item["beacon_minor"] as? Int

                var key = uuid.uppercased()

                if let maj = major, let min = minor {
                  key = "\(uuid.uppercased()):\(maj):\(min)"
                  Logger.d("📡 Mapped: \(key) -> \(name)")
                } else {
                  Logger.d("📡 Mapped: \(key) (Region Only) -> \(name)")
                }

                beaconMap[key] = name
              }
          }
            
          Logger.i("Fetched \(beaconMap.count) beacons from server")
          self.prefs.saveTargets(beaconMap)
          completion(beaconMap)
        } else {
          ompletion(self.prefs.getTargetBeacons())
        }
      } catch {
        self.handleNetworkError(error, context: "JSON Parse")
        completion(self.prefs.getTargetBeacons())
      }
    }
    task.resume()
  }

  // func sendDetection(mac: String, rssi: Int, timestamp: Int, battery: Int? = nil, isInitial: Bool = true, completion: @escaping JSONCallback) {
  //     guard let config = config else { return }
      
  //     let components = mac.components(separatedBy: ":")
  //     let uuid = components[0]
  //     let major = components.count > 1 ? Int(components[1]) : nil
  //     let minor = components.count > 2 ? Int(components[2]) : nil

  //     let body: [String: Any] = [
  //       "type": "beacon_detection",
  //       "user_id": config.userId,
  //       "phone_id": getDeviceId(),

  //       // Send separated fields 
  //       "beacon_uuid": uuid,
  //       "major": major ?? NSNull(),
  //       "minor": minor ?? NSNull(),

  //       "beacon_mac": mac,
  //       "rssi": rssi,
  //       "battery": battery ?? NSNull(), 
  //       "is_initial": isInitial,
  //       "timestamp": getKLTimestamp()  
  //     ]
      
  //     executeRequest(body: body) { result in
  //     switch result {
  //     case .success(let json):
  //       completion(json)
  //     case .failure(_):
  //       completion([:])
  //     }
  //   }
  // }

  // func sendEvent(_ eventType: String, data: [String: Any]) {
  //   guard let config = config else { return }
    
  //   let body: [String: Any] = [
  //     "type": "gateway_event",
  //     "event_type": eventType,
  //     "user_id": config.userId,
  //     "phone_id": getDeviceId(),
  //     "details": data,
  //     "timestamp": getKLTimestamp()
  //   ]
    
  //   executeRequest(body: body) { _ in }
  // }

  // private func executeRequest(body: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
  //   guard let gatewayUrlString = config?.gatewayUrl.trimmingCharacters(in: .whitespacesAndNewlines),
  //         let url = URL(string: gatewayUrlString),
  //         gatewayUrlString.hasPrefix("http") else {
  //     completion(.failure(NSError(domain: "Gateway", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
  //     return
  //   }

  //   var request = URLRequest(url: url)
  //   request.httpMethod = "POST"
  //   request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
  //   request.setValue("application/json", forHTTPHeaderField: "Accept")
    
  //   do {
  //     request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
  //     Logger.i("📤 [Gateway] Sending \(body["type"] ?? "unknown"): \(body)")
  //   } catch {
  //     Logger.e("Failed to serialize JSON")
  //     return
  //   }

  //   let task = session.dataTask(with: request) { [weak self] data, response, error in
  //     guard let self = self else { return }

  //     if let error = error {
  //       self.handleNetworkError(error, context: "Gateway Transport")
  //       completion(.failure(error))
  //       return
  //     }

  //     guard let httpResponse = response as? HTTPURLResponse else { return }

  //     var responseJSON: [String: Any] = [:]
  //     if let data = data {
  //       responseJSON = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
  //     }

  //     if (200...299).contains(httpResponse.statusCode) {
  //       completion(.success(responseJSON))
  //     } else {
  //       let msg = "HTTP \(httpResponse.statusCode)"
  //       Logger.e("Gateway error: \(msg)")
  //       completion(.failure(NSError(domain: "Gateway", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
  //     }
  //   }
  //   task.resume()
  // }

  private func handleNetworkError(_ error: Error, context: String) {
    sdkTracker.error(.networkError, "\(context) error: \(error.localizedDescription)", error)
    Logger.e("\(context) error: \(error.localizedDescription)")
  }

  private func getDeviceId() -> String {
    return UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
  }

  private func getKLTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")
    return formatter.string(from: Date())
  }
}