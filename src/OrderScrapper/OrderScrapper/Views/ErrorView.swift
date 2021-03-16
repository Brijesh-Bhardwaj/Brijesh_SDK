//
//  ErrorView.swift
//  OrderScrapper
//

import Foundation
import SwiftUI

struct ErrorView : View {
    @Environment(\.horizontalSizeClass) var sizeClass
    let padding_zero : CGFloat  = 0
    
    var body: some View {
        VStack (){
            //Text Size
            Spacer(minLength: (sizeClass == .regular) ? 45 : 45)
            HStack {
                Image(IconNames.BackArrow, bundle: AppConstants.bundle)
                    .frame(width: (sizeClass == .regular) ? 30 : 23.25, height: (sizeClass == .regular) ? 30 : 23.25)
                    .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 20 : 20, bottom: padding_zero, trailing: (sizeClass == .regular) ? 16 : 16))
                Text(Utils.getString(key: Strings.HeadingConnectAmazonAccount))
                    .font(.system(size: (sizeClass == .regular) ? 22 : 17))
                    .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                Spacer()
            }
            Spacer(minLength: (sizeClass == .regular) ? 35 : 35)
            Spacer()
            VStack (alignment: .center){
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Image(IconNames.ErrorLarge, bundle: AppConstants.bundle)
                            .frame(width: (sizeClass == .regular) ? 105 : 87.19, height: (sizeClass == .regular) ? 105 : 87.19)
                            .padding(.bottom, (sizeClass == .regular) ? 30 : 21.41)
                        Text(Utils.getString(key: Strings.NoConnection))
                            .font(.system(size: (sizeClass == .regular) ? 27 : 20))
                            .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                            .padding(.bottom, (sizeClass == .regular) ? 25 : 15)
                        
                        Text(Utils.getString(key: Strings.NoConnection_msg))
                            .font(.system(size: (sizeClass == .regular) ? 17 : 12))
                            .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                            .padding(.bottom, (sizeClass == .regular) ? 50 : 35)
                        
                        Button(action: {
                        }) {
                            HStack(alignment: .center) {
                                Text(Utils.getString(key: Strings.BtnTryAgain))
                                    .fontWeight(.semibold)
                                    .font(.system(size: (sizeClass == .regular) ? 23 : 18))
                                    .foregroundColor(Utils.getColor(key: Colors.ColorBtn))
                            }.frame(width: (sizeClass == .regular) ? 165 : 151 , height: (sizeClass == .regular) ? 61 : 48, alignment: .center)
                           
                            .background(LinearGradient(gradient: Gradient(colors: [Utils.getColor(key: Colors.ColorLinearGradient2), Utils.getColor(key: Colors.ColorLinearGradient1)]), startPoint: .leading, endPoint: .trailing))
                            .cornerRadius((sizeClass == .regular) ? 28 : 24)
                        }
                    }
                    Spacer()
                }
                Spacer()
            }
            .background(Utils.getColor(key: Colors.ColorBackgroundErrorView))
            .cornerRadius((sizeClass == .regular) ? 35 : 35, corners: [.topLeft, .topRight])
            
        }.background(RadialGradient(gradient: Gradient(colors: [Utils.getColor(key: Colors.ColorRadialGradient1), Utils.getColor(key: Colors.ColorRadialGradient2)]), center: .center, startRadius: 1, endRadius: 100))
        .edgesIgnoringSafeArea(.all)
    }
}

struct ErrorView_Previews : PreviewProvider {
    
    static var previews: some View {
        Group {
            ErrorView()
                .previewDevice("iPhone 12 mini")
                .previewDisplayName("iPhone 12 mini")
            ErrorView()
                .previewDevice("iPhone 12 Pro Max")
                .previewDisplayName("iPhone 12 Pro Max")
            ErrorView()
                .previewDevice("iPhone 8")
                .previewDisplayName("iPhone 8")
            ErrorView()
                .previewDevice("iPhone SE (2nd generation)")
                .previewDisplayName("iPhone SE (2nd generation)")
            ErrorView()
                .previewDevice("iPad Pro (12.9-inch) (4th generation)")
                .previewDisplayName("iPad Pro(11-inch)(2nd generation)")
        }
    }
}
