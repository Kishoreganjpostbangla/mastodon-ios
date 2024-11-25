//
//  Mastodon+Entity+Filter.swift
//  
//
//  Created by MainasuK Cirno on 2021/1/28.
//

import Foundation

extension Mastodon.Entity {
    /// Field
    ///
    /// - Since: 2.4.3
    /// - Version: 3.3.0
    /// # Last Update
    ///   2021/1/28
    /// # Reference
    ///  [Document](https://docs.joinmastodon.org/entities/filter/)
    public struct Filter: Codable {
        
        public enum FilterStatus {
            case notFiltered
            case filtered(String)
            case hidden
        }
        
        public enum FilterAction: RawRepresentable, Codable {
            public typealias RawValue = String
            case warn
            case hide
            case _other(String)
            
            public init?(rawValue: String) {
                switch rawValue {
                case "warn": self = .warn
                case "hide": self = .hide
                default: self = ._other(rawValue)
                }
            }
            
            public var rawValue: String {
                switch self {
                case .warn: return "warn"
                case .hide: return "hide"
                case ._other(let value): return value
                }
            }
        }
        
        public typealias ID = String
        
        public let id: ID
        public let phrase: String
        public let context: [Context]
        public let expiresAt: Date?
        public let irreversible: Bool
        public let wholeWord: Bool
        public let filterAction: FilterAction?
        
        enum CodingKeys: String, CodingKey {
            case id
            case phrase
            case context
            case expiresAt = "expires_at"
            case irreversible
            case wholeWord = "whole_word"
            case filterAction = "filter_action"
        }
    }
}

extension Mastodon.Entity.Filter {
    public enum Context: RawRepresentable, Codable, Hashable {
        case home
        case notifications
        case `public`
        case thread
        case account
        
        case _other(String)
        
        public init?(rawValue: String) {
            switch rawValue {
            case "home":                self = .home
            case "notifications":       self = .notifications
            case "public":              self = .`public`
            case "thread":              self = .thread
            case "account":             self = .account
            default:                    self = ._other(rawValue)
            }
        }
        
        public var rawValue: String {
            switch self {
            case .home:                     return "home"
            case .notifications:            return "notifications"
            case .public:                   return "public"
            case .thread:                   return "thread"
            case .account:                  return "account"
            case ._other(let value):        return value
            }
        }
    }
}
