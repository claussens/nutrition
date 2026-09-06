import Foundation
import HealthKit

// Read-only HealthKit access: body mass, body fat percentage and active
// energy feed the profile. The app never writes to HealthKit, and the
// NSHealthShareUsageDescription in project.yml promises exactly this set,
// so a new read type here means new copy there too.
struct HealthStore {

    private enum HealthkitSetupError: Error {
        case notAvailableOnDevice
        case dataTypeNotAvailable
    }

    static func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void) {

        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthkitSetupError.notAvailableOnDevice)
            return
        }

        guard let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let bodyFatPercentage = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(false, HealthkitSetupError.dataTypeNotAvailable)
            return
        }

        let typesToRead = Set([ bodyMass, bodyFatPercentage, activeEnergy ])

        HKHealthStore().requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            completion(success, error)
        }
    }

    static func getMostRecentSample(sampleType: HKSampleType,
                                    startDate: Date = Date.distantPast,
                                    endDate: Date = Date(),
                                    completion: @escaping (HKQuantitySample?, Error?) -> Swift.Void) {

        // 1. Use HKQuery to load the most recent samples.
        let mostRecentPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: mostRecentPredicate, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in

            // 2. Always dispatch to the main thread when complete
            DispatchQueue.main.async {
                guard let samples = samples,
                      let sample = samples.first as? HKQuantitySample else {
                    completion(nil, error)
                    return
                }
                completion(sample, nil)
            }
        }

        HKHealthStore().execute(sampleQuery)
    }
}
