import SwiftUI

@main
struct DeepMineApp: App {
    @State private var deepMineLinkReady: Bool? = nil
    @StateObject private var store = DDMStore()

    private let deepMineSourceLink = "https://deepmines.org/click.php"
    private let deepMineCheckDomain = "termsfeed.com"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = deepMineLinkReady {
                    if ready {
                        DeepMineWebPanel(deepMineURLString: deepMineSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                    } else {
                        ContentView()
                            .environmentObject(store)
                    }
                } else {
                    DeepMineLoadingScreen()
                        .onAppear { deepMineCheckLink() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func deepMineCheckLink() {
        guard let url = URL(string: deepMineSourceLink) else {
            deepMineLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = DeepMineRedirectTracker(checkDomain: deepMineCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    deepMineLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(deepMineCheckDomain) {
                    deepMineLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(deepMineCheckDomain) {
                    deepMineLinkReady = false; return
                }
                if error != nil {
                    deepMineLinkReady = false; return
                }
                deepMineLinkReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if deepMineLinkReady == nil { deepMineLinkReady = false }
        }
    }
}

final class DeepMineRedirectTracker: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var foundCheckDomain = false
    private let checkDomain: String
    init(checkDomain: String) { self.checkDomain = checkDomain }
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(checkDomain) {
            foundCheckDomain = true
        }
        resolvedURL = request.url
        completionHandler(request) // never stop the chain
    }
}
