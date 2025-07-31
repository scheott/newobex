import Foundation

// MARK: - AI Response Models
struct JournalAIResponse {
    let summary: String
    let insights: [String]
    let reflection: String
    let mood: Int? // 1-10 scale
    let suggestedTags: [String]
}

struct JournalAIRequest {
    let content: String
    let userPath: UserPath
    let previousEntries: [String]? // For context
    let mood: Int? // User's self-reported mood
}

// MARK: - OpenAI API Models
private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int
    let topP: Double
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

private struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Journal AI Service
class JournalAIService {
    static let shared = JournalAIService()
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4"
    
    private init() {
        // Load API key from environment or config
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["OpenAI_API_Key"] as? String {
            self.apiKey = key
        } else {
            // Fallback to environment variable
            self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        }
    }
    
    // MARK: - Main AI Analysis Function
    func analyzeJournalEntry(_ request: JournalAIRequest) async throws -> JournalAIResponse {
        let systemPrompt = createSystemPrompt(for: request.userPath)
        let userPrompt = createUserPrompt(from: request)
        
        let openAIRequest = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.7,
            maxTokens: 800,
            topP: 0.9
        )
        
        let response = try await makeOpenAIRequest(openAIRequest)
        return try parseAIResponse(response.choices.first?.message.content ?? "")
    }
    
    // MARK: - Quick Reflection Generation
    func generateQuickReflection(content: String, userPath: UserPath) async throws -> String {
        let systemPrompt = createReflectionPrompt(for: userPath)
        
        let openAIRequest = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: content)
            ],
            temperature: 0.8,
            maxTokens: 200,
            topP: 0.9
        )
        
        let response = try await makeOpenAIRequest(openAIRequest)
        return response.choices.first?.message.content ?? "Unable to generate reflection."
    }
    
    // MARK: - Mood Analysis
    func analyzeMood(content: String) async throws -> Int {
        let systemPrompt = """
        You are an expert at analyzing emotional tone in personal writing. 
        Rate the overall mood of this journal entry on a scale of 1-10:
        1-3: Very negative (despair, anger, severe stress)
        4-5: Somewhat negative (frustration, sadness, mild stress)
        6-7: Neutral to positive (calm, content, stable)
        8-9: Positive (happy, motivated, optimistic)
        10: Extremely positive (euphoric, deeply fulfilled, peak state)
        
        Respond with only a single number from 1-10.
        """
        
        let openAIRequest = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: content)
            ],
            temperature: 0.3,
            maxTokens: 10,
            topP: 0.5
        )
        
        let response = try await makeOpenAIRequest(openAIRequest)
        let moodString = response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "6"
        return Int(moodString) ?? 6
    }
    
    // MARK: - Private Helper Methods
    private func createSystemPrompt(for path: UserPath) -> String {
        let basePrompt = """
        You are an AI coach specializing in self-discipline and personal growth. You analyze journal entries with wisdom, depth, and practicality. Your responses should be insightful but concise, helping the user gain clarity about their experiences and next steps.
        """
        
        let pathSpecific: String
        switch path {
        case .confidence:
            pathSpecific = """
            This user is on the Confidence path - focused on self-expression, presence, charisma, and social fluidity. Look for themes around:
            - Social interactions and relationships
            - Self-expression and authenticity
            - Presence and charisma development  
            - Overcoming social anxiety or self-doubt
            - Leadership and influence opportunities
            Provide insights that help them show up more boldly and authentically.
            """
        case .clarity:
            pathSpecific = """
            This user is on the Clarity path - focused on stillness, logic, journaling, and intentional thought. Look for themes around:
            - Mental clarity and decision-making
            - Intellectual pursuits and learning
            - Mindfulness and present-moment awareness
            - Systems thinking and problem-solving
            - Values alignment and purpose
            Provide insights that help them think more clearly and act more intentionally.
            """
        case .discipline:
            pathSpecific = """
            This user is on the Discipline path - focused on willpower, endurance, challenge, and grit. Look for themes around:
            - Physical and mental challenges
            - Habit formation and consistency
            - Overcoming resistance and procrastination
            - Goal achievement and milestone progress
            - Building mental toughness
            Provide insights that help them push through obstacles and build unshakeable discipline.
            """
        }
        
        return basePrompt + "\n\n" + pathSpecific + """
        
        Respond in JSON format with these fields:
        {
            "summary": "2-3 sentence summary of the entry's main themes",
            "insights": ["insight 1", "insight 2", "insight 3"],
            "reflection": "A thoughtful reflection question or prompt for deeper thinking",
            "mood": estimated_mood_1_to_10,
            "suggestedTags": ["tag1", "tag2", "tag3"]
        }
        """
    }
    
    private func createReflectionPrompt(for path: UserPath) -> String {
        let pathContext: String
        switch path {
        case .confidence:
            pathContext = "Focus on self-expression, presence, and authentic connection with others."
        case .clarity:
            pathContext = "Focus on mental clarity, intentional thinking, and values alignment."
        case .discipline:
            pathContext = "Focus on building discipline, overcoming challenges, and consistent action."
        }
        
        return """
        You are a wise coach helping someone on their personal growth journey. \(pathContext)
        
        Read their journal entry and provide a brief, insightful reflection or question that helps them think deeper about their experience. Keep it concise (1-2 sentences) and actionable.
        """
    }
    
    private func createUserPrompt(from request: JournalAIRequest) -> String {
        var prompt = "Journal Entry:\n\(request.content)"
        
        if let mood = request.mood {
            prompt += "\n\nUser's self-reported mood: \(mood)/10"
        }
        
        if let previous = request.previousEntries, !previous.isEmpty {
            prompt += "\n\nRecent context (previous entries):\n"
            for (index, entry) in previous.prefix(3).enumerated() {
                prompt += "\nEntry \(index + 1): \(entry.prefix(200))..."
            }
        }
        
        return prompt
    }
    
    private func makeOpenAIRequest(_ request: OpenAIRequest) async throws -> OpenAIResponse {
        guard !apiKey.isEmpty else {
            throw JournalAIError.missingAPIKey
        }
        
        guard let url = URL(string: baseURL) else {
            throw JournalAIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
        } catch {
            throw JournalAIError.encodingError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw JournalAIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw JournalAIError.apiError(message)
                }
                throw JournalAIError.statusCode(httpResponse.statusCode)
            }
            
            let aiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return aiResponse
            
        } catch let error as JournalAIError {
            throw error
        } catch {
            throw JournalAIError.networkError(error)
        }
    }
    
    private func parseAIResponse(_ content: String) throws -> JournalAIResponse {
        // Try to extract JSON from the response
        let jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw JournalAIError.parsingError("Invalid response format")
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            let summary = json?["summary"] as? String ?? "No summary available"
            let insights = json?["insights"] as? [String] ?? []
            let reflection = json?["reflection"] as? String ?? "What did you learn from this experience?"
            let mood = json?["mood"] as? Int
            let suggestedTags = json?["suggestedTags"] as? [String] ?? []
            
            return JournalAIResponse(
                summary: summary,
                insights: insights,
                reflection: reflection,
                mood: mood,
                suggestedTags: suggestedTags
            )
            
        } catch {
            // Fallback parsing if JSON fails
            return JournalAIResponse(
                summary: "Entry recorded successfully",
                insights: ["Reflect on your experience", "Consider what you learned", "Think about next steps"],
                reflection: "What was the most significant part of this experience?",
                mood: nil,
                suggestedTags: ["reflection", "growth"]
            )
        }
    }
}

// MARK: - Error Handling
enum JournalAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case encodingError(Error)
    case networkError(Error)
    case invalidResponse
    case statusCode(Int)
    case apiError(String)
    case parsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .statusCode(let code):
            return "AI service returned status code: \(code)"
        case .apiError(let message):
            return "AI service error: \(message)"
        case .parsingError(let message):
            return "Failed to parse AI response: \(message)"
        }
    }
}