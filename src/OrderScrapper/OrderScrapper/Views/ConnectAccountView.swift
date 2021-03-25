//
//  ConnectAccountView.swift
//  OrderScrapper

import SwiftUI
import Combine

struct ConnectAccountView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var viewModel: WebViewModel
    
    @State var monitor = NetworkMonitor()
    @State var showWebView = false
    @State var progressValue: Float = 0
    @State var webviewError = false
    @State var progressMessage = Utils.getString(key: Strings.HeadingConnectingAmazonAccount)
    @State var headerTitle = Utils.getString(key: Strings.HeadingConnectAmazonAccount)
    @State var stepMessage = Utils.getString(key: Strings.Step1)
    @State var processCompleted = false
    
    let padding_zero : CGFloat  = 0
    
    init(account: Account) {
        self.viewModel = WebViewModel()
        self.viewModel.userAccount = account
    }
    
    var body: some View {
        ZStack {
            WebView(viewModel: viewModel)
            if (!self.showWebView) {
                GeometryReader { geometry in
                    VStack () {
                        Spacer(minLength: geometry.size.height * 0.07)
                        
                        //Header Title
                        HStack {
                            Text(self.headerTitle)
                                .font(.system(size: (sizeClass == .regular) ? 30 : 17))
                                .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                                .padding(.leading, 20)
                                .onReceive(self.viewModel.headingMessage.receive(on: RunLoop.main)) { value in
                                    if (!self.headerTitle.elementsEqual(value)) {
                                        self.headerTitle = value
                                    }
                                }
                            Spacer()
                        }
                        
                        Spacer(minLength: geometry.size.height * 0.05)
                        
                        if monitor.status == .connected {
                            if webviewError {
                                ExceptionErrorView(onButtonClick: self.onRetry)
                            } else if processCompleted {
                                DataFetchSuccessView(onButtonClick: self.onProcessDone)
                            } else {
                                ProgressView(progressValue: $progressValue, progressMessage: $progressMessage, stepMessage: $stepMessage)
                                    .onReceive(self.viewModel.progressMessage.receive(on: RunLoop.main)) {
                                        value in
                                        if (!value.elementsEqual(self.progressMessage)) {
                                            self.progressMessage = value
                                        }
                                    }
                                    .onReceive(self.viewModel.progressValue.receive(on: RunLoop.main)) { value in
                                        progressValue = value
                                    }
                                    .onReceive(self.viewModel.stepMessage.receive(on: RunLoop.main)) { value in
                                        if (!value.elementsEqual(self.stepMessage)) {
                                            self.stepMessage = value
                                        }
                                    }
                            }
                        } else {
                            NetworkErrorView(onButtonClick: self.onRetry)
                         }
                    }.background(RadialGradient(gradient: Gradient(colors: [Utils.getColor(key: Colors.ColorRadialGradient1), Utils.getColor(key: Colors.ColorRadialGradient2)]), center: .center, startRadius: 1, endRadius: 100))
                }
                .edgesIgnoringSafeArea(.all)
            }
        }.edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .onReceive(self.viewModel.showWebView.receive(on: RunLoop.main)) {
            value in
            if (showWebView != value) {
                showWebView = value
            }
        }
        .onReceive(self.viewModel.webviewError.receive(on: RunLoop.main)) { value in
            webviewError = value
        }
        .onReceive(self.viewModel.completionPublisher.receive(on: RunLoop.main)) { value in
            if value != self.processCompleted {
                self.processCompleted = value
            }
        }
        .onReceive(self.viewModel.authError.receive(on: RunLoop.main)) { authError in
            if authError {
                self.presentationMode.wrappedValue.dismiss()
                LibContext.shared.webAuthErrorPublisher.send(authError)
            }
        }
    }
    
    func onRetry() {
        self.viewModel.navigationPublisher.send(.reload)
        self.webviewError = false
    }
    
    func onProcessDone() {
        self.presentationMode.wrappedValue.dismiss()
        LibContext.shared.scrapeCompletionPublisher.send(true)
    }
}

struct ConnectAccountView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConnectAccountView(account: UserAccountMO())
                .previewDevice("iPhone 12 Pro Max")
            ConnectAccountView(account: UserAccountMO())
                .previewDevice("iPhone 12 mini")
        }
    }
}
