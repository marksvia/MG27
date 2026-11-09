//
//  NeoSpringView.swift
//  GestaltLab
//
//  WebKit-based respring. Approach from rooootdev/neospring, originally by
//  neonmodder123 and ported to Swift by skadz108.
//  https://github.com/rooootdev/neospring
//
//  The trick works by making the WebContent process balloon until the system
//  jetsams it, which takes SpringBoard down with it. On iOS 27 that frequently
//  does nothing, so this view never blocks: it gives the trick a few seconds,
//  then shows an explicit way out.
//

import SwiftUI
import WebKit

struct NeoSpringView: View {
    /// Called when the user gives up waiting, or the timeout expires.
    let onDismiss: () -> Void

    @State private var startsRespring = false
    @State private var showEscape = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView().tint(.white)
                Text("正在刷新 SpringBoard…")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))

                if showEscape {
                    VStack(spacing: 8) {
                        Text("这次 respring 没生效，系统可能已经忽略了这个手法。")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 32)

                        Button {
                            onDismiss()
                        } label: {
                            Text("退出")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Text("改动已经写入，重启设备同样生效。")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .transition(.opacity)
                }
            }

            // The web view must not eat touches, or the escape button is
            // unreachable once the payload starts hammering the process.
            if startsRespring {
                NeoSpringWebView()
                    .brightness(-1)
                    .allowsHitTesting(false)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            startsRespring = true

            // Give the payload ~6s to take SpringBoard down. If we are still
            // here, it did not work.
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.easeInOut(duration: 0.25)) { showEscape = true }
        }
    }
}

private struct NeoSpringWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isUserInteractionEnabled = false
        webView.loadHTMLString(Self.document, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private static let document = #"""
    <!DOCTYPE html>
    <html>
      <body>
        <iframe id="frame" srcdoc="" sandbox="allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-popups allow-presentation allow-scripts"></iframe>
        <script>
          const frame = document.getElementById('frame');
          const payload = `
            <html>
              <body>
                <script>
                  const container = document.createElement('div');
                  container.style.cssText = 'perspective: 1px; perspective-origin: 9999999% 9999999%;';
                  document.body.appendChild(container);

                  for (let i = 0; i < 500; i++) {
                    const layer = document.createElement('div');
                    layer.style.cssText = 'position: absolute; width: 100vw; height: 100vh; backdrop-filter: blur(100px); -webkit-backdrop-filter: blur(100px); transform: translate3d(100000px, 100000px, ' + i + 'px) rotateY(90deg);';
                    container.appendChild(layer);
                  }

                  setInterval(() => {
                    navigator.share({ title: 'R', text: 'R'.repeat(100000) }).catch(() => {});
                    const bytes = new Uint8Array(1024 * 1024 * 10);
                    crypto.getRandomValues(bytes);
                  }, 0);
                <\/script>
              </body>
            </html>
          `;
          frame.srcdoc = payload;
        </script>
      </body>
    </html>
    """#
}
