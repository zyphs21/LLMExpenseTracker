//
//  JSONDecoder+Ext.swift
//  LLMExpenseTracker
//
//  Created by ZhangYuanping on 2024/11/18.
//  


import Foundation

extension JSONDecoder {
    // 将Codable对象转换为JSON字符串的通用方法
    public static func convertToJSONString<T: Codable>(_ object: T) -> String? {
        do {
            let encoder = JSONEncoder()
            // 处理日期类型的配置示例
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(object)
            return String(data: data, encoding:.utf8)
        } catch {
            print("编码出错: \(error)")
            return nil
        }
    }

    // 将JSON字符串转换为Codable对象的通用方法
    public static func convertFromJSONString<T: Codable>(_ jsonString: String) -> T? {
        guard let data = jsonString.data(using:.utf8) else {
            print("无法将JSON字符串转换为Data类型")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            // 处理日期类型的配置示例
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("解码出错: \(error)")
            return nil
        }
    }
}

