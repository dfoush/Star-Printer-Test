//
//  StarPrinterController.swift
//  SPFlex
//
//  Created by Foushee, Dawson on 4/25/22.
//  Copyright © 2022 Chick-fil-A. All rights reserved.
//

import Foundation
import ExternalAccessory

final class StarPrinterController: NSObject {

    private let starPrinterQueue = DispatchQueue(label: "com.star-printer-test.starprinterqueue")

    private var currentStatuses: StarPrinterStatus_2? {
        didSet {
            if let currentStatuses = currentStatuses {
                print(statusString(from: currentStatuses))
            }
        }
    }

    private var starIoExtManager: StarIoExtManager!

    private var emulation: StarIoExtEmulation = .escPosMobile

    // MARK: - Init

    /// Initializes a printer controller.
    override init() {
        super.init()

        print("Initializing StarIoExtManager, connectAsync()")
        starIoExtManager = StarIoExtManager(type: .standard, portName: "BT:PRNT Star", portSettings: "mini", ioTimeoutMillis: 10_000)
        starIoExtManager.delegate = self
        starIoExtManager.connectAsync()
    }

    // MARK: - Public Methods

    func testBatteryStatus() {
        print("test battery status")
//        starIoExtManager.connect()

        guard let batteryCommandData = StarCommunication.createBatteryInformationCommand(emulation) else {
            assertionFailure("failed to create Star printer test data")
            return
        }

        starIoExtManager.lock.lock()

        print("printer status             : \(starIoExtManager.printerStatus.rawValue)")
        print("printer paper status       : \(starIoExtManager.printerPaperStatus.rawValue)")
        print("printer cover status       : \(starIoExtManager.printerCoverStatus.rawValue)")
        print("printer cash drawer status : \(starIoExtManager.cashDrawerStatus.rawValue)")

        starPrinterQueue.async {
            StarCommunication.sendBatteryCommand(batteryCommandData,
                                           port: self.starIoExtManager.port,
                                           completionHandler: { communicationResult, batteryStatusString in
//                DispatchQueue.main.async {
                    self.currentStatuses = communicationResult.status

                    print("Battery Status: \(batteryStatusString)\n" + StarCommunication.getCommunicationResultMessage(communicationResult))

                    self.starIoExtManager.lock.unlock()
//                }
            })
        }
    }

    func testPrint() {
        print("test print")
//        starIoExtManager.connect()

        guard let testData = StarCommunication.createTestData(emulation) else {
            assertionFailure("failed to create Star printer test data")
            return
        }

        starIoExtManager.lock.lock()

        starPrinterQueue.async {
            StarCommunication.sendCommands(testData,
                                           port: self.starIoExtManager.port,
                                           completionHandler: { (communicationResult: CommunicationResult) in
//                DispatchQueue.main.async {
                    self.currentStatuses = communicationResult.status

                    print(StarCommunication.getCommunicationResultMessage(communicationResult))

                    self.starIoExtManager.lock.unlock()
//                }
            })
        }
    }

    // MARK: - Private

    private func updatePrinterStatus() {
        print("update printer status - noop currently")
//        var statuses: StarPrinterStatus_2 = StarPrinterStatus_2()
//
//        starIoExtManager.connect()
//
//        log.debug("printer status             : \(starIoExtManager.printerStatus.rawValue)")
//        log.debug("printer paper status       : \(starIoExtManager.printerPaperStatus.rawValue)")
//        log.debug("printer cover status       : \(starIoExtManager.printerCoverStatus.rawValue)")
//        log.debug("printer cash drawer status : \(starIoExtManager.cashDrawerStatus.rawValue)")
//
//        starIoExtManager.lock.lock()
//
//        starPrinterQueue.async {
//            do {
//                try self.starIoExtManager.port?.getParsedStatus(starPrinterStatus: &statuses, level: 2)
//
//                self.currentStatuses = statuses
//            } catch {
//                log.debug("Unable to get printer status")
//            }
//
//            self.starIoExtManager.lock.unlock()
//        }
    }

    private func statusString(from status: StarPrinterStatus_2) -> String {
        """
        Updated StarPrinterStatuses:
            offline: \(status.offline)
            coverOpen: \(status.coverOpen)
            compulsionSwitch: \(status.compulsionSwitch)

            overTemp: \(status.overTemp)
            unrecoverableError: \(status.unrecoverableError)
            cutterError: \(status.cutterError)
            mechError: \(status.mechError)
            headThermistorError: \(status.headThermistorError)

            receiveBufferOverflow: \(status.receiveBufferOverflow)
            pageModeCmdError: \(status.pageModeCmdError)
            paperDetectionError: \(status.paperDetectionError)
            blackMarkError: \(status.blackMarkError)
            jamError: \(status.jamError)
            presenterPaperJamError: \(status.presenterPaperJamError)
            headUpError: \(status.headUpError)
            voltageError: \(status.voltageError)

            receiptBlackMarkDetection: \(status.receiptBlackMarkDetection)
            receiptPaperEmpty: \(status.receiptPaperEmpty)
            receiptPaperNearEmptyInner: \(status.receiptPaperNearEmptyInner)
            receiptPaperNearEmptyOuter: \(status.receiptPaperNearEmptyOuter)

            paperPresent: \(status.paperPresent)
            presenterPaperPresent: \(status.presenterPaperPresent)
            peelerPaperPresent: \(status.peelerPaperPresent)
            stackerFull: \(status.stackerFull)
            slipTOF: \(status.slipTOF)
            slipCOF: \(status.slipCOF)
            slipBOF: \(status.slipBOF)
            validationPaperPresent: \(status.validationPaperPresent)
            slipPaperPresent: \(status.slipPaperPresent)

            connectedInterface: \(status.connectedInterface)
        """
    }

}

extension StarPrinterController: StarIoExtManagerDelegate {

    func didStatusUpdate(_ manager: StarIoExtManager!, status: String!) {
        guard let status = status else { return }

        print("Star printer status updated: \(status)")
    }

    func didPrinterCoverOpen(_ manager: StarIoExtManager!) {
        print("Did cover open")
    }

    func didPrinterCoverClose(_ manager: StarIoExtManager!) {
        print("Did cover close")
    }

    func didPrinterOnline(_ manager: StarIoExtManager!) {
        print("Printer online")
    }

    func didPrinterOffline(_ manager: StarIoExtManager!) {
        print("Printer offline")
    }

    func manager(_ manager: StarIoExtManager, didConnectPort portName: String) {
        print("Connected to port \(portName)")
    }

    func manager(_ manager: StarIoExtManager, didFailToConnectPort portName: String, error: Error?) {
        print("Failed to connect to port \(portName) with error \(error?.localizedDescription ?? "nil")")
    }

}
