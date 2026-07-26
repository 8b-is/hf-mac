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
        config.mediaTypesRequiringUserActionForPlayback = []
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

    /// Local file → offline (grant read access to the spaces directory root); else network.
    private func load(_ url: URL, in wv: WKWebView) {
        if url.isFileURL {
            let readAccessDir = url.deletingLastPathComponent()
            wv.loadFileURL(url, allowingReadAccessTo: readAccessDir)
        } else {
            wv.load(URLRequest(url: url))
        }
    }
}
