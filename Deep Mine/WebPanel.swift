import SwiftUI
import WebKit

// Fullscreen / sheet WebView wrapper. Renamed per-app: deepMine* prefix.
struct DeepMineWebPanel: UIViewRepresentable {
    let deepMineURLString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.isOpaque = true
        webView.backgroundColor = UIColor(DDMPalette.background)
        if let url = URL(string: deepMineURLString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    // MUST be empty — never reload on SwiftUI re-renders.
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
