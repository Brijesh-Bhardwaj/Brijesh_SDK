//
//  ConnectAccountView.swift
//  OrderScrapper

import SwiftUI
import Combine

struct ConnectAccountView: View {
    @ObservedObject var viewModel: WebViewModel
    @State var showWebView = false
    @Environment(\.horizontalSizeClass) var sizeClass
    let padding_zero : CGFloat  = 0
    @State var progressValue: Float = 0
    
    init(email: String, password: String) {
        self.viewModel = WebViewModel()
        self.viewModel.userEmail = email
        self.viewModel.userPassword = password
    }
    
    var body: some View {
        ZStack {
            WebView(viewModel: viewModel)
            if (!self.showWebView) {
                VStack (){
                    //Text Size
                    Spacer(minLength: (sizeClass == .regular) ? 45 : 45)
                    HStack {
                        Text(Utils.getString(key: Strings.HeadingConnectAmazonAccount))
                            .font(.system(size: (sizeClass == .regular) ? 25 : 17))
                            .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                            .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 20 : 20, bottom: padding_zero, trailing: (sizeClass == .regular) ? 16 : 16))
                        Spacer()
                    }
                    Spacer(minLength: (sizeClass == .regular) ? 35 : 35)
                    Spacer()
                    VStack (alignment: .center){
                        HStack {
                            Spacer()
                            VStack {
                                Text(Utils.getString(key: Strings.HeadingConnectingAmazonAccount))
                                    .font(.system(size: (sizeClass == .regular) ? 27 : 20))
                                    .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                                    .padding(.bottom, (sizeClass == .regular) ? 20 : 15)
                                
                                Text(Utils.getString(key: Strings.SubheadingStayOnThisScreenUntilCompletion))
                                    .font(.system(size: (sizeClass == .regular) ? 17 : 12))
                                    .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                                    .padding(.bottom, (sizeClass == .regular) ? 163 : 147)
                                
                                
                                //ProgressBar
                                ProgressBar(value: $progressValue)
                                    .frame(height: (sizeClass == .regular) ? 110 : 80)
                                    .onReceive(self.viewModel.progressValue.receive(on: RunLoop.main)) { value in
                                        progressValue = value
                                    }
                                
                                Text(Utils.getString(key: Strings.Step1))
                                    .font(.system(size: (sizeClass == .regular) ? 22 : 17))
                                    .padding(.top, (sizeClass == .regular) ? 15 : 10)
                                    .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                            }.padding(.top,(sizeClass == .regular) ? 65 : 51)
                            
                            
                            Spacer()
                        }
                        Spacer()
                    }
                    .background(Utils.getColor(key: Colors.ColorBackgroundErrorView))
                    .cornerRadius((sizeClass == .regular) ? 35 : 35, corners: [.topLeft, .topRight])
                    
                }.background(RadialGradient(gradient: Gradient(colors: [Utils.getColor(key: Colors.ColorRadialGradient1), Utils.getColor(key: Colors.ColorRadialGradient2)]), center: .center, startRadius: 1, endRadius: 100))
                .edgesIgnoringSafeArea(.all)
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
