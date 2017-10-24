//
//  ViewController.swift
//  DefinationCreator
//
//  Created by SunYang on 2017/7/4.
//  Copyright © 2017年 SunYang. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        var str = "- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath" as NSString
        let pattern = "\\([^)]*\\)"
//        let regex = try! NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options(rawValue:0))
//        let res = regex.matches(in: str as String, options: NSRegularExpression.MatchingOptions(rawValue:0), range: NSMakeRange(0, str.length))
//        for result in res {
//            str = str.replacingCharacters(in: result.range, with: "") as NSString
//        }
        str = str.replacingOccurrences(of: pattern, with: "", options: [NSString.CompareOptions.regularExpression], range: NSMakeRange(0, str.length)) as NSString
        print(str)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

extension String {
    
    var count: Int {
        let string_NS = self as NSString
        return string_NS.length
    }
    
    func pregReplace(pattern: String, with: String,
                     options: NSRegularExpression.Options = []) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        return regex.stringByReplacingMatches(in: self, options: [],
                                              range: NSMakeRange(0, self.count),
                                              withTemplate: with)
    }
}
