//
//  ProgressBar.swift
//  OrderScrapper
//

import Foundation
import SwiftUI

struct ProgressBar: View {
    @Binding var value: Float
    var progressPadding : CGFloat = 6
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width) - 2*progressPadding,
                                  height: geometry.size.height - 2*progressPadding, alignment: .leading)
                    .foregroundColor(Utils.getColor(key: Colors.ColorRadialGradient1))
                    .padding(.leading, progressPadding)
                Spacer()
            }
            .frame(width: geometry.size.width , height: geometry.size.height)
            .border(Utils.getColor(key: Colors.ColorRadialGradient1), width: 1)
            .background(Color.white)
        }.cornerRadius(10)
    }
}

