//
//  Object.swift
//  Gryphin
//
//  Created by Dima Bart on 2016-12-23.
//  Copyright © 2016 Dima Bart. All rights reserved.
//

import Foundation

extension Schema {
    final class Object: JsonCreatable {
        
        let kind:        Kind
        let name:        String
        let description: String?
        let fields:      [Field]?
        
        // ----------------------------------
        //  MARK: - Init -
        //
        init(json: JSON) {
            self.kind        = Kind(string: json["kind"] as! String)
            self.name        = json["name"]              as! String
            self.description = json["description"]       as? String
            
            self.fields      = Field.collectionWith(optionalJson: json["fields"] as? [JSON])
        }
    }
}
