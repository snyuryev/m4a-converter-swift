//
//  Helpers.swift
//  ConverterTest
//
//  Created by Sergey Yuryev on 25/01/2017.
//  Copyright © 2017 syuryev. All rights reserved.
//

import Foundation

func now() -> Double {
    return Date().timeIntervalSince1970
}

func diff(start: Double) -> Double {
    return Date().timeIntervalSince1970 - start
}
