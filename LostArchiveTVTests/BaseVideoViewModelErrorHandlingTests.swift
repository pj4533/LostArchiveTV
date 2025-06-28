//
//  BaseVideoViewModelErrorHandlingTests.swift
//  LostArchiveTVTests
//
//  Created by Claude on 6/28/25.
//

import Testing
import Foundation
@testable import LATV

/// Tests for improved error handling in BaseVideoViewModel
@Suite("BaseVideoViewModel Error Handling")
struct BaseVideoViewModelErrorHandlingTests {
    
    @Test("Handle NetworkError connection errors with actionable messages")
    @MainActor func testConnectionErrorHandling() {
        let viewModel = TestableBaseVideoViewModel()
        
        // Test connection error
        let connectionError = NetworkError.connectionError(message: "Failed to connect to host")
        viewModel.handleError(connectionError)
        
        #expect(viewModel.errorMessage == "Connection failed: Failed to connect to host")
        #expect(viewModel.hasConnectionError == true)
    }
    
    @Test("Handle NetworkError timeout with user-friendly message")
    @MainActor func testTimeoutErrorHandling() {
        let viewModel = TestableBaseVideoViewModel()
        
        let timeoutError = NetworkError.timeout
        viewModel.handleError(timeoutError)
        
        #expect(viewModel.errorMessage == "The request timed out. Please check your connection and try again.")
        #expect(viewModel.hasConnectionError == true)
    }
    
    @Test("Handle NetworkError no internet connection")
    @MainActor func testNoInternetErrorHandling() {
        let viewModel = TestableBaseVideoViewModel()
        
        let noInternetError = NetworkError.noInternetConnection
        viewModel.handleError(noInternetError)
        
        #expect(viewModel.errorMessage == "No internet connection. Please check your network settings and try again.")
        #expect(viewModel.hasConnectionError == true)
    }
    
    @Test("Handle server errors with context-specific messages")
    @MainActor func testServerErrorHandling() {
        let viewModel = TestableBaseVideoViewModel()
        
        // Test 500 server error
        let serverError500 = NetworkError.serverError(statusCode: 500, message: "Internal Server Error")
        viewModel.handleError(serverError500)
        
        #expect(viewModel.errorMessage == "Server is temporarily unavailable. Please try again in a moment.")
        #expect(viewModel.hasConnectionError == false)
        
        // Test 404 error
        let serverError404 = NetworkError.serverError(statusCode: 404, message: "Not Found")
        viewModel.handleError(serverError404)
        
        #expect(viewModel.errorMessage == "The requested video could not be found. Trying another video...")
        #expect(viewModel.hasConnectionError == false)
        
        // Test other server error
        let serverError400 = NetworkError.serverError(statusCode: 400, message: "Bad Request")
        viewModel.handleError(serverError400)
        
        #expect(viewModel.errorMessage == "Server error (400): Bad Request")
        #expect(viewModel.hasConnectionError == false)
    }
    
    @Test("Handle generic errors with fallback message")
    @MainActor func testGenericErrorHandling() {
        let viewModel = TestableBaseVideoViewModel()
        
        let genericError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Generic test error"])
        viewModel.handleError(genericError)
        
        #expect(viewModel.errorMessage == "Error loading video: Generic test error")
        #expect(viewModel.hasConnectionError == false)
    }
    
    @Test("Clear error message functionality")
    @MainActor func testClearError() {
        let viewModel = TestableBaseVideoViewModel()
        
        // Set an error first
        let error = NetworkError.timeout
        viewModel.handleError(error)
        #expect(viewModel.errorMessage != nil)
        
        // Clear the error
        viewModel.clearError()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasConnectionError == false)
    }
    
    @Test("Connection error detection accuracy")
    @MainActor func testConnectionErrorDetection() {
        let viewModel = TestableBaseVideoViewModel()
        
        // Test various connection-related error messages
        viewModel.errorMessage = "Connection failed: Network unreachable"
        #expect(viewModel.hasConnectionError == true)
        
        viewModel.errorMessage = "No internet connection available"
        #expect(viewModel.hasConnectionError == true)
        
        viewModel.errorMessage = "Network request timed out"
        #expect(viewModel.hasConnectionError == true)
        
        viewModel.errorMessage = "Failed to parse JSON response"
        #expect(viewModel.hasConnectionError == false)
        
        viewModel.errorMessage = nil
        #expect(viewModel.hasConnectionError == false)
    }
}

/// Testable subclass of BaseVideoViewModel for testing purposes
@MainActor
private class TestableBaseVideoViewModel: BaseVideoViewModel {
    // Just inherits from BaseVideoViewModel to test the error handling methods
}