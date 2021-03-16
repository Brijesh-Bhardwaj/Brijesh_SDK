//
//  LoginView.swift
//  OrderScrapper

import Foundation
import SwiftUI

struct LoginView : View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var invalidEmail = ""
    @State private var invalidPassword = ""
    @State private var errorInvalidEmailAndPasswrd = ""
    @Environment(\.horizontalSizeClass) var sizeClass
    let padding_zero : CGFloat  = 0
    
    var body: some View {
        VStack {
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
            VStack (alignment: .leading){
                HStack {
                    Text(Utils.getString(key: Strings.HeadingPleaseSignInWithCredentials))
                        .font(.system(size: (sizeClass == .regular) ? 25 : 20))
                        .foregroundColor(Utils.getColor(key: Colors.ColorHeading))
                    Spacer(minLength: (sizeClass == .regular) ? 25 : 25)
                }.padding(.top, (sizeClass == .regular) ? 50 : 30)
                .padding(.all, (sizeClass == .regular) ? 25 : 15)
                
                //Error view
                if !errorInvalidEmailAndPasswrd.isEmpty {
                HStack {
                    Image(IconNames.Error, bundle: AppConstants.bundle)
                        .frame(width: (sizeClass == .regular) ? 35 : 35, height: (sizeClass == .regular) ? 35 : 35, alignment: .leading)
                    Text(errorInvalidEmailAndPasswrd)
                        .font(.system(size: (sizeClass == .regular) ? 17 : 12))
                        .padding(EdgeInsets(top: padding_zero, leading: padding_zero, bottom: padding_zero, trailing: (sizeClass == .regular) ? 16 : 16))
                        .foregroundColor(Utils.getColor(key: Colors.ColorError))
                    Spacer()
                }.padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                }
                HStack {
                    Text(Utils.getString(key: Strings.LabelEmailOrMobileNumber))
                        .font(.system(size: (sizeClass == .regular) ? 19 : 14))
                        .foregroundColor(Utils.getColor(key: Colors.ColorLabel))
                    Spacer()
                }.padding(EdgeInsets(top: (sizeClass == .regular) ? 15 : 10, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                
                TextField(Utils.getString(key: Strings.LabelEmailOrMobileNumber), text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .border(Utils.getColor(key: Colors.ColorBorderTextField), width: (sizeClass == .regular) ? 1 : 1)
                    .cornerRadius((sizeClass == .regular) ? 4 : 4)
                    .padding(EdgeInsets(top: (sizeClass == .regular) ? 10 : 5, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                    .frame(width: .infinity , height: (sizeClass == .regular) ? 60 : 40)
                if !invalidEmail.isEmpty {
                Text(invalidEmail)
                    .font(.footnote)
                    .foregroundColor(Utils.getColor(key: Colors.ColorError))
                    .padding(.leading, (sizeClass == .regular) ? 21 : 16)
                    .padding(.bottom, (sizeClass == .regular) ? 21 : 16)
                }
                HStack {
                    Text(Utils.getString(key: Strings.LabelPassword))
                        .font(.system(size: (sizeClass == .regular) ? 19 : 14))
                        .foregroundColor(Utils.getColor(key: Colors.ColorLabel))
                    Spacer()
                }.padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                
                SecureField(Utils.getString(key: Strings.LabelPassword), text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .border(Utils.getColor(key: Colors.ColorBorderTextField), width: (sizeClass == .regular) ? 1 : 1)
                    .cornerRadius((sizeClass == .regular) ? 4 : 4)
                    .padding(EdgeInsets(top: (sizeClass == .regular) ? 10 : 5, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                    .frame(width: .infinity , height: (sizeClass == .regular) ? 60 : 40)
                if !invalidPassword.isEmpty {
                Text(invalidPassword)
                    .font(.footnote)
                    .foregroundColor(Utils.getColor(key: Colors.ColorError))
                    .padding(.leading, (sizeClass == .regular) ? 21 : 16)
                    .padding(.bottom, (sizeClass == .regular) ? 21 : 16)
                }
                //SignIn Button
                HStack {
                    Spacer()
                    Button(action: {
                        if !ValidationUtil.isValidEmail(email: email) {
                            self.invalidEmail = Utils.getString(key: Strings.ValidationPleaseEnterValidEmail)
                            return
                        }
                        if !ValidationUtil.isValidPassword(password: password) {
                            self.invalidPassword = Utils.getString(key: Strings.ValidationPleaseEnterValidPassword)
                            return
                        }
                        self.invalidEmail = ""
                        self.invalidPassword = ""
                    }) {
                        HStack(alignment: .center) {
                            Text(Utils.getString(key: Strings.BtnSubmit))
                                .fontWeight(.semibold)
                                .font(.system(size: (sizeClass == .regular) ? 23 : 18))
                                .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 10 : 10, bottom: padding_zero, trailing: padding_zero))
                                .foregroundColor(Utils.getColor(key: Colors.ColorBtn))
                            Spacer()
                            Image(IconNames.RightArrow, bundle: AppConstants.bundle)
                                .frame(width: (sizeClass == .regular) ? 18 : 18, height:(sizeClass == .regular) ? 17 : 17)
                                .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 10 : 10, bottom: padding_zero, trailing: (sizeClass == .regular) ? 23 : 21))
                        }
                        .frame(width: (sizeClass == .regular) ? 150 : 133 , height: (sizeClass == .regular) ? 55 : 48, alignment: .leading)
                        .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 23 : 21, bottom: padding_zero, trailing: padding_zero))
                        .foregroundColor(.white)
                        .background(LinearGradient(gradient: Gradient(colors: [Utils.getColor(key: Colors.ColorLinearGradient2), Utils.getColor(key: Colors.ColorLinearGradient2)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius((sizeClass == .regular) ? 24 : 24)
                    }.padding(EdgeInsets(top: (sizeClass == .regular) ? 60 : 45, leading: padding_zero, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                }
                Spacer()
            }.background(Color.white)
            .cornerRadius((sizeClass == .regular) ? 35 : 35, corners: [.topLeft, .topRight])
        }.background(RadialGradient(gradient: Gradient(colors: [Utils.getColor(key: Colors.ColorRadialGradient1), Utils.getColor(key: Colors.ColorRadialGradient2)]), center: .center, startRadius: 1, endRadius: 100))
        .edgesIgnoringSafeArea(.all)
    }
}


struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView()
                .previewDevice("iPhone 12 mini")
                .previewDisplayName("iPhone 12 mini")
            LoginView()
                .previewDevice("iPhone 12 Pro Max")
                .previewDisplayName("iPhone 12 Pro Max")
            LoginView()
                .previewDevice("iPhone 8")
                .previewDisplayName("iPhone 8")
            LoginView()
                .previewDevice("iPhone SE (2nd generation)")
                .previewDisplayName("iPhone SE (2nd generation)")
            LoginView()
                .previewDevice("iPad Pro (12.9-inch) (4th generation)")
                .previewDisplayName("iPad Pro(11-inch)(2nd generation)")
        }
    }
}

