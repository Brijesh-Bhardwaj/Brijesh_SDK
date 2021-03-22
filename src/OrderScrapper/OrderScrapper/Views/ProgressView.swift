//
//  ProgressView.swift
//  OrderScrapper
//

import SwiftUI

struct ProgressView: View {
    @Binding var progressValue: Float
    @Binding var progressMessage: String
    @Binding var stepMessage: String
    
    var body: some View {
        GeometryReader { geometry in
            VStack (alignment: .center){
                VStack {
                    Text(self.progressMessage)
                        .font(.system(size: 24))
                        .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                        .padding(.bottom, 20)
                    
                    Text(Utils.getString(key: Strings.SubheadingStayOnThisScreenUntilCompletion))
                        .font(.system(size: 18))
                        .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                        .padding(.bottom, geometry.size.height * 0.2)
                    
                    //ProgressBar
                    ProgressBar(value: $progressValue)
                        .frame(height: geometry.size.height * 0.08)
                        .padding([.leading, .trailing], 10)
                    
                    Text(self.stepMessage)
                        .font(.system(size: 22))
                        .padding(.top, 15)
                        .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                }.padding([.leading, .trailing], 5)
                .padding(.top, geometry.size.height * 0.07)
                
                Spacer()
            }
            .background(Utils.getColor(key: Colors.ColorBackgroundErrorView))
            .cornerRadius(geometry.size.width * 0.1, corners: [.topLeft, .topRight])
        }
    }
}
