//
//  ExpenseTrackViewController.swift
//  LLMExpenseTracker
//
//  Created by ZhangYuanping on 2024/11/18.
//  


import UIKit
import RxSwift
import SnapKit
import Speech

class ExpenseTrackViewController: UIViewController {

    let disposeBag = DisposeBag()
    private let expenseTracker = ExpenseTracker()
    private var expenses: [ExpenseEntry] = []

    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.register(ExpenseCell.self, forCellReuseIdentifier: ExpenseCell.identifier)
        table.delegate = self
        table.dataSource = self
        return table
    }()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 语音合成
    private let synthesizer = AVSpeechSynthesizer()
    
    private lazy var voiceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .white
        button.layer.cornerRadius = 30
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(voiceButtonTapped), for: .touchUpInside)
        return button
    }()
    
   var chatMessages = [ChatMessage]()

    deinit {
        print("=== ExpenseTrackViewController deinit ===")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.white
        
        setupTableView()
        loadExpenses()
        
//        chat(content: "今天买了一条裤子，花了我 10 块钱")

        setupVoiceButton()
        requestSpeechAuthorization()
    }

    override func viewDidAppear(_ animated: Bool) {
        print("-----viewDidAppear")
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    private func loadExpenses() {
        if case .success(let data) = expenseTracker.fetchAllExpenses(),
           let expenseData = data as? [ExpenseEntry] {
            self.expenses = expenseData
            tableView.reloadData()
        }
    }

    private func setupVoiceButton() {
        view.addSubview(voiceButton)
        voiceButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.width.height.equalTo(60)
        }
    }

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.voiceButton.isEnabled = true
                case .denied, .restricted, .notDetermined:
                    self.voiceButton.isEnabled = false
                    print("Speech recognition authorization denied")
                @unknown default:
                    break
                }
            }
        }
    }

    @objc private func voiceButtonTapped() {
//        chat(content: "删除买裤子的花销")
//        chat(content: "帮忙更新一下，买裤子实际花了66元")
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            voiceButton.tintColor = .systemBlue
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            if let result = result {
                let text = result.bestTranscription.formattedString
                print("Recognized text: \(text)")
                
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.voiceButton.tintColor = .systemBlue
                
                let text = result?.bestTranscription.formattedString ?? ""
                // 发送语音识别的内容给LLM
                chat(content: text)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            voiceButton.tintColor = .systemRed
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension ExpenseTrackViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return expenses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ExpenseCell.identifier, for: indexPath) as? ExpenseCell else {
            return UITableViewCell()
        }
        let expense = expenses[indexPath.row]
        cell.configure(with: expense)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64 // 根据实际内容调整合适的高度
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            
            // 从数据源中删除
            let expenseToDelete = self.expenses[indexPath.row]
            self.expenseTracker.deleteExpense(id: expenseToDelete.id)
            self.expenses.remove(at: indexPath.row)
            
            // 从表格视图中删除
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            completionHandler(true)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        return configuration
    }
}

extension ExpenseTrackViewController {
    func chat(content: String) {
        guard !content.isEmpty else { return }
        let service = DoubaoService()
//        service.sendChatRequest(content: content)
        service.sendChatRequest(content, additionalContent: getAdditionContent())
            .subscribe(onSuccess: { [weak self] response in
                guard let self = self else { return }
                guard let choice = response.choices.first else { return }
                if choice.finishReason == "tool_calls" {
                    self.parseForToolCall(choice.message.toolCalls)
                } else {
                    self.parseForContent(choice.message.content)
                }
            }, onFailure: { error in
                // 处理错误
                print("send chat fail: \(error.localizedDescription)")
            })
            .disposed(by: disposeBag)
    }
    
    func parseChatResponse(_ response: ChatResponse) {
        
    }
    
    @discardableResult
    func parseForContent(_ content: String) -> Bool {
        guard
            let actionModel: ExpenseTrackActionModel = JSONDecoder.convertFromJSONString(content)
        else {
            return false
        }
        switch actionModel.name {
        case .add:
            self.expenseTracker.addExpense(actionModel.parameters)
            self.loadExpenses()
        default:
            break
        }
        return true
    }
    
    @discardableResult
    func parseForToolCall(_ toolCalls: [ToolCall]?) -> Bool {
        guard let toolCall = toolCalls?.first else { return false }
        guard let action = ExpenseTrackAction(rawValue: toolCall.function.name) else {
            return false
        }
        let toolCallParam = toolCall.function.arguments
        switch action {
        case .add:
            guard
                let expense: ExpenseEntry = JSONDecoder.convertFromJSONString(toolCallParam)
            else {
                return false
            }
            print("新增：\(expense)")
            expenseTracker.addExpense(expense)
            loadExpenses()
            if let currentExpenses = JSONDecoder.convertToJSONString(expenseTracker.expenses) {
                let message = ChatMessage(role: "assistant", content: currentExpenses)
                chatMessages.append(message)
            }
        case .delete:
            guard
                let expense: ExpenseEntry = JSONDecoder.convertFromJSONString(toolCallParam)
            else {
                return false
            }
            print("删除：\(expense)")
            expenseTracker.deleteExpense(id: expense.id)
            loadExpenses()
        case .update:
            guard
                let expense: ExpenseEntry = JSONDecoder.convertFromJSONString(toolCallParam)
            else {
                return false
            }
            print("更新：\(expense)")
            expenseTracker.updateExpense(expense)
            loadExpenses()
        default:
            break
        }
        return true
    }
    
    func getAdditionContent() -> String {
        guard let currentExpenses = JSONDecoder.convertToJSONString(expenseTracker.expenses) else {
            return ""
        }
        return """
        当前记录的花销：
        \(currentExpenses)
        """
    }
    
}
