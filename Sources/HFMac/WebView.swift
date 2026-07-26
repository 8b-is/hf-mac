import SwiftUI
import WebKit

/// Embeds a live Hugging Face Space (its `*.hf.space` app) so it runs on the
/// desktop — your quantum games, Gradio demos, static apps. Blends with native
/// macOS glass transparency and caches visited assets.
struct SpaceWebView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var loaded: URL? }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        wv.allowsBackForwardNavigationGestures = true
        load(url, in: wv)
        context.coordinator.loaded = url
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        if context.coordinator.loaded != url {
            load(url, in: wv)
            context.coordinator.loaded = url
        }
    }

    /// Local file → offline (grant read to the whole snapshot dir); else network.
    private func load(_ url: URL, in wv: WKWebView) {
        if url.isFileURL {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            wv.load(URLRequest(url: url))
        }
    }
}
