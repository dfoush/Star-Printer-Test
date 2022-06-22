//
//  StarPrinterCommunication.swift
//  SPFlex
//
//  Created by Foushee, Dawson on 4/28/22.
//  Copyright © 2022 Chick-fil-A. All rights reserved.
//

// swiftlint:disable function_body_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable comment_spacing
// swiftlint:disable file_length

import Foundation


class CommunicationResult {
    var result: StarPrinterResult
    var status: StarPrinterStatus_2
    var code: Int

    init(_ result: StarPrinterResult, _ status: StarPrinterStatus_2, _ code: Int) {
        self.result = result
        self.status = status
        self.code = code
    }
}

enum StarPrinterResult {
    case success
    case errorOpenPort
    case errorBeginCheckedBlock
    case errorEndCheckedBlock
    case errorWritePort
    case errorReadPort
    case errorUnknown
}

typealias SendCompletionHandler = (_ communicationResult: CommunicationResult) -> Void
typealias SendBatteryCompletionHandler = (_ communicationResult: CommunicationResult, _ serialNumber: String) -> Void

enum StarCommunication {

    /// Creates battery information command data
    static func createBatteryInformationCommand(_ emulation: StarIoExtEmulation) -> Data? {
        // These bytes represent the battery query, this came from a support
        // email and don't seem to exist in the actual SDK documentation
        let bytes: [UInt8] = [0x1b, 0x1d, 0x29, 0x49, 0x01, 0, 0x50]
        let length: UInt = UInt(bytes.count)
        let builder: ISCBBuilder = StarIoExt.createCommandBuilder(emulation)

        builder.beginDocument()
        builder.appendBytes(bytes, length: length)
        builder.endDocument()

        return builder.commands.copy() as? Data
    }

    /// Returns test Star printer data, copied from the SDK sample project
    static func createTestData(_ emulation: StarIoExtEmulation) -> Data? {
        let encoding = String.Encoding.utf8

        // create data
        let builder: ISCBBuilder = StarIoExt.createCommandBuilder(emulation)

        builder.beginDocument()

        builder.append(SCBCodePageType.UTF8)
        builder.append(SCBInternationalType.USA)

        // ** Sample data **
        builder.appendCharacterSpace(0)

        builder.appendAlignment(SCBAlignmentPosition.center)

        builder.append((
            "Star Clothing Boutique\n" +
            "123 Star Road\n" +
            "City, State 12345\n" +
            "\n").data(using: encoding))

        builder.appendAlignment(SCBAlignmentPosition.left)

        builder.append((
            "Date:MM/DD/YYYY                    Time:HH:MM PM\n" +
            "------------------------------------------------\n" +
            "\n").data(using: encoding))

        builder.appendData(withEmphasis: "SALE \n".data(using: encoding))

        builder.append((
            "SKU               Description              Total\n" +
            "300678566         PLAIN T-SHIRT            10.99\n" +
            "300692003         BLACK DENIM              29.99\n" +
            "300651148         BLUE DENIM               29.99\n" +
            "300642980         STRIPED DRESS            49.99\n" +
            "300638471         BLACK BOOTS              35.99\n" +
            "\n" +
            "Subtotal                                  156.95\n" +
            "Tax                                         0.00\n" +
            "------------------------------------------------\n").data(using: encoding))

        builder.append("Total                       ".data(using: encoding))

        builder.appendData(withMultiple: "   $156.95\n".data(using: encoding), width: 2, height: 2)

        builder.append((
            "------------------------------------------------\n" +
            "\n" +
            "Charge\n" +
            "159.95\n" +
            "Visa XXXX-XXXX-XXXX-0123\n" +
            "\n").data(using: encoding))

        builder.appendData(withInvert: "Refunds and Exchanges\n".data(using: encoding))

        builder.append("Within ".data(using: encoding))

        builder.appendData(withUnderLine: "30 days".data(using: encoding))

        builder.append(" with receipt\n".data(using: encoding))

        builder.append((
            "And tags attached\n" +
            "\n").data(using: encoding))

        builder.appendAlignment(SCBAlignmentPosition.center)

        builder.appendBarcodeData("{BStar.".data(using: String.Encoding.ascii), symbology: SCBBarcodeSymbology.code128, width: SCBBarcodeWidth.mode2, height: 40, hri: true)

        builder.appendCutPaper(SCBCutPaperAction.partialCutWithFeed)

        builder.endDocument()
        // ** Sample data **

        return builder.commands.copy() as? Data
    }

    /// Sends Star printer command data to the port specified
    static func sendCommands(_ commands: Data!, port: SMPort!, completionHandler: SendCompletionHandler?) {
        var result: StarPrinterResult = .errorOpenPort
        var code: Int = SMStarIOResultCodeFailedError
        var printerStatus: StarPrinterStatus_2 = StarPrinterStatus_2()

        var commandsArray: [UInt8] = [UInt8](repeating: 0, count: commands.count)
        commands.copyBytes(to: &commandsArray, count: commands.count)

        while true {
            do {
                if port == nil {
                    break
                }

                result = .errorBeginCheckedBlock

                try port.beginCheckedBlock(starPrinterStatus: &printerStatus, level: 2)

                if printerStatus.offline == 1 { // true
                    break
                }

                result = .errorWritePort

                let startDate: Date = Date()

                var total: UInt32 = 0

                while total < UInt32(commands.count) {
                    var written: UInt32 = 0

                    try port.write(writeBuffer: commandsArray, offset: total, size: UInt32(commands.count) - total, numberOfBytesWritten: &written)

                    total += written

                    if Date().timeIntervalSince(startDate) >= 30.0 {     // 30000mS!!!
                        break
                    }
                }

                if total < UInt32(commands.count) {
                    break
                }

                port.endCheckedBlockTimeoutMillis = 30_000     // 30000mS!!!

                result = .errorEndCheckedBlock

                try port.endCheckedBlock(starPrinterStatus: &printerStatus, level: 2)

                if printerStatus.offline == 1 { // true
                    break
                }

                result = .success
                code = SMStarIOResultCodeSuccess

                break
            } catch let error as NSError {
                code = error.code
            }
        }

        completionHandler?(CommunicationResult(result, printerStatus, code))
    }

    /// This method includes reading information back from the port after sending the
    /// command, copied from the SDK sample project. Currently is not returning the
    /// expected value format.
    static func sendBatteryCommand(_ commands: Data!, port: SMPort!, completionHandler: SendBatteryCompletionHandler?) {
        var result: StarPrinterResult = .errorOpenPort
        var printerStatus: StarPrinterStatus_2 = StarPrinterStatus_2()
        var code: Int = SMStarIOResultCodeFailedError
        var message: String = ""

        while true {
            do {
                // Sleep to avoid a problem which sometimes cannot communicate with Bluetooth.
                // (Refer Readme for details)
                Thread.sleep(forTimeInterval: 0.2)

                result = .errorWritePort

                try port.getParsedStatus(starPrinterStatus: &printerStatus, level: 2)

                let startDate: Date = Date()

                var total: UInt32 = 0

                var commandArray: [UInt8] = [UInt8](repeating: 0, count: commands.count)
                commands.copyBytes(to: &commandArray, count: commands.count)

                while total < UInt32(commandArray.count) {
                    var written: UInt32 = 0

                    try port.write(writeBuffer: commandArray,
                                   offset: total,
                                   size: UInt32(commandArray.count) - total,
                                   numberOfBytesWritten: &written)

                    total += written

                    if Date().timeIntervalSince(startDate) >= 3.0 {     //  3000mS!!!
                        break
                    }
                }

                if total < UInt32(commandArray.count) {
                    break
                }

                result = .errorReadPort

                var information: String = ""

                var receivedData: [UInt8] = [UInt8]()

                while true {
                    var buffer: [UInt8] = [UInt8](repeating: 0, count: 1_024 + 8)

                    if Date().timeIntervalSince(startDate) >= 3.0 {     //  3000mS!!!
                        break
                    }

                    Thread.sleep(forTimeInterval: 0.01)     // Break time.

                    var readLength: UInt32 = 0

                    try port.read(readBuffer: &buffer, offset: 0, size: 1_024, numberOfBytesRead: &readLength)

                    if readLength == 0 {
                        continue
                    }

                    let resizedBuffer = Array(buffer.prefix(Int(readLength)))
                    receivedData.append(contentsOf: resizedBuffer)

                    var test: String = ""
                    for currentCount: Int in 0 ..< Int(receivedData.count - 1) {
                        test += String(format: "%c", receivedData[currentCount])
                    }
                    message = test
                    print("battery test full data: \(test)")

                    // check below (copied from sample project) is failing because the parsed data isn't what is expected
                    // currently received data looks like `SM-T301IVer4.4` instead of `PrBtY=....,`

                    if receivedData.count >= 2 {
                        for i: Int in 0 ..< Int(receivedData.count - 1) { // swiftlint:disable:this identifier_name
                            if receivedData[i + 0] == 0x0a &&
                               receivedData[i + 1] == 0x00 {
                                for j: Int in 0 ..< Int(receivedData.count - 9) { // swiftlint:disable:this identifier_name
                                    if receivedData[j + 0] == 0x1b &&
                                       receivedData[j + 1] == 0x1d &&
                                       receivedData[j + 2] == 0x29 &&
                                       receivedData[j + 3] == 0x49 &&
                                       receivedData[j + 6] == 49 {
                                        information = ""

                                        for k: Int in j + 7 ..< Int(receivedData.count) { // swiftlint:disable:this identifier_name
                                            let text: String = String(format: "%c", receivedData[k])

                                            information += text
                                        }

                                        result = .success
                                        break
                                    }
                                }

                                break
                            }
                        }
                    }

                    if result == .success {
                        break
                    }
                }

                if result != .success {
                    break
                }

                result = .errorReadPort

                // Extract Battery Field ("PrBtY=....,")
                let batteryPrefix = "PrBtY="
                let batteryString = information.split(separator: ",")
                    .filter { $0.hasPrefix(batteryPrefix) }
                    .map { $0.dropFirst(batteryPrefix.count) }
                    .first

                guard let batteryString = batteryString else {
                    break
                }

                message = String(batteryString)

                result = .success
                code = SMStarIOResultCodeSuccess

                break
            } catch let error as NSError {
                code = error.code
            }
        }

        completionHandler?(CommunicationResult(result, printerStatus, code), message)
    }

    // swiftlint:disable cyclomatic_complexity
    static func getCommunicationResultMessage(_ communicationResult: CommunicationResult) -> String {
        var message: String

        switch communicationResult.result {
        case .success:
            message = "Success!"
        case .errorOpenPort:
            message = "Fail to openPort"
        case .errorBeginCheckedBlock:
            message = "Printer is offline (beginCheckedBlock)"
        case .errorEndCheckedBlock:
            message = "Printer is offline (endCheckedBlock)"
        case .errorReadPort:
            message = "Read port error (readPort)"
        case .errorWritePort:
            message = "Write port error (writePort)"
        default:
            message = "Unknown error"
        }

        if communicationResult.result != .success {
            message += "\n\nError code: " + String(communicationResult.code)

            if communicationResult.code == SMStarIOResultCodeInUseError {
                message += " (In use)"
            } else if communicationResult.code == SMStarIOResultCodeFailedError {
                message += " (Failed)"
            } else if communicationResult.code == SMStarIOResultCodePaperPresentError {
                message += " (Paper Present)"
            }
        }

        return message
    }
}
