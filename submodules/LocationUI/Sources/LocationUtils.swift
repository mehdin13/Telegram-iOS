import Foundation
import SwiftSignalKit
import SyncCore
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import MapKit
import AccountContext

extension TelegramMediaMap {
    convenience init(coordinate: CLLocationCoordinate2D, liveBroadcastingTimeout: Int32? = nil, proximityNotificationRadius: Int32? = nil) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: liveBroadcastingTimeout, liveProximityNotificationRadius: proximityNotificationRadius)
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}

extension MKMapRect {
    init(region: MKCoordinateRegion) {
        let point1 = MKMapPoint(CLLocationCoordinate2D(latitude: region.center.latitude + region.span.latitudeDelta / 2.0, longitude: region.center.longitude - region.span.longitudeDelta / 2.0))
        let point2 = MKMapPoint(CLLocationCoordinate2D(latitude: region.center.latitude - region.span.latitudeDelta / 2.0, longitude: region.center.longitude + region.span.longitudeDelta / 2.0))
        self = MKMapRect(x: min(point1.x, point2.x), y: min(point1.y, point2.y), width: abs(point1.x - point2.x), height: abs(point1.y - point2.y))
    }
}

extension CLLocationCoordinate2D: Equatable {

}

public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}

public func nearbyVenues(context: AccountContext, latitude: Double, longitude: Double, query: String? = nil) -> Signal<[TelegramMediaMap], NoError> {
    return context.account.postbox.transaction { transaction -> SearchBotsConfiguration in
        return currentSearchBotsConfiguration(transaction: transaction)
    } |> mapToSignal { searchBotsConfiguration in
        return context.engine.peers.resolvePeerByName(name: searchBotsConfiguration.venueBotUsername ?? "foursquare")
        |> take(1)
        |> mapToSignal { peerId -> Signal<ChatContextResultCollection?, NoError> in
            guard let peerId = peerId else {
                return .single(nil)
            }
            return requestChatContextResults(account: context.account, botId: peerId, peerId: context.account.peerId, query: query ?? "", location: .single((latitude, longitude)), offset: "")
            |> map { results -> ChatContextResultCollection? in
                return results?.results
            }
            |> `catch` { error -> Signal<ChatContextResultCollection?, NoError> in
                return .single(nil)
            }
        }
        |> map { contextResult -> [TelegramMediaMap] in
            guard let contextResult = contextResult else {
                return []
            }
            var list: [TelegramMediaMap] = []
            for result in contextResult.results {
                switch result.message {
                    case let .mapLocation(mapMedia, _):
                        if let _ = mapMedia.venue {
                            list.append(mapMedia)
                        }
                    default:
                        break
                }
            }
            return list
        }
    }
}

func stringForEstimatedDuration(strings: PresentationStrings, eta: Double) -> String? {
    if eta > 0.0 && eta < 60.0 * 60.0 * 10.0 {
        let eta = max(eta, 60.0)
        let minutes = Int32(eta / 60.0) % 60
        let hours = Int32(eta / 3600.0)
        
        let string: String
        if hours > 1 {
            if hours == 1 && minutes == 0 {
                string = strings.Map_ETAHours(1)
            } else {
                string = strings.Map_ETAHours(10).replacingOccurrences(of: "10", with: String(format: "%d:%02d", arguments: [hours, minutes]))
            }
        } else {
            string = strings.Map_ETAMinutes(minutes)
        }
        return strings.Map_DirectionsDriveEta(string).0
    } else {
        return nil
    }
}

func throttledUserLocation(_ userLocation: Signal<CLLocation?, NoError>) -> Signal<CLLocation?, NoError> {
    return userLocation
    |> reduceLeft(value: nil) { current, updated, emit -> CLLocation? in
        if let current = current {
            if let updated = updated {
                if updated.distance(from: current) > 250 || (updated.horizontalAccuracy < 50.0 && updated.horizontalAccuracy < current.horizontalAccuracy) {
                    emit(updated)
                    return updated
                } else {
                    return current
                }
            } else {
                return current
            }
        } else {
            if let updated = updated, updated.horizontalAccuracy > 0.0 {
                emit(updated)
                return updated
            } else {
                return nil
            }
        }
    }
}

func driveEta(coordinate: CLLocationCoordinate2D) -> Signal<Double?, NoError> {
    return Signal { subscriber in
        let destinationPlacemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
        let destination = MKMapItem(placemark: destinationPlacemark)
        
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        directions.calculateETA { response, error in
            subscriber.putNext(response?.expectedTravelTime)
            subscriber.putCompletion()
        }
        return ActionDisposable {
            directions.cancel()
        }
    }
}
