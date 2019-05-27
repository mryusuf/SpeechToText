//
//  Dict.swift
//  SpeechToText
//
//  Created by Indra Permana on 27/05/19.
//  Copyright © 2019 Yusuf Indra. All rights reserved.
//

import Foundation

struct Dict: Decodable {
    let dict: [String]
    
    private enum Key: String, CodingKey {
        case dict = ""
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        
        self.dict = try container.decode([String].self, forKey: .dict)
    }
}
