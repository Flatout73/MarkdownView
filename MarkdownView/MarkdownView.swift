import UIKit
import WebKit

/**
 Markdown View for iOS.
 
 - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
 */
open class MarkdownView: UIView {
    
    private var webView: WKWebView?
    
    fileprivate var intrinsicContentHeight: CGFloat? {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }
    
    @objc public var isScrollEnabled: Bool = true {
        
        didSet {
            webView?.scrollView.isScrollEnabled = isScrollEnabled
        }
        
    }
    
    @objc public var onTouchLink: ((URLRequest) -> Bool)?
    
    @objc public var onRendered: ((CGFloat) -> Void)?
    
    public convenience init() {
        self.init(frame: CGRect.zero)
    }
    
    override init (frame: CGRect) {
        super.init(frame : frame)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override var intrinsicContentSize: CGSize {
        if let height = self.intrinsicContentHeight {
            return CGSize(width: UIView.noIntrinsicMetric, height: height)
        } else {
            return CGSize.zero
        }
    }
    
    /// - parameter paddingTop: optional padding at the top of the content view. Should
    ///      be in CSS distance format, e.g. "22px" or "1em". Default is "0".
    ///      (If this string contains quotes or line breaks, it is discarded - for reasons of security)
    @objc public func load(markdown: String?, enableImage: Bool = true, paddingTop: String = "0") {
        guard let markdown = markdown else { return }
        
        let bundle = Bundle(for: MarkdownView.self)
        
        let htmlURL: URL? =
            bundle.url(forResource: "markdownview",
                       withExtension: "html") ??
            bundle.url(forResource: "markdownview",
                       withExtension: "html",
                       subdirectory: "MarkdownView.bundle") ??
            bundle.url(forResource: "markdownview",
                       withExtension: "html",
                       subdirectory: "MarkdownView_MarkdownView.bundle")
        
        if let url = htmlURL {
            let templateRequest = URLRequest(url: url)
            
            let escapedMarkdown = self.escape(markdown: markdown) ?? ""
            let imageOption = enableImage ? "true" : "false"
            var paddingTopScript = "document.getElementById('contents').style.paddingTop = \"\(paddingTop)\";";
            if paddingTop.contains("\"") || paddingTop.contains("\n") || paddingTop.contains("'") {
                paddingTopScript = ""
            }
            let script = "window.showMarkdown('\(escapedMarkdown)', \(imageOption));\(paddingTopScript);"
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            
            let controller = WKUserContentController()
            controller.addUserScript(userScript)
            
            let configuration = WKWebViewConfiguration()
            configuration.userContentController = controller
            configuration.dataDetectorTypes = .phoneNumber
         
            let wv = WKWebView(frame: self.bounds, configuration: configuration)
            wv.scrollView.isScrollEnabled = self.isScrollEnabled
            wv.translatesAutoresizingMaskIntoConstraints = false
            wv.navigationDelegate = self
            addSubview(wv)
            wv.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
            wv.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
            wv.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
            wv.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
            wv.backgroundColor = self.backgroundColor
            
            self.webView = wv
            
            wv.load(templateRequest)
        } else {
            // TODO: raise error
        }
    }
    
    private func escape(markdown: String) -> String? {
        return markdown.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
    }
}

extension MarkdownView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = "document.body.scrollHeight;"
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let _ = error { return }
            
            if let height = result as? CGFloat {
                self?.onRendered?(height)
                self?.intrinsicContentHeight = height
            }
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        switch navigationAction.navigationType {
        case .linkActivated:
            if let onTouchLink = onTouchLink, onTouchLink(navigationAction.request) {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        default:
            decisionHandler(.allow)
        }
    }
}
