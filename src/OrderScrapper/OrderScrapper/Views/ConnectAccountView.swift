//
//  ConnectAccountView.swift
//  OrderScrapper
//
//  Created by Avinash on 12/03/21.
//

import SwiftUI

struct ConnectAccountView: View {
    @ObservedObject var viewModel: WebViewModel
    @State var showWebView = false
    
    init(email: String, password: String) {
        print("Init Connect Account View ", email, password)
        self.viewModel = WebViewModel()
        self.viewModel.userEmail = email
        self.viewModel.userPassword = password
    }
    
    var body: some View {
        ZStack {
            WebView(viewModel: viewModel)
            if (!self.showWebView) {
                Color.yellow.frame(width: .infinity, height: .infinity, alignment: .center)
            }
        }.edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .onReceive(self.viewModel.showWebView.receive(on: RunLoop.main)) { value in
            if (showWebView != value) {
                showWebView = value
            }
        }
    }
}

struct ConnectAccountView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectAccountView(email: "", password: "")
    }
}
