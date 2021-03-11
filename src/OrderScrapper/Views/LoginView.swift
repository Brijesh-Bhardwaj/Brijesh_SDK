//
//  LoginView.swift
//  OrderScrapper

import Foundation
import SwiftUI
struct LoginView : View {
    @State private var email: String = ""
    @State private var password: String = ""
    let bundle: Bundle! = Bundle(identifier: "ai.blackstraw.orderscrapper.OrderScrapper")
    
    var body: some View {
        VStack {
            Spacer(minLength: Dimen.spacer1)
            HStack {
                Image(IconNames.BackArrow, bundle: bundle)
                    .frame(width: Dimen.width_height_back_arrow, height: Dimen.width_height_back_arrow)
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 16))
                Text(NSLocalizedString("heading_connect_amazon_account", tableName: nil, bundle: bundle, value: "", comment: ""))
                    .font(.system(size: Dimen.text_size_heading1))
                    .foregroundColor(Color("heading_color", bundle: bundle))
                Spacer()
            }
            Spacer(minLength: Dimen.spacer2)
            VStack {
                HStack {
                    Text(NSLocalizedString("heading_please_sign_in_with_credentials", tableName: nil, bundle: bundle, value: "", comment: ""))
                        .font(.system(size: Dimen.text_size_heading2))
                        .foregroundColor(Color("heading_color", bundle: bundle))
                    Spacer(minLength: 25)
                }.padding(.top, 30)
                .padding(.all, 15)
                
                //Error view
                HStack {
                    Image(IconNames.Error, bundle: bundle)
                        .frame(width: Dimen.width_height_error_icon, height: Dimen.width_height_error_icon, alignment: .leading)
                    Text(NSLocalizedString("error_enter_valid_username_password", tableName: nil, bundle: bundle, value: "", comment: ""))
                        .font(.system(size: Dimen.text_size_error_msg))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                        .foregroundColor(Color("error_color", bundle: bundle))
                }.hidden()
                
                HStack {
                    Text(NSLocalizedString("label_email_or_mobile_number", tableName: nil, bundle: bundle, value: "", comment: ""))
                        .font(.system(size: Dimen.text_size_label))
                        .foregroundColor(Color("label_color", bundle: bundle))
                    Spacer()
                }.padding(EdgeInsets(top: 10, leading: 16, bottom: 0, trailing: 16))
                
                TextField(NSLocalizedString("label_email_or_mobile_number", tableName: nil, bundle: bundle, value: "", comment: ""), text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .border(Color("border_color_text_field", bundle: bundle), width: 1)
                    .cornerRadius(Dimen.text_field_corner_radius)
                    .padding(EdgeInsets(top: 5, leading: 16, bottom: 0, trailing: 16))
                    .frame(width: .infinity , height: Dimen.height_text_field)
                
                HStack {
                    Text(NSLocalizedString("label_password", tableName: nil, bundle: bundle, value: "", comment: ""))
                        .font(.system(size: Dimen.text_size_label))
                        .foregroundColor(Color("label_color", bundle: bundle))
                    Spacer()
                }.padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                SecureField(NSLocalizedString("label_password", tableName: nil, bundle: bundle, value: "", comment: ""), text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .border(Color("border_color_text_field", bundle: bundle), width: 1)
                    .cornerRadius(Dimen.text_field_corner_radius)
                    .padding(EdgeInsets(top: 5, leading: 16, bottom: 0, trailing: 16))
                    .frame(width: .infinity , height: Dimen.height_text_field)
                
                //SignIn Button
                HStack {
                    Spacer()
                    Button(action: {
                        print("Submit tapped!")
                    }) {
                        HStack(alignment: .center) {
                            Text(NSLocalizedString("btn_submit", tableName: nil, bundle: bundle, value: "", comment: ""))
                                .fontWeight(.semibold)
                                .font(.system(size: Dimen.text_size_btn_submit))
                                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
                                .foregroundColor(Color("btn_color", bundle: bundle))
                            Spacer()
                            Image(IconNames.RightArrow, bundle: bundle)
                                .frame(width: 18, height:15.35)
                                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 21))
                        }
                        .frame(width: Dimen.width_btn_submit , height: Dimen.height_btn_submit, alignment: .leading)
                        .padding(EdgeInsets(top: 0, leading: 21, bottom: 0, trailing: 0))
                        .foregroundColor(.white)
                        .background(LinearGradient(gradient: Gradient(colors: [Color("color_linear_gradient2", bundle: bundle), Color("color_linear_gradient1", bundle: bundle)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(Dimen.btn_corner_radius)
                    }.padding(EdgeInsets(top: 45, leading: 0, bottom: 0, trailing: 16))
                }
                
                
                Spacer()
                
            }.background(Color.white)
            .cornerRadius(Dimen.parent_corner_radius, corners: [.topLeft, .topRight])
        }.background(Color.yellow)
        .ignoresSafeArea()
        
    }
}


struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView()
                .previewDevice("iPhone 12 mini")
            LoginView()
                .previewDevice("iPhone 12 Pro Max")
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

