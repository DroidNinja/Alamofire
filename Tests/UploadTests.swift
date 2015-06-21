// UploadTests.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Alamofire
import Foundation
import XCTest

class UploadDataTestCase: BaseTestCase {
    func testUploadDataRequest() {
        // Given
        let URLString = "http://httpbin.org/post"
        let data = "Lorem ipsum dolor sit amet".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let expectation = expectationWithDescription("Upload request should succeed: \(URLString)")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var error: NSError?

        // When
        Alamofire.upload(.POST, URLString, data)
            .response { responseRequest, responseResponse, _, responseError in
                request = responseRequest
                response = responseResponse
                error = responseError

                expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNil(error, "error should be nil")
    }

    func testUploadDataRequestWithProgress() {
        // Given
        let URLString = "http://httpbin.org/post"
        let data: NSData = {
            var text = ""
            for _ in 1...3_000 {
                text += "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
            }

            return text.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        }()

        let expectation = expectationWithDescription("Bytes upload progress should be reported: \(URLString)")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var responseRequest: NSURLRequest?
        var responseResponse: NSHTTPURLResponse?
        var responseData: AnyObject?
        var responseError: NSError?

        // When
        let upload = Alamofire.upload(.POST, URLString, data)
        upload.progress { bytesWritten, totalBytesWritten, totalBytesExpectedToWrite in
            let bytes = (bytes: bytesWritten, totalBytes: totalBytesWritten, totalBytesExpected: totalBytesExpectedToWrite)
            byteValues.append(bytes)

            let progress = (completedUnitCount: upload.progress.completedUnitCount, totalUnitCount: upload.progress.totalUnitCount)
            progressValues.append(progress)
        }
        upload.response { request, response, data, error in
            responseRequest = request
            responseResponse = response
            responseData = data
            responseError = error

            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(responseRequest, "response request should not be nil")
        XCTAssertNotNil(responseResponse, "response response should not be nil")
        XCTAssertNotNil(responseData, "response data should not be nil")
        XCTAssertNil(responseError, "response error should be nil")

        XCTAssertEqual(byteValues.count, progressValues.count, "byteValues count should equal progressValues count")

        if byteValues.count == progressValues.count {
            for index in 0..<byteValues.count {
                let byteValue = byteValues[index]
                let progressValue = progressValues[index]

                XCTAssertGreaterThan(byteValue.bytes, 0, "reported bytes should always be greater than 0")
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount, "total bytes should be equal to completed unit count")
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount, "total bytes expected should be equal to total unit count")
            }
        }

        if let
            lastByteValue = byteValues.last,
            lastProgressValue = progressValues.last
        {
            let byteValueFractionalCompletion = Double(lastByteValue.totalBytes) / Double(lastByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastProgressValue.0) / Double(lastProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0, "byte value fractional completion should equal 1.0")
            XCTAssertEqual(progressValueFractionalCompletion, 1.0, "progress value fractional completion should equal 1.0")
        } else {
            XCTFail("last item in bytesValues and progressValues should not be nil")
        }
    }
}

// MARK: -

class UploadMultipartFormDataTestCase: BaseTestCase {

    // MARK: Tests

    func testThatUploadingMultipartFormDataSucceedsWithDefaultParameters() {
        // Given
        let URLString = "http://httpbin.org/post"
        let french = "français".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let japanese = "日本語".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let expectation = expectationWithDescription("multipart form data upload should succeed")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        Alamofire.upload(
            .POST,
            URLString: URLString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: french, name: "french")
                multipartFormData.appendBodyPart(data: japanese, name: "japanese")
            },
            encodingCompletion: { result in
                switch result {
                case .Success(let upload, _, _):
                    upload.response { responseRequest, responseResponse, responseData, responseError in
                        request = responseRequest
                        response = responseResponse
                        data = responseData
                        error = responseError

                        expectation.fulfill()
                    }
                case .Failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")
    }

    func testThatUploadingMultipartFormDataWhileStreamingFromMemoryMonitorsProgress() {
        executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: false)
    }

    func testThatUploadingMultipartFormDataWhileStreamingFromDiskMonitorsProgress() {
        executeMultipartFormDataUploadRequestWithProgress(streamFromDisk: true)
    }

    func testThatUploadingMultipartFormDataBelowMemoryThresholdStreamsFromMemory() {
        // Given
        let URLString = "http://httpbin.org/post"
        let french = "français".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let japanese = "日本語".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let expectation = expectationWithDescription("multipart form data upload should succeed")

        var streamingFromDisk: Bool?
        var streamFileURL: NSURL?

        // When
        Alamofire.upload(
            .POST,
            URLString: URLString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: french, name: "french")
                multipartFormData.appendBodyPart(data: japanese, name: "japanese")
            },
            encodingCompletion: { result in
                switch result {
                case let .Success(upload, uploadStreamingFromDisk, uploadStreamFileURL):
                    streamingFromDisk = uploadStreamingFromDisk
                    streamFileURL = uploadStreamFileURL

                    upload.response { _, _, _, _ in
                        expectation.fulfill()
                    }
                case .Failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(streamingFromDisk, "streaming from disk should not be nil")
        XCTAssertNil(streamFileURL, "stream file URL should be nil")

        if let streamingFromDisk = streamingFromDisk {
            XCTAssertFalse(streamingFromDisk, "streaming from disk should be false")
        }
    }

    func testThatUploadingMultipartFormDataAboveMemoryThresholdStreamsFromDisk() {
        // Given
        let URLString = "http://httpbin.org/post"
        let french = "français".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let japanese = "日本語".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let expectation = expectationWithDescription("multipart form data upload should succeed")

        var streamingFromDisk: Bool?
        var streamFileURL: NSURL?

        // When
        Alamofire.upload(
            .POST,
            URLString: URLString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: french, name: "french")
                multipartFormData.appendBodyPart(data: japanese, name: "japanese")
            },
            encodingMemoryThreshold: 0,
            encodingCompletion: { result in
                switch result {
                case let .Success(upload, uploadStreamingFromDisk, uploadStreamFileURL):
                    streamingFromDisk = uploadStreamingFromDisk
                    streamFileURL = uploadStreamFileURL

                    upload.response { _, _, _, _ in
                        expectation.fulfill()
                    }
                case .Failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(streamingFromDisk, "streaming from disk should not be nil")
        XCTAssertNotNil(streamFileURL, "stream file URL should not be nil")

        if let
            streamingFromDisk = streamingFromDisk,
            streamFilePath = streamFileURL?.path
        {
            XCTAssertTrue(streamingFromDisk, "streaming from disk should be true")
            XCTAssertTrue(NSFileManager.defaultManager().fileExistsAtPath(streamFilePath), "stream file path should exist")
        }
    }

    // MARK: Combined Test Execution

    private func executeMultipartFormDataUploadRequestWithProgress(#streamFromDisk: Bool) {
        // Given
        let URLString = "http://httpbin.org/post"
        let loremData1: NSData = {
            var loremValues: [String] = []
            for _ in 1...1_500 {
                loremValues.append("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
            }

            return join(" ", loremValues).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        }()
        let loremData2: NSData = {
            var loremValues: [String] = []
            for _ in 1...1_500 {
                loremValues.append("Lorem ipsum dolor sit amet, nam no graeco recusabo appellantur.")
            }

            return join(" ", loremValues).dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        }()

        let expectation = expectationWithDescription("multipart form data upload should succeed")

        var byteValues: [(bytes: Int64, totalBytes: Int64, totalBytesExpected: Int64)] = []
        var progressValues: [(completedUnitCount: Int64, totalUnitCount: Int64)] = []
        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var data: AnyObject?
        var error: NSError?

        // When
        Alamofire.upload(
            .POST,
            URLString: URLString,
            multipartFormData: { multipartFormData in
                multipartFormData.appendBodyPart(data: loremData1, name: "lorem1")
                multipartFormData.appendBodyPart(data: loremData2, name: "lorem2")
            },
            encodingMemoryThreshold: streamFromDisk ? 0 : 100_000_000,
            encodingCompletion: { result in
                switch result {
                case .Success(let upload, let streamingFromDisk, _):
                    upload.progress { bytesWritten, totalBytesWritten, totalBytesExpectedToWrite in
                        let bytes = (bytes: bytesWritten, totalBytes: totalBytesWritten, totalBytesExpected: totalBytesExpectedToWrite)
                        byteValues.append(bytes)

                        let progress = (completedUnitCount: upload.progress.completedUnitCount, totalUnitCount: upload.progress.totalUnitCount)
                        progressValues.append(progress)
                    }
                    upload.response { responseRequest, responseResponse, responseData, responseError in
                        request = responseRequest
                        response = responseResponse
                        data = responseData
                        error = responseError

                        expectation.fulfill()
                    }
                case .Failure:
                    expectation.fulfill()
                }
            }
        )

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(byteValues.count, progressValues.count, "byteValues count should equal progressValues count")

        if byteValues.count == progressValues.count {
            for index in 0..<byteValues.count {
                let byteValue = byteValues[index]
                let progressValue = progressValues[index]

                XCTAssertGreaterThan(byteValue.bytes, 0, "reported bytes should always be greater than 0")
                XCTAssertEqual(byteValue.totalBytes, progressValue.completedUnitCount, "total bytes should be equal to completed unit count")
                XCTAssertEqual(byteValue.totalBytesExpected, progressValue.totalUnitCount, "total bytes expected should be equal to total unit count")
            }
        }

        if let
            lastByteValue = byteValues.last,
            lastProgressValue = progressValues.last
        {
            let byteValueFractionalCompletion = Double(lastByteValue.totalBytes) / Double(lastByteValue.totalBytesExpected)
            let progressValueFractionalCompletion = Double(lastProgressValue.0) / Double(lastProgressValue.1)

            XCTAssertEqual(byteValueFractionalCompletion, 1.0, "byte value fractional completion should equal 1.0")
            XCTAssertEqual(progressValueFractionalCompletion, 1.0, "progress value fractional completion should equal 1.0")
        } else {
            XCTFail("last item in bytesValues and progressValues should not be nil")
        }
    }
}
