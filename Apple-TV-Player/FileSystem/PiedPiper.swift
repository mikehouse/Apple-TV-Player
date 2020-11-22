//
//  PiedPiper.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 22.11.2020.
//

import Foundation
import Compression

final class PiedPiper {
    private let pageSize = 128
    
    func compress(string: String) throws -> Data {
        let sourceData = string.data(using: .utf8)!
        return try compress(data: sourceData)
    }
    
    func compress(data sourceData: Data) throws -> Data {
        var compressedData = Data()
        let outputFilter = try OutputFilter(.compress, using: .lzfse) { (data: Data?) -> Void in
            if let data = data {
                compressedData.append(data)
            }
        }
        var index = 0
        let bufferSize = sourceData.count
        
        while true {
            let rangeLength = min(pageSize, bufferSize - index)
            
            let subdata = sourceData.subdata(in: index..<index + rangeLength)
            index += rangeLength
            
            try outputFilter.write(subdata)
            
            if (rangeLength == 0) {
                break
            }
        }
        return compressedData
    }
    
    func decompress(data compressedData: Data) throws -> Data {
        var decompressedData = Data()
        var index = 0
        let bufferSize = compressedData.count
        
        let inputFilter = try InputFilter(.decompress,
            using: .lzfse) { (length: Int) -> Data? in
            let rangeLength = min(length, bufferSize - index)
            let subdata = compressedData.subdata(in: index..<index + rangeLength)
            index += rangeLength
            return subdata
        }
        while let page = try inputFilter.readData(ofLength: pageSize) {
            decompressedData.append(page)
        }
        return decompressedData
    }
}
