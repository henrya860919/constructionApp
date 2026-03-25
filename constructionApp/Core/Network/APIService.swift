//
//  APIService.swift
//  constructionApp
//

import Foundation

enum APIService {
    private static let urlSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 60
        return URLSession(configuration: c)
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        return e
    }()

    static func login(baseURL: URL, email: String, password: String) async throws -> LoginResult {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        let url = baseURL.appendingPathComponent("auth/login")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        let parsed = try decoder.decode(LoginResponse.self, from: data)
        let d = parsed.data
        return LoginResult(accessToken: d.accessToken, refreshToken: d.refreshToken, user: d.user)
    }

    /// `GET /app/version`（公開）
    static func fetchAppVersion(baseURL: URL) async throws -> AppVersionDTO {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        let url = baseURL.appendingPathComponent("app").appendingPathComponent("version")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(AppVersionEnvelope.self, from: data).data
    }

    static func refreshSessionTokens(baseURL: URL, refreshToken: String) async throws -> RefreshTokenEnvelope.DataPart {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("refresh")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(["refreshToken": refreshToken])
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(RefreshTokenEnvelope.self, from: data).data
    }

    static func logout(baseURL: URL, token: String) async throws {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("logout")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
    }

    static func fetchMe(baseURL: URL, token: String) async throws -> AuthUser {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        let url = baseURL.appendingPathComponent("auth/me")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(MeResponse.self, from: data).data
    }

    static func listProjects(
        baseURL: URL,
        token: String,
        page: Int = 1,
        limit: Int = FieldListPagination.pageSize
    ) async throws -> ProjectListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("projects"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(ProjectListResponse.self, from: data)
    }

    // MARK: - 報修 repair-requests

    static func listRepairRequests(
        baseURL: URL,
        token: String,
        projectId: String,
        status: String?,
        q: String? = nil,
        page: Int = 1,
        limit: Int = FieldListPagination.pageSize
    ) async throws -> RepairListEnvelope {
        let base = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("repair-requests")
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        var query: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let status, !status.isEmpty {
            query.append(URLQueryItem(name: "status", value: status))
        }
        let trimmedQ = q?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedQ.isEmpty {
            query.append(URLQueryItem(name: "q", value: String(trimmedQ.prefix(200))))
        }
        components.queryItems = query
        guard let url = components.url else { throw APIRequestError.invalidURL }
        return try await authorizedGET(RepairListEnvelope.self, url: url, token: token)
    }

    static func getRepairRequest(
        baseURL: URL,
        token: String,
        projectId: String,
        repairId: String
    ) async throws -> RepairDetailDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("repair-requests")
            .appendingPathComponent(repairId)
        return try await authorizedGET(RepairDetailEnvelope.self, url: url, token: token).data
    }

    static func listRepairExecutionRecords(
        baseURL: URL,
        token: String,
        projectId: String,
        repairId: String
    ) async throws -> [RepairExecutionRecordDTO] {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("repair-requests")
            .appendingPathComponent(repairId)
            .appendingPathComponent("records")
        return try await authorizedGET(RepairRecordsEnvelope.self, url: url, token: token).data
    }

    /// `POST /api/v1/files/upload` — multipart 欄位 `file`、`projectId`、`fileName`、可選 `category`。
    static func uploadProjectFile(
        baseURL: URL,
        token: String,
        projectId: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        category: String?
    ) async throws -> FileUploadEnvelope.DataPart {
        let url = baseURL
            .appendingPathComponent("files")
            .appendingPathComponent("upload")
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        appendField(name: "projectId", value: projectId)
        appendField(name: "fileName", value: fileName)
        if let category, !category.isEmpty {
            appendField(name: "category", value: category)
        }
        let safeFilename = fileName.replacingOccurrences(of: "\"", with: "_")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFilename)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(FileUploadEnvelope.self, from: data).data
    }

    static func createRepairRequest(
        baseURL: URL,
        token: String,
        projectId: String,
        body: CreateRepairRequestBody
    ) async throws -> RepairListItemDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("repair-requests")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(RepairItemEnvelope.self, from: data).data
    }

    static func deleteRepairRequest(
        baseURL: URL,
        token: String,
        projectId: String,
        repairId: String
    ) async throws {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("repair-requests")
            .appendingPathComponent(repairId)
        try await authorizedDELETE(url: url, token: token)
    }

    static func updateRepairRequest(
        baseURL: URL,
        token: String,
        projectId: String,
        repairId: String,
        body: UpdateRepairRequestBody
    ) async throws -> RepairListItemDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("repair-requests")
            .appendingPathComponent(repairId)
        return try await authorizedPATCH(RepairItemEnvelope.self, url: url, token: token, body: body).data
    }

    static func createRepairExecutionRecord(
        baseURL: URL,
        token: String,
        projectId: String,
        repairId: String,
        body: CreateRepairExecutionRecordBody
    ) async throws -> RepairExecutionRecordDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("repair-requests")
            .appendingPathComponent(repairId)
            .appendingPathComponent("records")
        return try await authorizedPOST(
            RepairExecutionRecordItemEnvelope.self,
            url: url,
            token: token,
            body: body
        ).data
    }

    static func updateRepairExecutionRecord(
        baseURL: URL,
        token: String,
        projectId: String,
        repairId: String,
        recordId: String,
        body: UpdateRepairExecutionRecordBody
    ) async throws -> RepairExecutionRecordDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("repair-requests")
            .appendingPathComponent(repairId)
            .appendingPathComponent("records")
            .appendingPathComponent(recordId)
        return try await authorizedPATCH(
            RepairExecutionRecordItemEnvelope.self,
            url: url,
            token: token,
            body: body
        ).data
    }

    // MARK: - 缺失改善 defect-improvements

    static func listDefectImprovements(
        baseURL: URL,
        token: String,
        projectId: String,
        status: String?,
        q: String? = nil,
        page: Int = 1,
        limit: Int = FieldListPagination.pageSize
    ) async throws -> DefectListEnvelope {
        let base = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("defect-improvements")
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        var query: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let status, !status.isEmpty {
            query.append(URLQueryItem(name: "status", value: status))
        }
        let trimmedQ = q?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedQ.isEmpty {
            query.append(URLQueryItem(name: "q", value: String(trimmedQ.prefix(200))))
        }
        components.queryItems = query
        guard let url = components.url else { throw APIRequestError.invalidURL }
        return try await authorizedGET(DefectListEnvelope.self, url: url, token: token)
    }

    static func getDefectImprovement(
        baseURL: URL,
        token: String,
        projectId: String,
        defectId: String
    ) async throws -> DefectDetailDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("defect-improvements")
            .appendingPathComponent(defectId)
        return try await authorizedGET(DefectDetailEnvelope.self, url: url, token: token).data
    }

    static func listDefectExecutionRecords(
        baseURL: URL,
        token: String,
        projectId: String,
        defectId: String
    ) async throws -> [DefectExecutionRecordDTO] {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("defect-improvements")
            .appendingPathComponent(defectId)
            .appendingPathComponent("records")
        return try await authorizedGET(DefectRecordsEnvelope.self, url: url, token: token).data
    }

    static func createDefectImprovement(
        baseURL: URL,
        token: String,
        projectId: String,
        body: CreateDefectImprovementBody
    ) async throws -> DefectListItemDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("defect-improvements")
        return try await authorizedPOST(DefectItemEnvelope.self, url: url, token: token, body: body).data
    }

    static func createDefectExecutionRecord(
        baseURL: URL,
        token: String,
        projectId: String,
        defectId: String,
        body: CreateDefectExecutionRecordBody
    ) async throws -> DefectExecutionRecordDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("defect-improvements")
            .appendingPathComponent(defectId)
            .appendingPathComponent("records")
        return try await authorizedPOST(
            DefectExecutionRecordItemEnvelope.self,
            url: url,
            token: token,
            body: body
        ).data
    }

    static func deleteDefectImprovement(
        baseURL: URL,
        token: String,
        projectId: String,
        defectId: String
    ) async throws {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("defect-improvements")
            .appendingPathComponent(defectId)
        try await authorizedDELETE(url: url, token: token)
    }

    static func updateDefectImprovement(
        baseURL: URL,
        token: String,
        projectId: String,
        defectId: String,
        body: UpdateDefectImprovementBody
    ) async throws -> DefectListItemDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("defect-improvements")
            .appendingPathComponent(defectId)
        return try await authorizedPATCH(DefectItemEnvelope.self, url: url, token: token, body: body).data
    }

    static func updateDefectExecutionRecord(
        baseURL: URL,
        token: String,
        projectId: String,
        defectId: String,
        recordId: String,
        body: UpdateDefectExecutionRecordBody
    ) async throws -> DefectExecutionRecordDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("defect-improvements")
            .appendingPathComponent(defectId)
            .appendingPathComponent("records")
            .appendingPathComponent(recordId)
        return try await authorizedPATCH(
            DefectExecutionRecordItemEnvelope.self,
            url: url,
            token: token,
            body: body
        ).data
    }

    // MARK: - 自主查驗 self-inspections

    static func listSelfInspectionTemplates(
        baseURL: URL,
        token: String,
        projectId: String
    ) async throws -> [SelfInspectionProjectTemplateDTO] {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("self-inspections")
            .appendingPathComponent("templates")
        return try await authorizedGET(SelfInspectionTemplatesEnvelope.self, url: url, token: token).data
    }

    static func getSelfInspectionTemplateHub(
        baseURL: URL,
        token: String,
        projectId: String,
        templateId: String
    ) async throws -> SelfInspectionTemplateHubDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("self-inspections")
            .appendingPathComponent("templates")
            .appendingPathComponent(templateId)
        return try await authorizedGET(SelfInspectionTemplateHubEnvelope.self, url: url, token: token).data
    }

    static func listSelfInspectionRecords(
        baseURL: URL,
        token: String,
        projectId: String,
        templateId: String,
        page: Int = 1,
        limit: Int = FieldListPagination.pageSize
    ) async throws -> SelfInspectionRecordsEnvelope {
        let base = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("self-inspections")
            .appendingPathComponent("templates")
            .appendingPathComponent(templateId)
            .appendingPathComponent("records")
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(max(1, limit))"),
        ]
        guard let url = components.url else { throw APIRequestError.invalidURL }
        return try await authorizedGET(SelfInspectionRecordsEnvelope.self, url: url, token: token)
    }

    static func createSelfInspectionRecord(
        baseURL: URL,
        token: String,
        projectId: String,
        templateId: String,
        body: SelfInspectionCreateRecordBody
    ) async throws -> SelfInspectionRecordDetailDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("self-inspections")
            .appendingPathComponent("templates")
            .appendingPathComponent(templateId)
            .appendingPathComponent("records")
        return try await authorizedPOST(
            SelfInspectionCreateRecordEnvelope.self,
            url: url,
            token: token,
            body: body
        ).data
    }

    static func getSelfInspectionRecord(
        baseURL: URL,
        token: String,
        projectId: String,
        templateId: String,
        recordId: String
    ) async throws -> SelfInspectionRecordDetailDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("self-inspections")
            .appendingPathComponent("templates")
            .appendingPathComponent(templateId)
            .appendingPathComponent("records")
            .appendingPathComponent(recordId)
        return try await authorizedGET(SelfInspectionRecordDetailEnvelope.self, url: url, token: token).data
    }

    static func updateSelfInspectionRecord(
        baseURL: URL,
        token: String,
        projectId: String,
        templateId: String,
        recordId: String,
        body: SelfInspectionCreateRecordBody
    ) async throws -> SelfInspectionRecordDetailDTO {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("self-inspections")
            .appendingPathComponent("templates")
            .appendingPathComponent(templateId)
            .appendingPathComponent("records")
            .appendingPathComponent(recordId)
        return try await authorizedPATCH(
            SelfInspectionRecordDetailEnvelope.self,
            url: url,
            token: token,
            body: body
        ).data
    }

    static func deleteSelfInspectionRecord(
        baseURL: URL,
        token: String,
        projectId: String,
        templateId: String,
        recordId: String
    ) async throws {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("self-inspections")
            .appendingPathComponent("templates")
            .appendingPathComponent(templateId)
            .appendingPathComponent("records")
            .appendingPathComponent(recordId)
        try await authorizedDELETE(url: url, token: token)
    }

    // MARK: - 圖說 drawing-nodes

    static func listDrawingNodes(
        baseURL: URL,
        token: String,
        projectId: String
    ) async throws -> [DrawingNodeDTO] {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("drawing-nodes")
        return try await authorizedGET(DrawingNodeTreeEnvelope.self, url: url, token: token).data
    }

    static func listDrawingRevisions(
        baseURL: URL,
        token: String,
        projectId: String,
        nodeId: String
    ) async throws -> [DrawingRevisionDTO] {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId)
            .appendingPathComponent("drawing-nodes")
            .appendingPathComponent(nodeId)
            .appendingPathComponent("revisions")
        return try await authorizedGET(DrawingRevisionsEnvelope.self, url: url, token: token).data
    }

    /// 下載需 Authorization 的檔案（例如 `/api/v1/files/:id`）。
    static func fetchAuthorizedData(url: URL, token: String) async throws -> Data {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return data
    }

    private static func authorizedGET<T: Decodable>(_ type: T.Type, url: URL, token: String) async throws -> T {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(T.self, from: data)
    }

    private static func authorizedPOST<T: Decodable, B: Encodable>(
        _ type: T.Type,
        url: URL,
        token: String,
        body: B
    ) async throws -> T {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(T.self, from: data)
    }

    private static func authorizedDELETE(url: URL, token: String) async throws {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
    }

    private static func authorizedPATCH<T: Decodable, B: Encodable>(
        _ type: T.Type,
        url: URL,
        token: String,
        body: B
    ) async throws -> T {
        try AppConfiguration.validateAPIBaseIsSecureForRequests()
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await urlSession.data(for: req)
        try throwIfHTTPError(data: data, response: response)
        return try decoder.decode(T.self, from: data)
    }

    private static func throwIfHTTPError(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIRequestError.transport(URLError(.badServerResponse))
        }
        guard (200 ... 299).contains(http.statusCode) else {
            if let env = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw APIRequestError.httpStatus(http.statusCode, env.error.message)
            }
            let raw = String(data: data, encoding: .utf8)
            throw APIRequestError.httpStatus(http.statusCode, raw)
        }
    }
}
