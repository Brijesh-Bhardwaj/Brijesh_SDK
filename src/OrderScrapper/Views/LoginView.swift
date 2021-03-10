//
//  LoginView.swift
//  OrderScrapper

import Foundation
import SwiftUI
struct LoginView : View {
    
    @State private var email: String = ""
    @State private var password: String = ""
    var body: some View {
        
        
        VStack {
            Text("Please sign in with your Amazon credentials")
            
            Text("Email or mobile number")
            TextField("Email address", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .border(Color.yellow, width: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/)
                .cornerRadius(4)
            
            Text("Password")
            SecureField("Password", text: $password)
                .border(Color.yellow, width: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/)
                .cornerRadius(4)

            //Sign Button
            /*Button(action: {
                
            }, label: {
                Text("Submit")
            })*/
            
            Button(action: {
                print("Submit tapped!")
            }) {
                HStack {
                    Text("Submit")
                        .fontWeight(.semibold)
                        .font(.title)
                    Image(systemName: "arrow")
                        .font(.title)
                    
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(LinearGradient(gradient: Gradient(colors: [Color.orange, Color.yellow]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(24)
            }
            
            Spacer()
        }
        .background(Color.white)
        .cornerRadius(40)
                
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}

