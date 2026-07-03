# ABTasty QA Assistant

This package allows QA teams and developers to easily test campaigns, force variations, and verify flag values in real-time within iOS applications. [Using ABTasty QA Assistant](https://docs.abtasty.com/server-side/integrations/using-abtasty-qa-assistant)

### Table of Contents

* [Overview](#overview)
* [Features](#features)
* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Quick Start](#quick-start)
* [Detailed Integration](#detailed-integration)
  * [Initialize Flagship SDK](#1-initialize-flagship-sdk)
  * [Setup QA Assistant](#2-setup-qa-assistant)
  * [Display Overlay Button](#3-display-overlay-button)
  * [Live Flag Updates](#4-live-flag-updates)
* [Key Features](#key-features)
* [Best Practices](#best-practices)
* [Troubleshooting](#troubleshooting)
* [Additional Resources](#additional-resources)

---

## Overview

The ABTasty QA Assistant provides an intuitive in-app interface for testing A/B campaigns, feature flags, and variations during development and QA phases. It integrates with the Flagship iOS SDK to provide real-time flag updates and comprehensive campaign management, presented as a draggable overlay button and a bottom-sheet panel.

### ⚠️ Production Warning

**Do not ship this package to production!** The QA Assistant is intended for development and QA testing only.

To prevent accidental inclusion in production, wrap initialization in a `#if DEBUG` compile-time check. Since this is a compiler directive, the QA Assistant code is stripped out entirely from Release builds:

```swift
private var qaAssistant: ABTastyQAAssistant?

private func toggleQAAssistant() {
    #if DEBUG
    if qaAssistant == nil {
        qaAssistant = ABTastyQAAssistant("YOUR_ENVIRONMENT_ID", "YOUR_API_KEY")
        qaAssistant?.showOverlayButton(in: self)
    }
    #endif
}
```

---

## Features

* 🎯 **Campaign Management** - View, test, and force variations for A/B tests and feature flags
* 🔄 **Live Flag Updates** - Real-time flag value changes when forcing variations
* 📊 **Allocation Viewer** - Check traffic distribution across variations
* 🎨 **Draggable Overlay Button** - Floating, drag-to-reposition button for easy access during testing
* 🔍 **Targeting Inspection** - Verify targeting rules and conditions
* 📈 **Event Tracking** - Monitor all hits (events, screens, transactions) sent to Flagship
* 🧪 **Variation Testing** - Force specific variations to test different experiences
* 🧭 **Context Viewer** - Inspect the current visitor context

---

## Prerequisites

Before integrating the ABTasty QA Assistant, ensure you have:

* Xcode with a project targeting **iOS 15.0** or higher
* An ABTasty account with:
  * Environment ID
  * API Key
* The [Flagship iOS SDK](https://docs.abtasty.com/server-side/sdks/ios/ios) `~> 5.0.0-beta` installed in your project

---

## Installation

ABTastyQAssistant is distributed via [CocoaPods](https://cocoapods.org) and [Swift Package Manager](https://www.swift.org/package-manager/).

### CocoaPods

Add both the Flagship SDK and QA Assistant to your `Podfile`:

```ruby
target 'YourApp' do
  use_frameworks!

  # Flagship SDK
  pod 'FlagShip', '~> 5.0.0-beta'

  # ABTasty QA Assistant
  pod 'ABTastyQAssistant'
end
```

Then run, from your project's root directory:

```bash
pod install
```

Always open the generated `.xcworkspace` file (not the `.xcodeproj`) afterwards.

### Swift Package Manager

Add the package to your `Package.swift`, or via Xcode's **File > Add Package Dependencies…**:

```swift
dependencies: [
    .package(url: "https://github.com/flagship-io/abtasty-qa-assistant-ios.git", .upToNextMajor(from: "0.7.0"))
]
```

Then add `"ABTastyQAssistant"` to your target's dependencies.

> **Note:** the Flagship SDK's module is named `FlagShip` when installed via CocoaPods and `Flagship` when installed via Swift Package Manager — use the import that matches your installation method (see the Quick Start example below).

---

## Quick Start

Get up and running in 5 minutes with this complete example:

### Step 1: Replace Your Credentials

Replace these placeholders with your actual values:

* `YOUR_ENVIRONMENT_ID` - Your Flagship environment ID
* `YOUR_API_KEY` - Your Flagship API key

### Step 2: Copy & Paste This Code

```swift
import UIKit
import FlagShip // "import Flagship" if you installed via Swift Package Manager
import ABTastyQAssistant

class ViewController: UIViewController {

    private var qaAssistant: ABTastyQAAssistant?
    private let flagValueLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        initFlagship()
    }

    private func initFlagship() {
        // 1. Start Flagship
        Flagship.sharedInstance.start(
            envId: "YOUR_ENVIRONMENT_ID",
            apiKey: "YOUR_API_KEY"
        )

        // 2. Create a visitor
        _ = Flagship.sharedInstance
            .newVisitor(visitorId: "user_123", hasConsented: true)
            .withContext(context: ["isQA": true])
            .build()

        // 3. Setup live updates (register before fetching flags)
        Flagship.sharedInstance.sharedVisitor?.onFlagUpdate = { [weak self] changedKeys in
            DispatchQueue.main.async {
                print("🔔 Flags updated: \(changedKeys)")
                self?.updateFlagValue()
            }
        }

        // 4. Fetch flags
        Flagship.sharedInstance.sharedVisitor?.fetchFlags { [weak self] in
            DispatchQueue.main.async {
                self?.updateFlagValue()
            }
        }
    }

    private func updateFlagValue() {
        let value = Flagship.sharedInstance.sharedVisitor?
            .getFlag(key: "btnTitle")
            .value(defaultValue: "Default Button") ?? "No value"
        flagValueLabel.text = value
    }

    @objc private func toggleQA() {
        if qaAssistant?.isOverlayVisible == true {
            qaAssistant?.hideOverlayButton()
            qaAssistant?.dispose()
            qaAssistant = nil
        } else {
            qaAssistant = ABTastyQAAssistant(
                "YOUR_ENVIRONMENT_ID",
                "YOUR_API_KEY",
                onClose: {
                    print("QA Assistant closed")
                }
            )
            qaAssistant?.showOverlayButton(in: self)
        }
        updateQAButton()
    }

    private func updateQAButton() {
        let imageName = qaAssistant?.isOverlayVisible == true ? "eye.slash" : "ladybug"
        navigationItem.leftBarButtonItem?.image = UIImage(systemName: imageName)
    }

    private func setupUI() {
        title = "ABTasty QA Demo"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ladybug"),
            style: .plain,
            target: self,
            action: #selector(toggleQA)
        )

        flagValueLabel.textAlignment = .center
        flagValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        flagValueLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flagValueLabel)
        NSLayoutConstraint.activate([
            flagValueLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            flagValueLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    deinit {
        Flagship.sharedInstance.sharedVisitor?.onFlagUpdate = nil
        qaAssistant?.dispose()
    }
}
```

### Step 3: Run Your App

Build and run your app on a simulator or device.

### Step 4: Use the QA Assistant

1. **Tap the bug icon** in the navigation bar (top-left)
2. **The QA overlay button appears**, floating above your content — drag it anywhere on screen
3. **Tap the overlay button** to open the QA Assistant bottom sheet
4. **Browse campaigns** and force different variations
5. **Watch the flag value update live** when you select variations

---

## Detailed Integration

### 1. Initialize Flagship SDK

First, initialize the Flagship SDK in your app:

```swift
private func initFlagship() {
    // Start Flagship SDK
    Flagship.sharedInstance.start(
        envId: "YOUR_ENVIRONMENT_ID",
        apiKey: "YOUR_API_KEY"
    )

    // Create a visitor with context
    _ = Flagship.sharedInstance
        .newVisitor(visitorId: "user_123", hasConsented: true)
        .withContext(context: [
            "isQA": true,
            "country": "FR",
            "isVip": false
            // Add your custom context
        ])
        .build()

    print("✅ Flagship SDK initialized")

    // Fetch flags from the server
    Flagship.sharedInstance.sharedVisitor?.fetchFlags {
        print("✅ Flags fetched")
    }
}
```

### 2. Setup QA Assistant

Initialize the QA Assistant with your credentials:

```swift
private func initializeQAAssistant() {
    qaAssistant = ABTastyQAAssistant(
        "YOUR_ENVIRONMENT_ID",
        "YOUR_API_KEY",
        onClose: { [weak self] in
            // Called when the QA Assistant panel is closed
            print("🔄 QA Assistant closed, refreshing flags...")
            self?.refreshFlags()
        }
    )

    print("✅ QA Assistant initialized")
}
```

### 3. Display Overlay Button

Show the floating overlay button on top of a `UIViewController`:

```swift
private func showQAAssistant() {
    initializeQAAssistant()
    qaAssistant?.showOverlayButton(in: self)
}

private func hideQAAssistant() {
    qaAssistant?.hideOverlayButton()
    qaAssistant?.dispose()
    qaAssistant = nil
}

private func toggleQAAssistant() {
    if qaAssistant?.isOverlayVisible == true {
        hideQAAssistant()
    } else {
        showQAAssistant()
    }
}
```

**Add a button in your navigation bar:**

```swift
navigationItem.leftBarButtonItem = UIBarButtonItem(
    image: UIImage(systemName: "ladybug"),
    style: .plain,
    target: self,
    action: #selector(toggleQAAssistant)
)
```

### 4. Live Flag Updates

Enable live flag updates to automatically refresh your UI when flags are modified through the QA Assistant:

```swift
private func setupFlagUpdateListener() {
    Flagship.sharedInstance.sharedVisitor?.onFlagUpdate = { [weak self] changedKeys in
        DispatchQueue.main.async {
            guard let self else { return }
            print("🔔 Live update received for flags: \(changedKeys)")

            // Show a notification
            self.showSyncBanner("🔄 Live update: \(changedKeys.joined(separator: ", "))")

            // Update your UI with new flag values
            self.updateFlagValues()
        }
    }

    print("✅ Flag update listener registered")
}

private func updateFlagValues() {
    guard let visitor = Flagship.sharedInstance.sharedVisitor else { return }

    let buttonTitle = visitor.getFlag(key: "btnTitle").value(defaultValue: "Default") ?? "Default"
    let buttonColor = visitor.getFlag(key: "btnColor").value(defaultValue: "blue") ?? "blue"

    print("Updated flag values:")
    print("  btnTitle: \(buttonTitle)")
    print("  btnColor: \(buttonColor)")
}
```

**Important:** Register the listener *before* fetching flags, so the very first fetch (and any subsequent QA-triggered update) is caught:

```swift
private func initFlagship() {
    Flagship.sharedInstance.start(envId: "ENV_ID", apiKey: "API_KEY")

    _ = Flagship.sharedInstance
        .newVisitor(visitorId: "user_123", hasConsented: true)
        .withContext(context: ["isQA": true])
        .build()

    // ✅ Setup listener before fetching flags
    setupFlagUpdateListener()

    Flagship.sharedInstance.sharedVisitor?.fetchFlags { }
}
```

---

## Key Features

### 🎯 Campaign Management

The QA Assistant provides a comprehensive interface to:

* **View all campaigns** - See active, inactive, and forced campaigns (A/B tests, toggles, personalizations)
* **View variations** - Explore different variations for each campaign with all associated flags
* **Force variations** - Override the default allocation and test specific variations
* **Reset to original** - Return to the production variation with a single tap
* **Hide / show campaigns** - Temporarily disable a campaign for the current session
* **View allocations** - Check traffic distribution across variations
* **Check targeting** - Verify targeting rules and conditions

See [Using ABTasty QA Assistant](https://docs.abtasty.com/server-side/integrations/using-abtasty-qa-assistant) for more information.

### 🔄 Live Flag Updates

Real-time flag value changes when you force variations through the QA Assistant:

```swift
// Setup listener for automatic UI updates
Flagship.sharedInstance.sharedVisitor?.onFlagUpdate = { changedKeys in
    print("🔔 Flags updated: \(changedKeys)")
    // Refresh your UI with new flag values
}
```

### 📊 Comprehensive Views

* **Campaigns Tab** - Browse every campaign, its status, and the currently allocated variation
* **Variations Tab** - See all flags and their values for each variation of a campaign
* **Allocation Tab** - View traffic distribution percentages across variation groups
* **Targeting Tab** - Check targeting rules and audience criteria
* **Events Tab** - Monitor hits (events, screens, transactions) sent to Flagship in real-time

### 🔍 Context Management

* **Context Tab** - See all context key-value pairs for the current visitor

---

## Best Practices

### 1. Initialize in Debug Mode Only

Only enable the QA Assistant in debug/staging builds. Wrapping the code in `#if DEBUG` removes it entirely from Release/App Store builds:

```swift
private func initQAAssistant() {
    #if DEBUG
    qaAssistant = ABTastyQAAssistant("YOUR_ENVIRONMENT_ID", "YOUR_API_KEY")
    #endif
}
```

### 2. Always Dispose Properly

Clean up resources when the presenting view controller is deallocated:

```swift
deinit {
    Flagship.sharedInstance.sharedVisitor?.onFlagUpdate = nil  // Remove listener

    qaAssistant?.hideOverlayButton()
    qaAssistant?.dispose()
}
```

---

## Troubleshooting

### Issue: Overlay button not showing

**Solution:** Make sure you call `showOverlayButton(in:)` with a `UIViewController` whose `view` is already attached to a window (e.g. from `viewDidAppear`, not before the view hierarchy is set up):

```swift
qaAssistant?.showOverlayButton(in: self)
```

### Issue: Flags not updating after forcing a variation

**Solution:** Ensure the flag update listener is registered *before* the first `fetchFlags` call:

```swift
// Setup listener BEFORE fetching flags
Flagship.sharedInstance.sharedVisitor?.onFlagUpdate = { changedKeys in
    updateFlagValues()
}

Flagship.sharedInstance.sharedVisitor?.fetchFlags { }
```

### Issue: "Allocation has been bypassed" message

This is expected when you force a campaign. The allocation is bypassed because you've manually selected a variation instead of letting the normal traffic allocation decide. This is working as intended.

### Issue: QA Assistant compiled into a production build

Make sure to wrap QA Assistant code in `#if DEBUG` checks:

```swift
#if DEBUG
// QA Assistant code
#endif
```

Consider using a separate CocoaPods target, or a build configuration that excludes the `ABTastyQAssistant` pod from your Release build, to fully exclude the package from production builds.

---

## Additional Resources

* [Flagship iOS SDK Documentation](https://docs.abtasty.com/server-side/sdks/ios/ios)
* [GitHub Repository](https://github.com/flagship-io/abtasty-qa-assistant-ios)
* [Report Issues](https://github.com/flagship-io/abtasty-qa-assistant-ios/issues)

---

## Example Application

A complete demo application is included in the `Example/` directory. To run it:

```bash
cd Example
pod install
open ABTastyQAssistant.xcworkspace
```

Then build and run the `ABTastyQAssistant-Example` scheme from Xcode.

The example demonstrates:

* Complete Flagship SDK integration
* QA Assistant setup and teardown
* Live flag updates
* Multiple flag types (string, number, VIP-targeted flags)
* Context updates and hit tracking (screens, events, transactions)
