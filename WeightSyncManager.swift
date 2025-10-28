import Foundation
import CoreBluetooth
import UserNotifications
import Combine

class WeightSyncManager: NSObject, ObservableObject {

    @Published var weightHistory: [WeightEntry] = []
    @Published var isScanning: Bool = false

    private var centralManager: CBCentralManager!
    private var miScalePeripheral: CBPeripheral?

    private let weightServiceUUID = CBUUID(string: "181D")
    private let weightMeasurementCharacteristicUUID = CBUUID(string: "2A9D")

    private var completionHandler: (() -> Void)?
    private var scanTimeoutWorkItem: DispatchWorkItem?

    func startSync(completion: (() -> Void)? = nil) {
        guard !isScanning else { return }
        self.completionHandler = completion
        self.isScanning = true
        centralManager = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: true])

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.isScanning {
                self.stopScanning()
                self.notifyUser(success: false, message: "Nie wykryto danych z wagi.")
                self.completionHandler?()
            }
        }
        scanTimeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }

    private func stopScanning() {
        isScanning = false
        scanTimeoutWorkItem?.cancel()
        scanTimeoutWorkItem = nil
        centralManager?.stopScan()
        if let peripheral = miScalePeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }

    private func parseWeightData(_ data: Data) -> Double? {
        guard data.count >= 3 else { return nil }
        let flags = data[0]
        let isLb = (flags & 0x01) != 0
        let weightRaw = UInt16(data[1]) | (UInt16(data[2]) << 8)
        if isLb {
            let pounds = Double(weightRaw) / 100.0
            return pounds * 0.45359237
        } else {
            return Double(weightRaw) * 0.005
        }
    }

    private func saveWeight(weight: Double) {
        let entry = WeightEntry(date: Date(), weight: weight)
        DispatchQueue.main.async {
            self.weightHistory.insert(entry, at: 0)
        }
    }

    private func notifyUser(success: Bool, message: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = success ? "Synchronizacja zakończona" : "Synchronizacja nie powiodła się"
        content.body = message ?? (success ? "Odczytano wagę z urządzenia." : "Spróbuj ponownie.")
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension WeightSyncManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: [weightServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        default:
            print("Bluetooth state: \(central.state.rawValue)")
            isScanning = false
            completionHandler?()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        miScalePeripheral = peripheral
        miScalePeripheral?.delegate = self
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([weightServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Nie udało się połączyć: \(String(describing: error))")
        stopScanning()
        notifyUser(success: false, message: "Błąd połączenia z wagą.")
        completionHandler?()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        stopScanning()
    }
}

extension WeightSyncManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { print("Błąd usług: \(error)") }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == weightServiceUUID {
            peripheral.discoverCharacteristics([weightMeasurementCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { print("Błąd charakterystyk: \(error)") }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == weightMeasurementCharacteristicUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error { print("Błąd subskrypcji: \(error)") }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { print("Błąd odczytu: \(error)") }
        guard let value = characteristic.value else { return }
        guard let weightKg = parseWeightData(value) else { return }

        saveWeight(weight: weightKg)
        notifyUser(success: true, message: String(format: "Odczytano %.2f kg.", weightKg))

        DispatchQueue.main.async {
            self.stopScanning()
            self.completionHandler?()
        }
    }
}
