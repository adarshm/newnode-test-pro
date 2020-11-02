//
//  ViewController.swift
//  NewnodeTest
//
//  Created by apple on 02/11/20.
//

import UIKit

import Foundation
import NewNode

typealias ResponseCallBack = (_ statusCode: Int?, _ response: Any?, _ error: Error?) -> Void

class ViewController: UIViewController {

    override func viewDidLoad() {
        
        super.viewDidLoad()
    }

    @IBAction func testButtonTapped(sender: Any) {

        let url = "https://rss.weatherzone.com.au/?u=12994-1285&lt=aploc&lc=624&obs=1&fc=1&warn=1&_ga=2.30359615.1268443687.1604308759-2069924304.1604308759&time=\(Date().timeIntervalSince1970)"
//        let url = "https://rss.weatherzone.com.au/?u=12994-1285&lt=aploc&lc=624&obs=1&fc=1&warn=1&_ga=2.30359615.1268443687.1604308759-2069924304.1604308759"
        newnodeGetRequest(url: url,
                       parameters: [:]) { (status, response, error) in
        }
    }


    func newnodeGetRequest(url: String!,
                        parameters: [String: String] = [:],
                        responseCallBack: ResponseCallBack!) {

        print("API - URL - ", url ?? "")
        guard let apiUrl = URL(string: url) else { return }

        var urlRequest = URLRequest(url: apiUrl)
        urlRequest.httpMethod = "GET"

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.connectionProxyDictionary = NewNode.connectionProxyDictionary
//        sessionConfig.waitsForConnectivity = true
        let session = URLSession(configuration: sessionConfig)


        let task = session.dataTask(with: urlRequest) {(data: Data?, response: URLResponse?, error: Error?) in

            if let data = data {
                let str = String(decoding: data, as: UTF8.self)
                print("Response", str)
            }

            if let error = error {
                print("Error", error)
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


