

import Foundation
import NewNode

typealias APIClientResponseCallBack = (_ statusCode: Int?, _ response: Any?, _ error: Error?) -> Void

open class APIClient {

    static let client = APIClient()
    fileprivate static let networkUnavailableErrorCode = -1009
    static let defaultTimeoutIntervalForResource: TimeInterval = 60

    var timeoutIntervalForNewnode: TimeInterval = APIClient.defaultTimeoutIntervalForResource
    struct ResponseStatusCode {

        static let success = "success"
        static let failure = "fail"
    }

    init() {

    }

    fileprivate func getHeaderforURL(_ url: String) -> HTTPHeaders {

        var headers = [String: String]()
        headers["content-type"] = url.hasSuffix(".txt") ? "application/text" :  "application/json"
        headers["cookie"] = ("\(Router.Cookie.name)=\(Router.Cookie.value)") // "voltron=True"
        return HTTPHeaders(headers)
    }

    fileprivate func makePOSTRequest(_ service: String!, parameters: [String: Any]? = nil, responseCallBack: APIClientResponseCallBack!) {

        sendRequest(.post, url: service, parameters: parameters, responseCallBack: responseCallBack)
    }

    fileprivate func makeGETRequest(_ service: String!, parameters: [String: Any]? = nil, responseCallBack: APIClientResponseCallBack!) {

        sendRequest(.get, url: service, parameters: parameters, responseCallBack: responseCallBack)
    }

    fileprivate func sendRequest(_ method: Alamofire.HTTPMethod,
                                 url: String!,
                                 parameters: [String: Any]? = nil,
                                 responseCallBack: APIClientResponseCallBack!) {

        switch NetworkPreferences.channel {
        case .unknown, .newnode:
            newnodeRequest(method, url: url, parameters: parameters, responseCallBack: responseCallBack)
        case .vpn:
            vpnRequest(method, url: url, parameters: parameters, responseCallBack: responseCallBack)
        }
    }

    static func get(_ url: String,
                    parameters: [String: Any],
                    successCallBack : @escaping APISuccessCallBack,
                    failureCallBack : @escaping APIFailureCallBack) {

        client.makeGETRequest(url, parameters: parameters) { (httpStatusCode, response, error) in
            parseResponse(response, error, httpStatusCode, successCallBack, failureCallBack)
        }
    }

    static func post(_ url: String,
                     parameters: [String: Any],
                     successCallBack : @escaping APISuccessCallBack,
                     failureCallBack : @escaping APIFailureCallBack) {

        client.makePOSTRequest(url, parameters: parameters) { (httpStatusCode, response, error) in
            parseResponse(response, error, httpStatusCode, successCallBack, failureCallBack)
        }
    }

    static func parseResponse(_ response: Any?,
                              _ error: Error?,
                              _ httpStatusCode: Int?,
                              _ successCallBack: APISuccessCallBack,
                              _ failureCallBack: APIFailureCallBack) {

        guard let httpStatusCode = httpStatusCode else {
            if let nserror = error as NSError?, nserror.code == networkUnavailableErrorCode {
                failureCallBack(createNSErrorObj(error, code: .networkError))
            }
            else {
                failureCallBack(createNSErrorObj(error, code: .apiRetrievingError))
            }
            return
        }
        if HTTPStatusCode.success.contains(httpStatusCode) {
            if let resp = response as? Data {
                successCallBack(resp)
            }
            else {
                failureCallBack(createNSErrorObj(error, code: .apiRetrievingError))
            }
        }
        else {
            failureCallBack(createNSErrorObj(error, code: .apiRetrievingError))
        }
    }

    static func createNSErrorObj(_ error: Error?, code: APIStatusCodes) -> NSError {

        return NSError(domain: Router.baseURL,
                       code: code.errorCode,
                       userInfo: ["error": error?.localizedDescription ?? "Error fetching data"])

    }

}

extension APIClient {

    /*
    func request_with_af(_ method: Alamofire.HTTPMethod,
                 url: String!,
                 parameters: [String: Any]? = nil,
                 responseCallBack: APIClientResponseCallBack!) {


        DebugHelper.log("\(NetworkPreferences.channel.rawValue) - hitting endpoint")
        let headers = getHeaderforURL(url)
        let requestInitTime =  Date()
        session.request(url,
                        method: method,
                        parameters: parameters,
                        encoding: URLEncoding.queryString,
                        headers: headers).responseData { (response) in
                            let diff = Date().seconds(from: requestInitTime)
                            if diff > 5 {
                                DebugHelper.log("\(NetworkPreferences.channel.rawValue) - took more than \(diff) sec  - \(url ?? "")")
                                DebugHelper.record(domain: .buffering, userInfo: ["channel": "\(NetworkPreferences.channel.rawValue)",
                                                                                  "requestStartTime" : requestInitTime,
                                                                                  "requestEndTime":  Date(),
                                                                                  "buffer_time": "\(diff) seconds",
                                                                                  "endpoint": url ?? ""])
                            }
                            DebugHelper.log("\(NetworkPreferences.channel.rawValue) - receiving response")
                            responseCallBack(response.response?.statusCode, response.data ?? [] as Any, response.error)
        }
    }
     */

    func newnodeRequest(_ method: Alamofire.HTTPMethod,
                 url: String!,
                 parameters: [String: Any]? = nil,
                 responseCallBack: APIClientResponseCallBack!) {

        print("NewNode - URL - ", url ?? "")
        let request = try? URLRequest(url: url, method: method, headers: getHeaderforURL(url))
        guard let convertibleReq = request,
            let req = try? URLEncoding.queryString.encode(convertibleReq, with: parameters) else { return }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.connectionProxyDictionary = NewNode.connectionProxyDictionary
        sessionConfig.waitsForConnectivity = true
        sessionConfig.timeoutIntervalForResource = APIClient.client.timeoutIntervalForNewnode
        let session = URLSession(configuration: sessionConfig)

        let requestInitTime =  Date()
        let task = session.dataTask(with: req) {(data: Data?, response: URLResponse?, error: Error?) in

            DebugHelper.log("newnode - receiving response")
            let diff = Date().seconds(from: requestInitTime)
            if diff > 5 {
                DebugHelper.log("newnode - took more than \(diff) sec - \(url ?? "")")
                DebugHelper.record(domain: .buffering, userInfo: ["channel": "newnode",
                                                                  "requestStartTime" : requestInitTime,
                                                                  "requestEndTime":  Date(),
                                                                  "buffer_time": "\(diff) seconds",
                                                                  "endpoint": url ?? ""])
            }
            let httpResponse = response as? HTTPURLResponse

            // Make sure the session is cleaned up.
            session.invalidateAndCancel()
            // Invoke the callback with the result.
            DispatchQueue.main.async {
                responseCallBack(httpResponse?.statusCode, data, error)
            }
        }
        // Start the request task.
        task.resume()
    }

}

extension APIClient {

    func vpnRequest(_ method: Alamofire.HTTPMethod,
                    url: String!,
                    parameters: [String: Any]? = nil,
                    responseCallBack: APIClientResponseCallBack!) {

        let request = try? URLRequest(url: url, method: method, headers: getHeaderforURL(url))
        guard let convertibleReq = request,
            let req = try? URLEncoding.queryString.encode(convertibleReq, with: parameters) else { return }

        let session = NetworkManager.shared.getPsiphoneSession()
        session.configuration.waitsForConnectivity = true
        session.configuration.timeoutIntervalForResource = APIClient.defaultTimeoutIntervalForResource
        let requestInitTime =  Date()
        let getConnectionState = NetworkManager.shared.psiphonTunnel?.getConnectionState()
        let task = session.dataTask(with: req) {(data: Data?, response: URLResponse?, error: Error?) in

            DebugHelper.log("vpn - receiving response")
            let diff = Date().seconds(from: requestInitTime)
            if diff > 5 {
                DebugHelper.log("vpn - took more than \(diff) sec - \(url ?? "")")
                DebugHelper.record(domain: .buffering, userInfo: ["channel": "vpn",
                                                                  "VPNConnectionState" : "\(String(describing: getConnectionState))",
                                                                  "requestStartTime" : requestInitTime,
                                                                  "requestEndTime":  Date(),
                                                                  "buffer_time": "\(diff) seconds",
                                                                  "endpoint": url ?? ""])
            }
            let httpResponse = response as? HTTPURLResponse

            // Make sure the session is cleaned up.
            session.invalidateAndCancel()
            // Invoke the callback with the result.
            DispatchQueue.main.async {
                responseCallBack(httpResponse?.statusCode, data, error)
            }
        }
        // Start the request task.
        task.resume()
    }
}
