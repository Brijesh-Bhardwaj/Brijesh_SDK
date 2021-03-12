//
//  LoginView.swift
//  OrderScrapper

import Foundation
import SwiftUI

struct LoginView : View {
    @State private var email: String = ""
    @State private var password: String = ""
    let bundle: Bundle! = Bundle(identifier: "ai.blackstraw.orderscrapper.OrderScrapper")
    @Environment(\.horizontalSizeClass) var sizeClass
    let padding_zero : CGFloat  = 0
    
    var body: some View {
        VStack {
            //Text Size
            Spacer(minLength: (sizeClass == .regular) ? 45 : 45)
            HStack {
                Image(IconNames.BackArrow, bundle: bundle)
                    .frame(width: (sizeClass == .regular) ? 30 : 23.25, height: (sizeClass == .regular) ? 30 : 23.25)
                    .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 20 : 20, bottom: padding_zero, trailing: (sizeClass == .regular) ? 16 : 16))
                Text(NSLocalizedString("heading_connect_amazon_account", tableName: nil, bundle: bundle, value: "", comment: ""))
                    .font(.system(size: (sizeClass == .regular) ? 22 : 17))
                    .foregroundColor(Color("heading_color", bundle: bundle))
                Spacer()
            }
            Spacer(minLength: (sizeClass == .regular) ? 35 : 35)
            VStack {
                HStack {
                    Text(NSLocalizedString("heading_please_sign_in_with_credentials", tableName: nil, bundle: bundle, value: "", comment: ""))
                        .font(.system(size: (sizeClass == .regular) ? 25 : 20))
                        .foregroundColor(Color("heading_color", bundle: bundle))
                    Spacer(minLength: (sizeClass == .regular) ? 25 : 25)
                }.padding(.top, (sizeClass == .regular) ? 50 : 30)
                .padding(.all, (sizeClass == .regular) ? 25 : 15)
                
                //Error view
                HStack {
                    Image(IconNames.Error, bundle: bundle)
                        .frame(width: (sizeClass == .regular) ? 35 : 35, height: (sizeClass == .regular) ? 35 : 35, alignment: .leading)
                    Text(NSLocalizedString("error_enter_valid_username_password", tableName: nil, bundle: bundle, value: "", comment: ""))
                        .font(.system(size: (sizeClass == .regular) ? 17 : 12))
                        .padding(EdgeInsets(top: padding_zero, leading: padding_zero, bottom: padding_zero, trailing: (sizeClass == .regular) ? 16 : 16))
                        .foregroundColor(Color("error_color", bundle: bundle))
                    Spacer()
                }.padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                .hidden()
                HStack {
                    Text(NSLocalizedString("label_email_or_mobile_number", tableName: nil, bundle: bundle, value: "", comment: ""))
                        .font(.system(size: (sizeClass == .regular) ? 19 : 14))
                        .foregroundColor(Color("label_color", bundle: bundle))
                    Spacer()
                }.padding(EdgeInsets(top: (sizeClass == .regular) ? 15 : 10, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                
                TextField(NSLocalizedString("label_email_or_mobile_number", tableName: nil, bundle: bundle, value: "", comment: ""), text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .border(Color("border_color_text_field", bundle: bundle), width: (sizeClass == .regular) ? 1 : 1)
                    .cornerRadius((sizeClass == .regular) ? 4 : 4)
                    .padding(EdgeInsets(top: (sizeClass == .regular) ? 10 : 5, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                    .frame(width: .infinity , height: (sizeClass == .regular) ? 60 : 40)
                
                HStack {
                    Text(NSLocalizedString("label_password", tableName: nil, bundle: bundle, value: "", comment: ""))
                        .font(.system(size: (sizeClass == .regular) ? 19 : 14))
                        .foregroundColor(Color("label_color", bundle: bundle))
                    Spacer()
                }.padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                
                SecureField(NSLocalizedString("label_password", tableName: nil, bundle: bundle, value: "", comment: ""), text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .border(Color("border_color_text_field", bundle: bundle), width: (sizeClass == .regular) ? 1 : 1)
                    .cornerRadius((sizeClass == .regular) ? 4 : 4)
                    .padding(EdgeInsets(top: (sizeClass == .regular) ? 10 : 5, leading: (sizeClass == .regular) ? 21 : 16, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                    .frame(width: .infinity , height: (sizeClass == .regular) ? 60 : 40)
                
                //SignIn Button
                HStack {
                    Spacer()
                    Button(action: {
                        print("Submit tapped!")
                    }) {
                        HStack(alignment: .center) {
                            Text(NSLocalizedString("btn_submit", tableName: nil, bundle: bundle, value: "", comment: ""))
                                .fontWeight(.semibold)
                                .font(.system(size: (sizeClass == .regular) ? 23 : 18))
                                .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 10 : 10, bottom: padding_zero, trailing: padding_zero))
                                .foregroundColor(Color("btn_color", bundle: bundle))
                            Spacer()
                            Image(IconNames.RightArrow, bundle: bundle)
                                .frame(width: (sizeClass == .regular) ? 18 : 18, height:(sizeClass == .regular) ? 17 : 17)
                                .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 10 : 10, bottom: padding_zero, trailing: (sizeClass == .regular) ? 23 : 21))
                        }
                        .frame(width: (sizeClass == .regular) ? 150 : 133 , height: (sizeClass == .regular) ? 55 : 48, alignment: .leading)
                        .padding(EdgeInsets(top: padding_zero, leading: (sizeClass == .regular) ? 23 : 21, bottom: padding_zero, trailing: padding_zero))
                        .foregroundColor(.white)
                        .background(LinearGradient(gradient: Gradient(colors: [Color("color_linear_gradient2", bundle: bundle), Color("color_linear_gradient1", bundle: bundle)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius((sizeClass == .regular) ? 24 : 24)
                    }.padding(EdgeInsets(top: (sizeClass == .regular) ? 60 : 45, leading: padding_zero, bottom: padding_zero, trailing: (sizeClass == .regular) ? 21 : 16))
                }
                Spacer()
            }.background(Color.white)
            .cornerRadius((sizeClass == .regular) ? 35 : 35, corners: [.topLeft, .topRight])
        }.background(Color("color_radial_gradient1", bundle: bundle))
        .ignoresSafeArea()
        
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

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

