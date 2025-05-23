//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  FooterView.swift
//  
//  Created by Nacho Soto on 7/20/23.

import RevenueCat
import SwiftUI

#if canImport(WebKit)
import WebKit
#endif

// swiftlint:disable file_length force_unwrapping

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
struct FooterView: View {

    @Environment(\.userInterfaceIdiom)
    private var interfaceIdiom

    var configuration: PaywallData.Configuration
    var mode: PaywallViewMode
    var fonts: PaywallFontProvider
    var color: Color
    var boldPreferred: Bool
    var purchaseHandler: PurchaseHandler
    var displayingAllPlans: Binding<Bool>?

    let localizedBundle: Bundle

    init(
        configuration: TemplateViewConfiguration,
        locale: Locale,
        bold: Bool = false,
        purchaseHandler: PurchaseHandler,
        displayingAllPlans: Binding<Bool>? = nil
    ) {
        self.init(
            configuration: configuration.configuration,
            locale: locale,
            mode: configuration.mode,
            fonts: configuration.fonts,
            color: configuration.colors.text1Color,
            purchaseHandler: purchaseHandler,
            displayingAllPlans: displayingAllPlans
        )
    }

    fileprivate init(
        configuration: PaywallData.Configuration,
        locale: Locale,
        mode: PaywallViewMode,
        fonts: PaywallFontProvider,
        color: Color,
        bold: Bool = false,
        purchaseHandler: PurchaseHandler,
        displayingAllPlans: Binding<Bool>?
    ) {
        self.configuration = configuration
        self.mode = mode
        self.fonts = fonts
        self.color = color
        self.boldPreferred = bold
        self.purchaseHandler = purchaseHandler
        self.displayingAllPlans = displayingAllPlans
        self.localizedBundle = Localization.localizedBundle(locale)
    }

    var body: some View {
        HStack {
            if self.mode.displayAllPlansButton, let binding = self.displayingAllPlans {
                Self.allPlansButton(binding, bundle: self.localizedBundle)

                if self.configuration.displayRestorePurchases || self.tosURL != nil || self.privacyURL != nil {
                    self.separator
                }
            }

            if self.configuration.displayRestorePurchases {
                RestorePurchasesButton(
                    localizedBundle: self.localizedBundle,
                    purchaseHandler: self.purchaseHandler
                )

                if self.tosURL != nil || self.privacyURL != nil {
                    self.separator
                }
            }

            if let url = self.tosURL {
                LinkButton(
                    localizedBundle: self.localizedBundle,
                    url: url,
                    titles: "Terms and conditions", "Terms"
                )

                if self.privacyURL != nil {
                    self.separator
                }
            }

            if let url = self.privacyURL {
                LinkButton(
                    localizedBundle: self.localizedBundle,
                    url: url,
                    titles: "Privacy policy", "Privacy"
                )
            }
        }
        .foregroundColor(self.color)
        .font(self.fonts.font(for: self.font).weight(self.fontWeight))
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .dynamicTypeSize(...Constants.maximumDynamicTypeSize)
        #if targetEnvironment(macCatalyst) || (swift(>=5.9) && os(visionOS))
        .buttonStyle(.plain)
        #endif
    }

    private static func allPlansButton(_ binding: Binding<Bool>, bundle: Bundle) -> some View {
        Button {
            withAnimation(Constants.toggleAllPlansAnimation) {
                binding.wrappedValue.toggle()
            }
        } label: {
            Text("All subscriptions", bundle: bundle)
        }
        .frame(minHeight: Constants.minimumButtonHeight)
    }

    private var separator: some View {
        SeparatorView(bold: self.bold)
    }

    private var bold: Bool {
        return self.boldPreferred && self.interfaceIdiom != .pad
    }

    private var tosURL: URL? {
        #if os(watchOS)
        return nil
        #else
        self.configuration.termsOfServiceURL
        #endif
    }
    private var privacyURL: URL? {
        #if os(watchOS)
        return nil
        #else
        self.configuration.privacyURL
        #endif
    }

    private var fontWeight: Font.Weight { self.bold ? .bold : .regular }

    fileprivate var font: Font.TextStyle {
        return self.interfaceIdiom == .pad
        ? .callout
        : .footnote
    }

}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
private struct SeparatorView: View {

    var bold: Bool

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: self.bold ? self.boldSeparatorSize : self.separatorSize))
            .accessibilityHidden(true)
    }

    @ScaledMetric(relativeTo: .footnote)
    private var separatorSize: CGFloat = 4

    @ScaledMetric(relativeTo: .footnote)
    private var boldSeparatorSize: CGFloat = 5
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
private struct RestorePurchasesButton: View {

    let localizedBundle: Bundle
    let purchaseHandler: PurchaseHandler

    @State
    private var restoredCustomerInfo: CustomerInfo?

    @State
    private var showRestoredCustomerInfoAlert: Bool = false

    var body: some View {
        AsyncButton {
            Logger.debug(Strings.restoring_purchases)

            let (customerInfo, success) = try await self.purchaseHandler.restorePurchases()

            if success {
                Logger.debug(Strings.restored_purchases)
                self.restoredCustomerInfo = customerInfo
                self.showRestoredCustomerInfoAlert = true
            } else {
                Logger.debug(Strings.restore_purchases_with_empty_result)
            }
        } label: {
            let largestText = Text("Restore purchases", bundle: self.localizedBundle)

            if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
                ViewThatFits {
                    largestText
                    Text("Restore", bundle: self.localizedBundle)
                }
                .accessibilityLabel(largestText)
            } else {
                largestText
            }
        }
        .frame(minHeight: Constants.minimumButtonHeight)
        .buttonStyle(.plain)
        .alert(Text("Purchases restored successfully!", bundle: self.localizedBundle),
               isPresented: self.$showRestoredCustomerInfoAlert) {
            Button(role: .cancel) {
                if let restoredCustomerInfo = self.restoredCustomerInfo {
                    Logger.debug(Strings.setting_restored_customer_info)
                    self.showRestoredCustomerInfoAlert = false
                    self.restoredCustomerInfo = nil
                    self.purchaseHandler.setRestored(restoredCustomerInfo)
                }
            } label: { Text("OK") }
        }
    }

}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
private struct LinkButton: View {

    private let localizedBundle: Bundle

    @Namespace
    private var namespace

    @State
    private var displayLink = false

    let url: URL
    let titles: [String]

    init(localizedBundle: Bundle, url: URL, titles: String...) {
        self.localizedBundle = localizedBundle
        self.url = url
        self.titles = titles
    }

    var body: some View {
        #if canImport(WebKit) && !os(macOS) && !targetEnvironment(macCatalyst)
        Button {
            self.displayLink = true
        } label: {
            self.content
        }
        .matchedGeometryEffect(id: self.titles.first ?? "", in: self.namespace)
        .buttonStyle(.plain)
        .sheet(isPresented: self.$displayLink) {
            NavigationView {
                WebView(url: self.url)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle(self.titles.first ?? "")
                    .toolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button {
                                self.displayLink = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
        #else
        Link(destination: self.url) {
            self.content
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            ViewThatFits {
                ForEach(self.titles, id: \.self) { title in
                    self.linkContent(for: title, bundle: self.localizedBundle)
                }
            }
            // Only use the largest label for accessibility
            .accessibilityLabel(
                self.titles.first.map { Self.localizedString($0, self.localizedBundle) }
                ?? ""
            )
        } else if let first = self.titles.first {
            self.linkContent(for: first, bundle: self.localizedBundle)
                .accessibilityLabel(
                    Text(Self.localizedString(self.titles.first ?? "", self.localizedBundle))
                )
        }
    }

    private func linkContent(for title: String, bundle: Bundle) -> some View {
        Text(Self.localizedString(title, bundle))
            .multilineTextAlignment(.center)
            .frame(minHeight: Constants.minimumButtonHeight)
    }

    private static func localizedString(_ string: String, _ bundle: Bundle) -> String {
        return bundle.localizedString(
            forKey: string,
            value: nil,
            table: nil
        )
    }

}

#if canImport(WebKit) && !os(macOS)
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@available(tvOS, unavailable)
private struct WebView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: self.url))

        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

}
#endif

// MARK: - Previews

#if DEBUG && canImport(SwiftUI) && canImport(UIKit)

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@available(watchOS, unavailable)
@available(macOS, unavailable)
@available(tvOS, unavailable)
struct Footer_Previews: PreviewProvider {

    static var previews: some View {
        Self.create(
            displayRestorePurchases: false
        )
        .previewDisplayName("Empty")

        Self.create(
            displayRestorePurchases: true
        )
        .previewDisplayName("Only Restore")

        Self.create(
            displayRestorePurchases: false,
            termsOfServiceURL: URL(string: "https://revenuecat.com/tos")!
        )
        .previewDisplayName("TOS")

        Self.create(
            displayRestorePurchases: true,
            termsOfServiceURL: URL(string: "https://revenuecat.com/tos")!
        )
        .previewDisplayName("Restore + TOS")

        Self.create(
            displayRestorePurchases: true,
            termsOfServiceURL: URL(string: "https://revenuecat.com/tos")!,
            privacyURL: URL(string: "https://revenuecat.com/tos")!
        )
        .previewDisplayName("All")

        Self.create(
            displayRestorePurchases: true,
            termsOfServiceURL: URL(string: "https://revenuecat.com/tos")!,
            privacyURL: URL(string: "https://revenuecat.com/tos")!,
            bold: false
        )
        .previewDisplayName("Not bold")
    }

    private static func create(
        displayRestorePurchases: Bool = true,
        termsOfServiceURL: URL? = nil,
        privacyURL: URL? = nil,
        bold: Bool = true
    ) -> some View {
        FooterView(
            configuration: .init(
                packages: [],
                images: .init(),
                colors: .init(light: TestData.lightColors, dark: TestData.darkColors),
                displayRestorePurchases: displayRestorePurchases,
                termsOfServiceURL: termsOfServiceURL,
                privacyURL: privacyURL
            ),
            locale: Locale.current,
            mode: .fullScreen,
            fonts: DefaultPaywallFontProvider(),
            color: TestData.colors.text1Color,
            bold: bold,
            purchaseHandler: PreviewHelpers.purchaseHandler,
            displayingAllPlans: .constant(false)
        )
    }

}

#endif
