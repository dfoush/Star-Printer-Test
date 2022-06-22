//
//  ContentView.swift
//  Star Printer  Test
//
//  Created by Foushee, Dawson on 6/22/22.
//

import SwiftUI

struct ContentView: View {

    let printerController = StarPrinterController()

    var body: some View {
        Button {
            printerController.testPrint()
        } label: {
            Text("Test Print")
        }.padding()

        Button {
            printerController.testBatteryStatus()
        } label: {
            Text("Test Battery Status")
        }

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
