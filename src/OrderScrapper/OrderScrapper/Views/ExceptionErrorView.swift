//
//  ExceptionErrorView.swift
//  OrderScrapper
//
//  Created by Avinash on 20/03/21.
//

import SwiftUI

struct ExceptionErrorView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    let padding_zero : CGFloat  = 0
    
    var onButtonClick: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            VStack (alignment: .center){
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .center) {
                        Image(IconNames.ErrorLarge, bundle: AppConstants.bundle)
                            .frame(width: (sizeClass == .regular) ? 105 : 87.19, height: (sizeClass == .regular) ? 105 : 87.19)
                            .padding(.bottom, (sizeClass == .regular) ? 30 : 21.41)
                        Text(Utils.getString(key: Strings.ErrorEncounteredUnexpectedError))
                            .font(.system(size: (sizeClass == .regular) ? 27 : 20))
                            .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, (sizeClass == .regular) ? 25 : 15)
                        Button(action: {
                            if let onClick = onButtonClick {
                                onClick()
                            }
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
            .edgesIgnoringSafeArea(.all)
            .cornerRadius(geometry.size.width * 0.1, corners: [.topLeft, .topRight])
        }
    }
}

struct ExceptionErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ExceptionErrorView()
    }
}
