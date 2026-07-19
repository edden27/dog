---
title: "QLPreviewProvider"
description: "A class that you subclass to provide a data-based Quick Look preview extension."
source: "https://developer.apple.com/documentation/quicklookui/qlpreviewprovider"
saved: 2026-07-17T01:32:33
sections:
  - L26: Overview
  - L38: Relationships
  - L54: See Also
---

Technologies > Quick Look UI

# QLPreviewProvider

Class

macOS 12.0+

A class that you subclass to provide a data-based Quick Look preview extension.

```swift
class QLPreviewProvider
```

## Overview

When you subclass [QLPreviewProvider](/documentation/quicklookui/qlpreviewprovider), conform your subclass [QLPreviewingController](/documentation/quicklookui/qlpreviewingcontroller).

To provide a data-based Quick Look extension, make the following modifications to your Info.plist file:

- Set the Boolean key `QLIsDataBasedPreview` to `true`.
- Add the type identifiers for your extension’s supported content types to the `QLSupportedContentTypes` array.
- Change the value of `NSExtensionPrincipalClass` to the name of your subclass. For example, if you named your subclass `PreviewProvider`, set the value to `$(PRODUCT_MODULE_NAME).PreviewProvider`.

After updating the extension’s `Info.plist` file, implement the [providePreview(for:completionHandler:)](/documentation/quicklookui/qlpreviewingcontroller/providepreview(for:completionhandler:)) method to return a [QLPreviewReply](/documentation/quicklookui/qlpreviewreply) for the provided [QLFilePreviewRequest](/documentation/quicklookui/qlfilepreviewrequest).

## Relationships

### Inherits From

- [NSObject](/documentation/objectivec/nsobject-swift.class)

### Conforms To

- [CVarArg](/documentation/swift/cvararg)
- [CustomDebugStringConvertible](/documentation/swift/customdebugstringconvertible)
- [CustomStringConvertible](/documentation/swift/customstringconvertible)
- [Equatable](/documentation/swift/equatable)
- [Hashable](/documentation/swift/hashable)
- [NSExtensionRequestHandling](/documentation/foundation/nsextensionrequesthandling)
- [NSObjectProtocol](/documentation/objectivec/nsobjectprotocol)

## See Also

### Data-based Preview Extensions

- [`class QLFilePreviewRequest`](/documentation/quicklookui/qlfilepreviewrequest)
- [`class QLPreviewReply`](/documentation/quicklookui/qlpreviewreply)
- [`class QLPreviewReplyAttachment`](/documentation/quicklookui/qlpreviewreplyattachment)