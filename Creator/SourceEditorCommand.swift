//
//  SourceEditorCommand.swift
//  Creator
//
//  Created by SunYang on 2017/7/4.
//  Copyright © 2017年 SunYang. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        var className: String?
        var methodObjects = [MethodObject]()
        //        var foundDefination = false
        var currentNotes = [String]()
        var currentDefinations = [(String, Int)]()
        var foundMethod = false
        var methodCount = 0
        var writeOffset = 0
        
        
        
        
        for index in 0..<invocation.buffer.lines.count {
            // get line
            let line = invocation.buffer.lines[index] as! String
            
            //handle definations
            
            if isDefinationBegin(line: line) {
                currentDefinations.removeAll()
            }
            
            if isDefination(line: line, index: index, invocation: invocation) {
                currentDefinations.append((line, index))
            }
            
            
            
            // handle class name
            if line.contains("@implementation") {
                className = line.components(separatedBy: " ")[1].replacingOccurrences(of: "\n", with: "")
            }
            if line.contains("@end") {
                className = nil
            }
            
            if isNote(line: line) {
                currentNotes.append(line.replacingOccurrences(of: "\n", with: ""))
            }
            
            if let cn = className {
                
                // handle method
                if !foundMethod && isInstanceMethod(line: line) {
                    foundMethod = true
                    let mo = MethodObject()
                    mo.methodName = getMethodName(line: line)
                    mo.belongClass = cn
                    mo.beginLine = index
                    methodObjects.append(mo)
                }
                
                if foundMethod {
                    // handle method count
                    if line.contains("{") {
                        methodCount += 1
                    }
                    if line.contains("}") {
                        methodCount -= 1
                        if methodCount <= 0 {
                            foundMethod = false
                            methodCount = 0
                            // remove notes
                            if let mo = methodObjects.last {
                                mo.notes = currentNotes
                                mo.originDefinations = currentDefinations
                            }
                            currentDefinations.removeAll()
                            currentNotes.removeAll()
                        }
                    }
                    
                    //handle resource
                    if isResource(line: line) {
                        if let mo = methodObjects.last {
                            for subString in line.components(separatedBy: "ResConfigLoader sharedInstance") {
                                if let resourceString = getResourceName(line: subString) {
                                    if subString.contains(" Color") || subString.contains("]Color") {
                                        mo.appendResource(newResource: resourceString, type: .Color)
                                    }
                                    if subString.contains(" Image") || subString.contains("]Image"){
                                        mo.appendResource(newResource: resourceString, type: .Image)
                                    }
                                    if subString.contains(" Font") || subString.contains("]Font"){
                                        mo.appendResource(newResource: resourceString, type: .Font)
                                    }
                                }
                            }
                        }
                    }
                    
                    //handle process
                    if isProcess(line: line) {
                        if let mo = methodObjects.last {
                            let subString = line.components(separatedBy: "[ProcessPluginManager sharedInstance]").last!
                            if let processString = getResourceName(line: subString) {
                                mo.appendResource(newResource: processString, type: .Process)
                            }
                        }
                    }
                    
                    //handle super
                    if hasSuper(line: line) {
                        if let mo = methodObjects.last {
                            mo.override = true
                        }
                    }
                }
                
            }
            
        }
        
        //wite new defination
        for mo in methodObjects {
            if !mo.needDefinate() {
                continue
            }
            
            for (_, index) in mo.originDefinations {
                invocation.buffer.lines.removeObject(at: index + writeOffset)
                writeOffset -= 1
            }
            
            
            var index = mo.beginLine + writeOffset
            for var defination in mo.getDefinationBody() {
                defination += "\n"
                invocation.buffer.lines.insert(defination, at: index)
                index += 1
            }
            writeOffset += mo.definationRows
        }
        
        
        
        
        
        completionHandler(nil)
    }
    
    func hasSuper(line: String) -> Bool {
        return line.contains("[super ");
    }
    
    func isNote(line: String) -> Bool {
        return line.contains("@HNOTES:")
    }
    
    func isProcess(line: String) -> Bool {
        return line.contains("[ProcessPluginManager sharedInstance]")
    }
    
    func isInstanceMethod(line: String) -> Bool {
        let newLine = line.replacingOccurrences(of: " ", with: "")
        return newLine.hasPrefix("-(")
    }
    
    func isDefinationBegin(line: String) -> Bool {
        return line.contains("/* @HBEGIN")
    }
    
    func isDefination(line: String, index: Int, invocation: XCSourceEditorCommandInvocation) -> Bool {
        if line == " */\n" {
            let foreLine = invocation.buffer.lines[index - 1] as! String
            if foreLine.contains("@HEND") {
                return true
            } else {
                return false
            }
        } else {
            return line.contains("* @H")
        }
    }
    
    func isResource(line: String) -> Bool {
        return line.contains("[ResConfigLoader sharedInstance]")
    }
    
    func getResourceName(line: String) -> String? {
        let pattern = "\\\"[^\"]*\\\""
        let reg = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let result = reg.matches(in: line, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSMakeRange(0, line.characters.count)).first
        if result != nil {
            let temp = line as NSString
            return temp.substring(with: result!.range).replacingOccurrences(of: "\"", with: "")
        } else {
            return nil
        }
    }
    
    func getMethodName(line: String) -> String {
        var temp = line as NSString
        temp = temp.replacingOccurrences(of: "{", with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) as NSString
        
        let pattern = "\\([^)]*\\)"
        let lineWithoutBracket = temp.replacingOccurrences(of: pattern, with: "", options: [NSString.CompareOptions.regularExpression], range: NSMakeRange(0, temp.length)).replacingOccurrences(of: "\n", with: "")
        let components = lineWithoutBracket.components(separatedBy: " ")
        var newComponents = [String]()
        for var com in components {
            if com.contains(":") {
                com = com.components(separatedBy: ":").first!
                //                com.append(":")
            }
            newComponents.append(com)
        }
        return newComponents.last!.replacingOccurrences(of: "-", with: "")
    }
    
    
}


class MethodObject: NSObject {
    
    enum MethodObjectResourceType {
        case Color, Image, Font, Process
    }
    
    var belongClass = ""
    var methodName = ""
    var override = false
    var beginLine = 0
    var fileType = ""
    
    var originDefinations = [(String, Int)]()
    var fonts = [String]()
    var colors = [String]()
    var images = [String]()
    var processes = [String]()
    
    var notes = [String]()
    
    var definationRows: Int {
        get {
            if fonts.isEmpty && colors.isEmpty && images.isEmpty && processes.isEmpty && notes.isEmpty {
                return 0
            } else {
                return 6 + fonts.count + images.count + colors.count + processes.count + notes.count
            }
        }
    }
    
    func needDefinate() -> Bool {
        return !(definationRows == 0)
    }
    
    func appendResource(newResource: String, type: MethodObjectResourceType) {
        var resourceArray = [String]()
        switch type {
        case .Color:
            resourceArray = colors
        case .Image:
            resourceArray = images
        case .Font:
            resourceArray = fonts
        case .Process:
            resourceArray = processes
        }
        for resource in resourceArray {
            if newResource == resource {
                return
            }
        }
        resourceArray.append(newResource)
        switch type {
        case .Color:
            colors = resourceArray
        case .Image:
            images = resourceArray
        case .Font:
            fonts = resourceArray
        case .Process:
            processes = resourceArray
        }
    }
    
    func getDefinationBody() -> [String] {
        var fin = [String]()
        fin.append("/* @HBEGIN")
        fin.append(" * @HCLASS: \(belongClass)")
        fin.append(" * @HFUNC: \(methodName)")
        fin.append(" * @HOVERRIDE: \(override ? "NO" : "YES")")
        
        for color in colors {
            fin.append(" * @HCOLOR: \(color)")
        }
        
        for font in fonts {
            fin.append(" * @HFONT: \(font)")
        }
        
        for image in images {
            fin.append(" * @HIMAGE: \(image)")
        }
        
        for process in processes {
            fin.append(" * @HPROCESS: \(process)")
        }
        
        for note in notes {
            fin.append(note)
        }
        
        fin.append(" * @HEND")
        fin.append(" */")
        return fin
    }
    
}
