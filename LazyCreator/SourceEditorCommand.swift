//
//  SourceEditorCommand.swift
//  LazyCreator
//
//  Created by SunYang on 2017/10/23.
//  Copyright © 2017年 SunYang. All rights reserved.
//

import Foundation
import XcodeKit

let filePath = Bundle.main.path(forResource: "InitializationInfos", ofType: "plist")
let LIInfos = NSDictionary(contentsOfFile: filePath!)
let kPropertyTypePlaceholder = "$__property_type__"
let kPropertyNamePlaceholder = "$__property_name__"
let kPropertyContainerPlaceholder = "$__container__"

let tableFilePath = Bundle.main.path(forResource: "TableViewMould", ofType: "plist")
let TableViewInfos = NSArray(contentsOfFile: tableFilePath!)

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
//        var implementations = Dictionary<Int, String>()
        var propertyObjects = [PropertyObject]()
        
        
        var className = ""
        var implementationIndex = 0
        var writeOffset = 0
        var hasTableView = false
        var interfaceIndex = 0
        
        for (index, object) in invocation.buffer.lines.enumerated() {
            let line = (object as! String).replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: ";", with: "")
            
            
            //check class
            if line.contains("@interface") {
                className = line.components(separatedBy: " ")[1].replacingOccurrences(of: "()", with: "")
                interfaceIndex = index
            }
            if line.contains("@implementation") {
                className = line.components(separatedBy: " ")[1]
            }
            
            if line.contains("@implementation") {
                implementationIndex = index + 1
            }
            
    
            
            // check property
            if line.contains("@property") {
                
                let po = PropertyObject(line: line)
                po.belongClass = className
                propertyObjects.append(po)
                if line.contains("TableView") {
                    hasTableView = true
                }
            }
        }
        
//        for (index, className) in implementations {
//            print("\(index) - \(className)")
//        }
        
        // add Lazy Initializer
        
        invocation.buffer.lines.insert("\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        invocation.buffer.lines.insert("#pragma mark - Lazy Initialized", at: implementationIndex + writeOffset)
        writeOffset += 1
        invocation.buffer.lines.insert("\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        
        
        for po in propertyObjects {
            if !po.needInitializer() {
                continue
            }
            
            for var li in po.getLazyInitialization() {
                li += "\n"
                invocation.buffer.lines.insert(li, at: implementationIndex + writeOffset)
                writeOffset += 1
            }
        }
        
        // add Layouts
        
        invocation.buffer.lines.insert("\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        invocation.buffer.lines.insert("#pragma mark - Layouts", at: implementationIndex + writeOffset)
        writeOffset += 1
        invocation.buffer.lines.insert("\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        
        var layoutMethodName = ""
        if propertyObjects.first!.belongClass.contains("Controller") {
            layoutMethodName = "viewWillLayoutSubviews"
        } else {
            layoutMethodName = "layoutSubviews"
        }
        invocation.buffer.lines.insert("- (void)\(layoutMethodName)\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        
        invocation.buffer.lines.insert("{\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        
        invocation.buffer.lines.insert("    [super \(layoutMethodName)];\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        
        
        for po in propertyObjects {
            if po.isUIKit() {
                let frameString = "    self.\(po.propertyName).frame = CGRectZero;\n"
                invocation.buffer.lines.insert(frameString, at: implementationIndex + writeOffset)
                writeOffset += 1
            }
        }
        
        invocation.buffer.lines.insert("}", at: implementationIndex + writeOffset)
        writeOffset += 1
        
        
        // add tableView stuff
        if hasTableView {
            // add protocol
            var interfaceLine = (invocation.buffer.lines[interfaceIndex] as! String).replacingOccurrences(of: "\n", with: "")
            interfaceLine += "<UITableViewDataSource, UITableViewDelegate>"
            invocation.buffer.lines[interfaceIndex] = interfaceLine
            
            // add methods
            for string in TableViewInfos as! [String] {
                invocation.buffer.lines.insert(string, at: implementationIndex + writeOffset)
                writeOffset += 1
            }
        }
        
        // add actoins
        invocation.buffer.lines.insert("\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        invocation.buffer.lines.insert("#pragma mark - Actions", at: implementationIndex + writeOffset)
        writeOffset += 1
        invocation.buffer.lines.insert("\n", at: implementationIndex + writeOffset)
        writeOffset += 1
        
        for po in propertyObjects {
            if po.propertyType == "UIButton" {
                invocation.buffer.lines.insert("- (void)\(po.propertyName)Click:(\(po.propertyType) *)sender", at: implementationIndex + writeOffset)
                writeOffset += 1
                invocation.buffer.lines.insert("{", at: implementationIndex + writeOffset)
                writeOffset += 1
                invocation.buffer.lines.insert("\n", at: implementationIndex + writeOffset)
                writeOffset += 1
                invocation.buffer.lines.insert("}", at: implementationIndex + writeOffset)
                writeOffset += 1
                invocation.buffer.lines.insert("\n", at: implementationIndex + writeOffset)
                writeOffset += 1
            }
        }
        
        
        
        completionHandler(nil)
    }
    
}

class PropertyObject: NSObject {
    var propertyName = ""
    var belongClass = ""
    var propertyAttributes: [String]?
    var propertyType = ""
    
    
    convenience init(line: String) {
        self.init()
        propertyName = self.getName(line: line)
        propertyType = self.getType(line: line)
        propertyAttributes = self.getAttributes(line: line)
    }
    
    func getName(line: String) -> String
    {
        let name = line.components(separatedBy: " ").last?.replacingOccurrences(of: "*", with: "")
        return name!
    }
    
    func getType(line: String) -> String {
        let type = line.components(separatedBy: ")").last?.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "*", with: "").replacingOccurrences(of: self.getName(line: line), with: "")
        return type!
    }
    
    func getAttributes(line: String) -> [String]?
    {
        let pattern = "[^()]+";
        let reg = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let results = reg.matches(in: line, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSMakeRange(0, line.characters.count))
        if results.count < 2 {
            return nil
        } else {
            let result = results[1]
            let temp = line as NSString
            let tempString = temp.substring(with: result.range).replacingOccurrences(of: " ", with: "")
            return tempString.components(separatedBy: ",")
        }
    }
    
    func getLazyInitialization() -> [String] {
        
        if !needInitializer() {
            return [String]()
        }
        
        var bodyArray = LIInfos![propertyType] as? [String]
        if bodyArray != nil {
            
        } else {
            if isUIKit() {
                bodyArray = LIInfos!["UIKit"] as? [String]
            } else {
                bodyArray = LIInfos!["Foundation"] as? [String]
            }
        }
        var impBody = [String]()
        if bodyArray != nil {
            for var string in bodyArray! {
                string = string.replacingOccurrences(of: kPropertyTypePlaceholder, with: propertyType).replacingOccurrences(of: kPropertyNamePlaceholder, with: propertyName)
                if string.contains(kPropertyContainerPlaceholder) {
                    if belongController() {
                        string = string.replacingOccurrences(of: kPropertyContainerPlaceholder, with: "").components(separatedBy: "||").first!
                    } else {
                        string = string.replacingOccurrences(of: kPropertyContainerPlaceholder, with: "").components(separatedBy: "||").last!
                    }
                }
                impBody.append(string)
            }
        } else {
            impBody.append("- (\(propertyType) *)\(propertyName)")
            impBody.append("{")
            impBody.append("    if (_\(propertyName) == nil)")
            impBody.append("    {")
            if (propertyAttributes?.contains("strong"))! || (propertyAttributes?.contains("retain"))! {
                impBody.append("        _\(propertyName) = [\(propertyType) new];")
            } else {
                impBody.append("        \(propertyType) *\(propertyName) = [\(propertyType) new];")
                impBody.append("        _\(propertyName) = \(propertyName);")
            }
            
            if isUIKit() {
                if belongController() {
                    impBody.append("        [self.view addSubview:_\(propertyName)];")
                } else {
                    impBody.append("        [self addSubview:_\(propertyName)];")
                }
            }
            
            impBody.append("    }")
            impBody.append("    return _\(propertyName);")
            impBody.append("}")
            impBody.append("\n")
        }
        
        return impBody
    }
    
    
    
    
    func isUIKit() -> Bool {
        return propertyType.contains("UI") || propertyType.contains("Controller") || propertyType.contains("Cell")
    }
    
    func isFoundation() -> Bool {
        return propertyType.contains("NS")
    }
    
    func needInitializer() -> Bool {
        return !(propertyAttributes?.contains("assign"))! && (isUIKit() || isFoundation())
    }
    
    func belongController() -> Bool {
        return belongClass.contains("Controller")
    }
    
}



















































