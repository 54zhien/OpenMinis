@main struct EEDCStorageModeTests {
    static func main() {
        precondition(EEDCStorageMode.choose(previousLocal: false, groupAvailable: true) == .shared)
        precondition(EEDCStorageMode.choose(previousLocal: false, groupAvailable: false) == .local)
        precondition(EEDCStorageMode.choose(previousLocal: true, groupAvailable: true) == .local)
        print("Storage mode tests passed")
    }
}
