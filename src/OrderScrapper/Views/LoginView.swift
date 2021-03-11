//
//  LoginView.swift
//  OrderScrapper

import Foundation
import SwiftUI
struct LoginView : View {
    @State private var email: String = ""
    @State private var password: String = ""
    var bundleIdentifier = "ai.blackstraw.orderscrapper.OrderScrapper"
    
    var body: some View {
        VStack {
            Spacer(minLength: 45)
            HStack {
                Image("arrow-back", bundle: Bundle(identifier: bundleIdentifier))
                    .frame(width: 23.25, height: 23.25)
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 16))
                Text("Connect Amazon Account")
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                Spacer()
            }
            
            Spacer(minLength: 25)
            VStack {
                HStack {
                    Text("Please sign in with your Amazon credentials")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                    Spacer(minLength: 25)
                }.padding(.top, 30)
                .padding(.all, 15)
                
                //Error view
                HStack {
                    Image("error", bundle: Bundle(identifier: bundleIdentifier))
                        .frame(width: 23.25, height: 23.25, alignment: .leading)
                    Text("Your email or mobile number and/or password do not match. Please try again")
                        .font(.system(size: 12))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                        .foregroundColor(.init(UIColor(red: 0.827, green: 0.329, blue: 0, alpha: 1)))
                }.hidden()
                
                HStack {
                    Text("Email or mobile number")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    Spacer()
                }.padding(EdgeInsets(top: 10, leading: 16, bottom: 0, trailing: 16))
                
                TextField("Email address", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .border(Color.yellow, width: 1)
                    .cornerRadius(4)
                    .padding(EdgeInsets(top: 5, leading: 16, bottom: 0, trailing: 16))
                    .frame(width: .infinity , height: 40)
                
                HStack {
                    Text("Password")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    Spacer()
                }.padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .border(Color.yellow, width: 1)
                    .cornerRadius(4)
                    .padding(EdgeInsets(top: 5, leading: 16, bottom: 0, trailing: 16))
                    .frame(width: .infinity , height: 40)
                
                //SignIn Button
                HStack {
                    Spacer()
                    Button(action: {
                        print("Submit tapped!")
                    }) {
                        HStack(alignment: .center) {
                            Text("Submit")
                                .fontWeight(.semibold)
                                .font(.system(size: 18))
                                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
                            Spacer()
                            Image("arrow-right", bundle: Bundle(identifier: bundleIdentifier))
                                .frame(width: 18, height:15.35)
                                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 21))
                        }
                        .frame(width: 133 , height: 48, alignment: .leading)
                        .padding(EdgeInsets(top: 0, leading: 21, bottom: 0, trailing: 0))
                        .foregroundColor(.white)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.yellow, Color.orange]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(24)
                    }.padding(EdgeInsets(top: 45, leading: 0, bottom: 0, trailing: 16))
                }
                
                
                Spacer()
                
            }.background(Color.white)
            .cornerRadius(35, corners: [.topLeft, .topRight])
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

