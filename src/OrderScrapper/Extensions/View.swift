//
//  View.swift
//  OrderScrapper
//
//  Created by Prakhar on 12/03/21.
//

import Foundation
import SwiftUI
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
