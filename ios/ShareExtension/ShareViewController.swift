//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by ChefMind AI on 14/01/2026.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    // TODO: REPLACE THIS WITH YOUR ACTUAL GROUP ID FROM XCODE
    // If you used "group.chefmind_ai" in Xcode, verify it here.
    let hostAppBundleIdentifier = "com.example.chefmindAi" 
    let sharedKey = "ShareMedia"

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        if let content = extensionContext!.inputItems[0] as? NSExtensionItem {
            if let contents = content.attachments {
                for (_, attachment) in (contents).enumerated() {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                            if let url = data as? URL, let self = self {
                                self.redirectToHostApp(type: .url, value: url.absoluteString)
                            }
                        }
                    }
                }
            }
        }
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    enum RedirectType {
        case url
    }

    func redirectToHostApp(type: RedirectType, value: String) {
        // Encoding the URL to ensure it's safe for a query parameter
        guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        
        // Deep Link: ShareMedia://dataUrl=<encoded_url>
        if let url = URL(string: "ShareMedia://dataUrl=\(encodedValue)") {
            var responder: UIResponder? = self
            let selector = sel_registerName("openURL:")
            var isOpen = false
            
            // First try extensionContext.open (iOS 8+)
            // Note: 'open' is available on NSExtensionContext in recent iOS versions for Today widgets, 
            // but for Share Extensions it is sometimes restricted. 
            // However, opening the container app via custom scheme usually works.
            
            self.extensionContext?.open(url, completionHandler: { success in 
                 // If that fails, we fallback or just finish.
                 self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            })
            
            // We return early because we handled the completion inside the open block
            return
        }
        
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}

