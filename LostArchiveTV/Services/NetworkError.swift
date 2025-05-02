//
//  NetworkError.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import Foundation

// Network errors for better error handling
enum NetworkError: Error {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case parsingError(message: String)
    case invalidURL
    case noData
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .parsingError(let message):
            return "Failed to parse server response: \(message)"
        case .invalidURL:
            return "The URL is invalid"
        case .noData:
            return "No data was returned from the server"
        }
    }
}