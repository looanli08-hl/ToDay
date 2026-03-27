import Foundation
import Photos

final class PhotoService {
    func requestAuthorization() async -> Bool {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch currentStatus {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    continuation.resume(returning: status == .authorized || status == .limited)
                }
            }
        default:
            return false
        }
    }

    func fetchPhotos(for date: Date) async -> [PhotoReference] {
        guard await requestAuthorization() else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
            PHAssetMediaType.image.rawValue,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: options)
        var results: [PhotoReference] = []
        results.reserveCapacity(assets.count)

        assets.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate else { return }

            let coordinate = asset.location.map {
                CoordinateValue(
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude
                )
            }

            results.append(
                PhotoReference(
                    id: asset.localIdentifier,
                    creationDate: creationDate,
                    location: coordinate,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight
                )
            )
        }

        return results
    }
}
