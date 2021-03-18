//
//  DataFetchSuccessView.swift
//  OrderScrapper

import Foundation
import SwiftUI

struct DataFetchSuccessView : View {
    @Environment(\.horizontalSizeClass) var sizeClass
    let padding_zero : CGFloat  = 0
    
    var body: some View {
        VStack (){
            //Text Size
            Spacer(minLength: (sizeClass == .regular) ? 45 : 45)
            HStack {
                Text(Utils.getString(key: Strings.HeadingConnectAmazonAccount))
                    .font(.system(size: (sizeClass == .regular) ? 22 : 17))
                    .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                    .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 20 : 20, bottom: padding_zero, trailing: (sizeClass == .regular) ? 16 : 16))
                Spacer()
            }
            Spacer(minLength: (sizeClass == .regular) ? 35 : 35)
            Spacer()
            VStack (alignment: .center){
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Image(IconNames.Tick, bundle: AppConstants.bundle)
                            .frame(width: (sizeClass == .regular) ? 105 : 87.19, height: (sizeClass == .regular) ? 105 : 87.19)
                            .padding(.bottom, (sizeClass == .regular) ? 30 : 21.41)
                        Text(Utils.getString(key: Strings.SuccessMsgReceiptsFechedSuccessfully))
                            .font(.system(size: (sizeClass == .regular) ? 27 : 20))
                            .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                            .padding(.bottom, (sizeClass == .regular) ? 180 : 180)
                        
                        Button(action: {
                        }) {
                            HStack(alignment: .center) {
                                Text(Utils.getString(key: Strings.BtnOk))
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

struct DataFetchSuccessView_Previews : PreviewProvider {
    
    static var previews: some View {
        Group {
            DataFetchSuccessView()
                .previewDevice("iPhone 12 mini")
                .previewDisplayName("iPhone 12 mini")
            DataFetchSuccessView()
                .previewDevice("iPhone 12 Pro Max")
                .previewDisplayName("iPhone 12 Pro Max")
            DataFetchSuccessView()
                .previewDevice("iPhone 8")
                .previewDisplayName("iPhone 8")
            DataFetchSuccessView()
                .previewDevice("iPhone SE (2nd generation)")
                .previewDisplayName("iPhone SE (2nd generation)")
            DataFetchSuccessView()
                .previewDevice("iPad Pro (12.9-inch) (4th generation)")
                .previewDisplayName("iPad Pro(11-inch)(2nd generation)")
        }
    }
}
