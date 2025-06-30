//
//  ErrorView.swift
//  LostArchiveTV
//
//  Created by PJ Gray on 4/19/25.
//

import SwiftUI

struct ErrorView: View {
    private let errorType: ErrorType
    let onRetryTapped: () -> Void
    
    // For backward compatibility, keep the string initializer
    init(error: String, onRetryTapped: @escaping () -> Void) {
        self.errorType = .string(error)
        self.onRetryTapped = onRetryTapped
    }
    
    // New initializer for NetworkError types
    init(error: NetworkError, onRetryTapped: @escaping () -> Void) {
        self.errorType = .network(error)
        self.onRetryTapped = onRetryTapped
    }
    
    private enum ErrorType {
        case string(String)
        case network(NetworkError)
    }
    
    private var iconName: String {
        switch errorType {
        case .string:
            return "exclamationmark.circle"
        case .network(let error):
            switch error {
            case .connectionError, .noInternetConnection:
                return "wifi.slash"
            case .timeout:
                return "clock.badge.exclamationmark"
            case .serverError:
                return "exclamationmark.triangle"
            case .invalidResponse, .parsingError, .invalidURL, .noData:
                return "exclamationmark.circle"
            case .contentUnavailable:
                return "video.slash"
            }
        }
    }
    
    private var buttonText: String {
        switch errorType {
        case .string:
            return "Try Again"
        case .network(let error):
            switch error {
            case .connectionError, .noInternetConnection:
                return "Check Connection"
            case .timeout:
                return "Try Again"
            case .serverError:
                return "Retry"
            case .invalidResponse, .parsingError, .invalidURL, .noData:
                return "Try Again"
            case .contentUnavailable:
                return "Try Another Video"
            }
        }
    }
    
    private var errorMessage: String {
        switch errorType {
        case .string(let message):
            return message
        case .network(let error):
            return error.localizedDescription
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Error icon
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(.red)
                .padding(.bottom, 10)
            
            // Error title
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            // Error message
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Retry button
            Button(action: onRetryTapped) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                    Text(buttonText)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.top, 10)
        }
        .padding()
    }
}

#Preview("String Error") {
    ErrorView(error: "Failed to load video metadata") {}
        .preferredColorScheme(.dark)
        .background(Color.black)
}

#Preview("Connection Error") {
    ErrorView(error: NetworkError.noInternetConnection) {}
        .preferredColorScheme(.dark)
        .background(Color.black)
}

#Preview("Timeout Error") {
    ErrorView(error: NetworkError.timeout) {}
        .preferredColorScheme(.dark)
        .background(Color.black)
}

#Preview("Server Error") {
    ErrorView(error: NetworkError.serverError(statusCode: 500, message: "Internal server error")) {}
        .preferredColorScheme(.dark)
        .background(Color.black)
}
