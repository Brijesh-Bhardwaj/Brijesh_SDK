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
            
            Text("Password")
            SecureField("Password", text: $password)
            
            //Sign Button
            Button(action: {
                
            }, label: {
                Text("Submit")
            })
            
            Spacer()
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}

struct LoginView_Previews_2: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}

struct LoginView_Previews_3: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}

struct LoginView_Previews_4: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
