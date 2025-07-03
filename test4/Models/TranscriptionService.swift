import Foundation

class TranscriptionService {
    private let apiKey: String
    private let apiURL = URL(string: "https://api.siliconflow.cn/v1/audio/transcriptions")!
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    enum TranscriptionError: Error, LocalizedError {
        case invalidAudioFile
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case authenticationError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidAudioFile:
                return "无效的音频文件"
            case .networkError(let error):
                return "网络错误：\(error.localizedDescription)"
            case .invalidResponse:
                return "无效的API响应"
            case .apiError(let message):
                return "API错误：\(message)"
            case .authenticationError(let message):
                return "认证错误：\(message)"
            }
        }
    }
    
    func transcribe(audioFileURL: URL) async throws -> String {
        print("开始转写音频文件：\(audioFileURL)")
        
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 检查音频文件是否存在和可访问
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            print("错误：音频文件不存在")
            throw TranscriptionError.invalidAudioFile
        }
        
        // 准备音频文件数据
        guard let audioData = try? Data(contentsOf: audioFileURL) else {
            print("错误：无法读取音频文件数据")
            throw TranscriptionError.invalidAudioFile
        }
        
        print("音频文件大小：\(audioData.count) bytes")
        
        // 构建multipart表单数据
        var bodyData = Data()
        
        // 添加文件数据
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        bodyData.append(audioData)
        bodyData.append("\r\n".data(using: .utf8)!)
        
        // 添加模型参数
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("FunAudioLLM/SenseVoiceSmall\r\n".data(using: .utf8)!)
        
        // 添加语言参数
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("zh\r\n".data(using: .utf8)!)
        
        // 结束标记
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = bodyData
        
        do {
            print("发送API请求...")
            print("请求头：")
            print("Authorization: Bearer [API Key 已隐藏]")
            print("Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "无")")
            print("使用模型：FunAudioLLM/SenseVoiceSmall")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("错误：无效的HTTP响应")
                throw TranscriptionError.invalidResponse
            }
            
            print("API响应状态码：\(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                throw TranscriptionError.authenticationError("API Key 无效或已过期")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "无法解码响应数据"
            print("API响应数据：\(responseString)")
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let message = errorJson["message"] as? String {
                        throw TranscriptionError.apiError(message)
                    }
                    if let error = errorJson["error"] as? String {
                        throw TranscriptionError.apiError(error)
                    }
                }
                throw TranscriptionError.apiError("状态码：\(httpResponse.statusCode)")
            }
            
            // 解析响应
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                print("错误：无法解析API响应")
                throw TranscriptionError.invalidResponse
            }
            
            print("转写成功：\(text)")
            return text
        } catch {
            print("转写过程发生错误：\(error.localizedDescription)")
            if let transcriptionError = error as? TranscriptionError {
                throw transcriptionError
            }
            throw TranscriptionError.networkError(error)
        }
    }
} 