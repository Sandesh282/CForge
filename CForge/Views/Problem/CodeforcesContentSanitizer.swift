import WebKit

struct CodeforcesContentSanitizer {
    /// Generates a WKUserScript that sanitizes the Codeforces problem page.
    /// It hides headers, footers, sidebars, and adjusts the layout for mobile viewing.
    static func injectionScript() -> WKUserScript {
        let css = """
            #header, .footer, .menu-box, .sidebar-menu, .roundbox-lt, .roundbox-rt, .roundbox-lb, .roundbox-rb, .second-level-menu, .userbox, .main-menu-list, .invitation-code-form, #topic-1 { display: none !important; }
            #pageContent { margin: 0 !important; width: 100% !important; padding: 10px !important; }
            .ttypography { font-size: 110% !important; }
            body { padding-top: 0 !important; background-color: #ffffff !important; }
        """
        
        let js = """
            var style = document.createElement('style');
            style.innerHTML = `\(css)`;
            document.head.appendChild(style);
        """
        
        return WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
}
