//
//  Utils.swift
//  Navgi
//
//  Created by Abhishek Chikhalkar on 07/03/25.
//

import ARKit

extension ARWorldTrackingConfiguration {
    func then(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }
}
