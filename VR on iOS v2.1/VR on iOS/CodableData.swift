//
//  CodableData.swift
//  VR on iOS
//
//  Created by Brandon on 9/18/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import Foundation
import SceneKit

protocol DataCodable {
    
    var asData: Data { get }
    init?(_ data: Data)
    
}

struct PlayerLocation {
    
    var position: SCNVector3
    var rotation: SCNVector3
    
}

extension PlayerLocation: DataCodable {
    
    var asData: Data {
        
        let dataBuffer: [UInt16] = [compressDistanceForData(position.x), compressDistanceForData(position.y), compressDistanceForData(position.z), compressRotationForData(rotation.x), compressRotationForData(rotation.y), compressRotationForData(rotation.z)]
        
        return dataBuffer.withUnsafeBufferPointer( { Data(buffer: $0) } )
        
    }
    
    init?(_ data: Data) {
        
        let dataArr: [UInt16] = data.withUnsafeBytes { (_ pointer: UnsafePointer<UInt16>) -> [UInt16] in
            
            [UInt16](UnsafeBufferPointer(start: pointer, count: data.count/MemoryLayout<UInt16>.stride))
            
        }
        
        print(dataArr)
        
        if dataArr.count != 6 {
            
            return nil
            
        }
        
        self.position = SCNVector3(decompressDistance(dataArr[0]), decompressDistance(dataArr[1]), decompressDistance(dataArr[2]))
        self.rotation  = SCNVector3(decompressRotation(dataArr[3]), decompressRotation(dataArr[4]), decompressRotation(dataArr[5]))
        
    }
    
}

func compressDistanceForData(_ num: Float) -> UInt16 {
    
    let num = round((num * 100) + 1000)
    
    if num > 2000 {
        
        return 2000
        
    } else if num < 0 {
        
        return 0
        
    }
    
    return UInt16(num)
    
}

func compressRotationForData(_ num: Float) -> UInt16 {
    
    let num = round(GLKMathRadiansToDegrees(num) + 360)
    
    return UInt16(num) % 720
    
}

func decompressDistance(_ num: UInt16) -> CGFloat {
    
    let num = CGFloat(num) - 1000
    
    return num / 100
    
}

func decompressRotation(_ num: UInt16) -> CGFloat {
    
    let num = CGFloat(num) - 360
    
    return CGFloat(GLKMathDegreesToRadians(Float(num)))
    
}

enum ActionType: String {
    case used
    case taken
    case replaced
}

struct TapAction {
    
    var type: ActionType
    var lookingAtObject: VRObject
    var holdingObject: VRObject?
    
}

extension TapAction: DataCodable {
    
    var asData: Data {
        
        var holdingString = "nil"
        
        if let holdingName = holdingObject?.name {
            
            holdingString = holdingName
            
        }
        
        let stringArr: [String] = [lookingAtObject.name ?? "nil", holdingString, "\(type)"]
        
        let string = "\(lookingAtObject.name ?? "nil"), \(holdingString), \(type)"
        
        if let data = string.data(using: .utf8) {
            
            return data
            
        }
        
        return "0".data(using: .utf8)! //stringArr.withUnsafeBufferPointer({ Data(buffer: $0) })
        
    }
    
    init?(_ data: Data, scene: SCNScene) {
        
        /*
         let dataStrings: [String] = data.withUnsafeBytes {(_ pointer: UnsafePointer<String>) -> [String] in
         
         [String](UnsafeBufferPointer(start: pointer, count: data.count/MemoryLayout<String>.stride))
         
         }
         */
        
        let bytes: [UInt8] = data.withUnsafeBytes {(_ pointer: UnsafePointer<UInt8>) -> [UInt8] in
            
            [UInt8](UnsafeBufferPointer(start: pointer, count: data.count/MemoryLayout<UInt8>.stride))
            
        }
        
        guard let dataStrings = String(bytes: bytes, encoding: .utf8)?.components(separatedBy: ", ") else {
            
            return nil
            
        }
        
        print(dataStrings)
        
        if dataStrings.count != 3 {
            
            return nil
            
        }
        
        if dataStrings[0] == "nil" {
            
            //  print("Look at object does not have a name")
            return nil
            
        }
        
        //  print("\(data)")
        
        guard let lookingAtObject = scene.rootNode.childNode(withName: dataStrings[0], recursively: true) else {
            
            return nil
            
        }
        
        if let holdingObject = scene.rootNode.childNode(withName: dataStrings[1], recursively: true) {
            
            self.holdingObject = holdingObject as? VRObject
            
        } else {
            
            self.holdingObject = nil
            
        }
        
        guard let type = ActionType(rawValue: dataStrings[2]) else {
            
            return nil
            
        }
        
        self.lookingAtObject = lookingAtObject as! VRObject
        self.type = type
        
    }
    
    init?(_ data: Data) {
        
        fatalError("ERROR: init(_ data: Data) not usable, use init(_ data: Data, scene: SCNScene) instead.")
        
    }
    
}
