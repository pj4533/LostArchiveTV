import Foundation

/// Represents unrecoverable content-related errors that should trigger video skipping
enum VideoContentError: Error, LocalizedError {
    /// The video file was not found (404 from Archive.org)
    case fileNotFound
    
    /// The video file exists but is corrupted or damaged
    case corruptedContent
    
    /// The video format is not supported or playable
    case unsupportedFormat
    
    /// Access to the content is restricted or removed
    case accessRestricted
    
    /// Required video metadata is missing or invalid
    case invalidMetadata
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Video file not found"
        case .corruptedContent:
            return "Video content is corrupted"
        case .unsupportedFormat:
            return "Video format not supported"
        case .accessRestricted:
            return "Access to video is restricted"
        case .invalidMetadata:
            return "Video metadata is invalid"
        }
    }
}

extension Error {
    /// Determines if this error represents an unrecoverable content issue
    var isContentError: Bool {
        // Check if it's already a VideoContentError
        if self is VideoContentError {
            return true
        }
        
        // Check for HTTP status codes indicating content issues
        if let urlError = self as? URLError {
            switch urlError.code {
            case .fileDoesNotExist,
                 .resourceUnavailable,
                 .dataNotAllowed:
                return true
            default:
                break
            }
        }
        
        // Check NSError for AVFoundation errors
        let nsError = self as NSError
        
        // AVFoundation error domain
        if nsError.domain == "AVFoundationErrorDomain" {
            switch nsError.code {
            case -11800, // AVErrorUnknown - often indicates corrupt content
                 -11828, // AVErrorFileFormatNotRecognized
                 -11829, // AVErrorFormatUnsupported
                 -11831, // AVErrorContentIsNotAuthorized
                 -11833, // AVErrorApplicationIsNotAuthorized
                 -11835, // AVErrorContentIsProtected
                 -11863, // AVErrorContentIsUnavailable
                 -11819: // AVErrorMediaServicesWereReset
                return true
            default:
                break
            }
        }
        
        // Check for HTTP status codes in userInfo
        if let httpResponse = nsError.userInfo[NSURLErrorFailingURLResponseErrorKey] as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 404, // Not Found
                 403, // Forbidden
                 410, // Gone
                 451: // Unavailable For Legal Reasons
                return true
            default:
                break
            }
        }
        
        return false
    }
    
    /// Determines if this error represents a network or buffering issue
    var isNetworkError: Bool {
        // Check for URLError network-related codes
        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed,
                 .requestBodyStreamExhausted:
                return true
            default:
                break
            }
        }
        
        // Check NSError for network-related errors
        let nsError = self as NSError
        
        // AVFoundation network errors
        if nsError.domain == "AVFoundationErrorDomain" {
            switch nsError.code {
            case -11847, // AVErrorNoLongerPlayable - often network related
                 -11820, // AVErrorServerIncorrectlyConfigured
                 -11821: // AVErrorApplicationIsNotAuthorizedToUseDevice
                return true
            default:
                break
            }
        }
        
        // POSIX errors that indicate network issues
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case 54, // ECONNRESET - Connection reset by peer
                 57, // ENOTCONN - Socket is not connected
                 60, // ETIMEDOUT - Operation timed out
                 61: // ECONNREFUSED - Connection refused
                return true
            default:
                break
            }
        }
        
        // Check for temporary server errors (5xx status codes)
        if let httpResponse = nsError.userInfo[NSURLErrorFailingURLResponseErrorKey] as? HTTPURLResponse {
            return (500...599).contains(httpResponse.statusCode)
        }
        
        return false
    }
}