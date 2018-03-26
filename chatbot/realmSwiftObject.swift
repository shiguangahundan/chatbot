//
//  realmSwiftObject.swift
//  chatbot
//
//  Created by Xie Jia Pei on 22/03/2018.
//  Copyright © 2018 Xie Jia Pei. All rights reserved.
//

import Foundation
import RealmSwift

class Message: Object{
    @objc dynamic var senderName = ""
    @objc dynamic var senderID = ""
    @objc dynamic var senderMessage = ""
}
