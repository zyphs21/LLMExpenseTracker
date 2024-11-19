//
//  DoubaoAPI.swift
//  LLMExpenseTracker
//
//  Created by ZhangYuanping on 2024/11/18.
//  


import Foundation
import Moya
import RxSwift
import Moya

// 定义API枚举
enum DoubaoAPI {
    case chat(request: ChatRequest)
}

// 定义请求参数的结构体
struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let tools: [Tool]
}
struct ChatMessage: Codable {
    let role: String
    let content: String
    let toolCalls: [ToolCall]?
    
    init(role: String, content: String, toolCalls: [ToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

// 新增 Tool 相关结构体
struct ToolCall: Codable {
    let id: String
    let type: String
    let function: FunctionParam
}

struct FunctionParam: Codable {
    let name: String
    let arguments: String
}

struct Tool: Codable {
    let type: String
    let function: FunctionTool
}

struct FunctionTool: Codable {
    let name: String
    let description: String
    let parameters: Parameters
}

struct Parameters: Codable {
    let properties: [String: Property]
    let required: [String]
    let type: String
}

struct Property: Codable {
    let description: String
    let type: String
}

// 响应模型
struct ChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
}

struct Choice: Codable {
    let index: Int
    let message: ChatMessage
    let logprobs: String?
    let finishReason: String
    
    enum CodingKeys: String, CodingKey {
        case index, message, logprobs
        case finishReason = "finish_reason"
    }
}

struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// 实现 TargetType 协议
extension DoubaoAPI: TargetType {

    static let apiKey = "Bearer xxxxx替换成你的APIKEYxxxxx"
    static let modelFC = "xxxxx替换成你的模型名称xxxxx"

    var baseURL: URL {
        return URL(string: "https://ark.cn-beijing.volces.com")!
    }
    
    var path: String {
        switch self {
        case .chat:
            return "/api/v3/chat/completions"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .chat:
            return .post
        }
    }
    
    var task: Task {
        switch self {
        case .chat(let request):
            return .requestJSONEncodable(request)
        }
    }
    
    var headers: [String: String]? {
        return [
            "Content-Type": "application/json",
            "Authorization": DoubaoAPI.apiKey
        ]
    }
}



class DoubaoService {
    private let provider = MoyaProvider<DoubaoAPI>()
    
    func sendChatRequest(
        _ content: String,
        additionalContent: String = "",
        chatMessages: [ChatMessage] = []
    ) -> Single<ChatResponse> {
        
        var messages = [
            ChatMessage(
                role: "system",
                content:
                """
                你是一个专业的记帐智能助手，根据用户所说的话，选择一个合适的记账 function 来执行。
                \(additionalContent)
                """
            ),
            ChatMessage(
                role: "user",
                content: content
            )
        ]
        messages.append(contentsOf: chatMessages)

        let addExpenseTool = Tool(
            type: "function",
            function: FunctionTool(
                name: "AddExpense",
                description: "添加一项花销",
                parameters: Parameters(
                    properties: [
                        "title": Property(description: "花销的内容", type: "string"),
                        "amount": Property(description: "花销的金额", type: "number"),
                        "category": Property(description: "花销的类别", type: "string"),
                    ],
                    required: [],
                    type: "object"
                )
            )
        )
        
        let deleteExpenseTool = Tool(
            type: "function",
            function: FunctionTool(
                name: "DeleteExpense",
                description: "删除一项花销",
                parameters: Parameters(
                    properties: [
                        "id": Property(description: "该花销的id", type: "string")
                    ],
                    required: ["id"],
                    type: "object"
                )
            )
        )
        
        let updateExpenseTool = Tool(
            type: "function",
            function: FunctionTool(
                name: "UpdateExpense",
                description: "更新当前的已有的一项花销",
                parameters: Parameters(
                    properties: [
                        "id": Property(description: "该花销的id", type: "string"),
                        "title": Property(description: "花销的内容", type: "string"),
                        "amount": Property(description: "花销的金额", type: "number"),
                        "category": Property(description: "花销的类别", type: "string"),
                    ],
                    required: [],
                    type: "object"
                )
            )
        )
        
        let request = ChatRequest(
            model: DoubaoAPI.modelFC,
            messages: messages,
            temperature: 0.8,
            tools: [addExpenseTool, deleteExpenseTool, updateExpenseTool]
        )
        
        let requestJSON = JSONDecoder.convertToJSONString(request)
        print("==request: \(String(describing: requestJSON))")
        
        return provider.rx.request(.chat(request: request))
            // .map(ChatResponse.self)
            .map { response -> (ChatResponse, String) in
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: response.data)
                let jsonString = String(data: response.data, encoding: .utf8) ?? ""
                return (chatResponse, jsonString)
            }
            .map { tuple -> ChatResponse in
                print("Raw JSON response:", tuple.1)
                return tuple.0
            }
    }
    
    @available(*, deprecated, message: "旧的实现")
    func sendChatRequest(content: String) -> Single<ChatResponse> {
        var messages = [
            ChatMessage(
                role: "system",
                content:
                """
                你是一个专业的记帐智能助手，根据用户所说的话，选择一个记账动作来帮助用户，
                请注意用下面动作对应的 JS0N 数据格式返回你的选择：
                ```
                新增花销: {"name": "AddExpense", "parameters": {"id": String, "title": String, "amount": Double, "category": String}}
                删除花销: {"name": "DeleteExpense", "parameters": {"id": String}
                ```
                """
            ),
            ChatMessage(
                role: "user",
                content: content
            )
        ]
        let request = ChatRequest(
            model: DoubaoAPI.modelFC,
            messages: messages,
            temperature: 0.8,
            tools: []
        )
        
        let requestJSON = JSONDecoder.convertToJSONString(request)
        print("==request: \(String(describing: requestJSON))")
        
        return provider.rx.request(.chat(request: request))
            // .map(ChatResponse.self)
            .map { response -> (ChatResponse, String) in
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: response.data)
                let jsonString = String(data: response.data, encoding: .utf8) ?? ""
                return (chatResponse, jsonString)
            }
            .map { tuple -> ChatResponse in
                print("Raw JSON response:", tuple.1)
                return tuple.0
            }
    }
}



