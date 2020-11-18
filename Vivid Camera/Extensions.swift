//
//  Extensions.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/15/20.
//

import Foundation

extension URL {
    /**
     Create a temporary URL path with a date format integrated
     
     - returns: The URL that was created
     
     # Notes: #
     1. The date format will be yyyyMMddHHmmssSSS
     */
    internal static func createDateUrl() -> URL {
        if let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMddHHmmssSSS"
            let filePath: String = "\(documentDirectory)/viv-\(formatter.string(from: Date())).mp4"
            return URL(fileURLWithPath: filePath)
        }
        return URL(fileURLWithPath: "EmptyFilePath")
    }
}
