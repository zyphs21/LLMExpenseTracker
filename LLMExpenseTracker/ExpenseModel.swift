//
//  ExpenseModel.swift
//  LLMExpenseTracker
//
//  Created by ZhangYuanping on 2024/11/18.
//  

import Foundation

struct ExpenseEntry: Codable, Identifiable {
    let id: String
    var title: String
    var amount: Double
    var category: String
    var date: Date
    
    init(id: String = UUID().uuidString,
         title: String,
         amount: Double,
         category: String,
         date: Date = Date()) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未知"
        amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "其他"
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
    }
}

enum ExpenseTrackAction: String, Codable {
    case add = "AddExpense"
    case delete = "DeleteExpense"
    case update = "UpdateExpense"
    case search = "SearchExpnse"
    case fetchAll = "GetTotalExpense"
}

struct ExpenseTrackActionModel: Codable {
    let name: ExpenseTrackAction
    let parameters: ExpenseEntry
}

enum ExpenseTrackResult {
    case success(Any?)
    case failure(Error)
}

enum ExpenseTrackError: Error {
    case entryNotFound
    case invalidAmount
    case saveFailed
    case loadFailed
}

class ExpenseTracker {
    var expenses: [ExpenseEntry] = []
    
    // 添加新记账
    @discardableResult
    func addExpense(_ entry: ExpenseEntry) -> ExpenseTrackResult {
        expenses.append(entry)
        return .success(nil)
    }
    
    // 删除记账
    @discardableResult
    func deleteExpense(id: String) -> ExpenseTrackResult {
        if let index = expenses.firstIndex(where: { $0.id == id }) {
            expenses.remove(at: index)
            return .success(nil)
        }
        return .failure(ExpenseTrackError.entryNotFound)
    }
    
    // 更新记账
    @discardableResult
    func updateExpense(_ entry: ExpenseEntry) -> ExpenseTrackResult {
        if let index = expenses.firstIndex(where: { $0.id == entry.id }) {
            expenses[index] = entry
            return .success(nil)
        }
        return .failure(ExpenseTrackError.entryNotFound)
    }
    
    // 查询单个记账
    @discardableResult
    func fetchExpense(id: String) -> ExpenseTrackResult {
        if let entry = expenses.first(where: { $0.id == id }) {
            return .success(entry)
        }
        return .failure(ExpenseTrackError.entryNotFound)
    }
    
    // 查询所有记账
    @discardableResult
    func fetchAllExpenses() -> ExpenseTrackResult {
        return .success(expenses)
    }
}
