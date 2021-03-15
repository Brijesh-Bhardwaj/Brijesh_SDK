//
//  ConnectAccountView.swift
//  OrderScrapper
//
//  Created by Avinash on 12/03/21.
//

import SwiftUI

struct ConnectAccountView: View {
    @ObservedObject var viewModel: ViewModel
    
    init(email: String, password: String) {
        print("Init Connect Account View ", email, password)
        self.viewModel = ViewModel()
        self.viewModel.userEmail = email
        self.viewModel.userPassword = password
    }
    
    var body: some View {
        ZStack {
            WebView(viewModel: viewModel)
//            Color.yellow.frame(width: .infinity, height: .infinity, alignment: .center)
//            VStack {
//                Text("Yolo")
//            }.background(Color.yellow)
        }.edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
    }
}

struct ConnectAccountView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectAccountView(email: "", password: "")
    }
}
