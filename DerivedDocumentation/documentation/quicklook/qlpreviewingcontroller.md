---
title: "QLPreviewingController"
description: "For view based previews, the view controller that implements the QLPreviewingController protocol must at least implement one of the two following methods: -[QLPreviewingController preparePreviewOfSearchableItemWithIdentifier:queryString:completionHandler:], to generate previews for Spotlight searchable items. -[QLPreviewingController preparePreviewOfFileAtURL:completionHandler:], to generate previews for file URLs."
source: "https://developer.apple.com/documentation/quicklook/qlpreviewingcontroller"
saved: 2026-07-17T01:32:33
sections:
  - L27: Overview
  - L33: Topics
  - L41: Relationships
  - L47: See Also
---

Technologies > Quick Look

# QLPreviewingController

Protocol

iOS 4.0+ | iPadOS 4.0+ | Mac Catalyst 13.0+ | visionOS 1.0+

For view based previews, the view controller that implements the QLPreviewingController protocol must at least implement one of the two following methods: -[QLPreviewingController preparePreviewOfSearchableItemWithIdentifier:queryString:completionHandler:], to generate previews for Spotlight searchable items. -[QLPreviewingController preparePreviewOfFileAtURL:completionHandler:], to generate previews for file URLs.

```swift
protocol QLPreviewingController : NSObjectProtocol
```

## Overview

The main preview should be presented by the view controller implementing QLPreviewingController. Avoid presenting additional view controllers over your QLPreviewingController. For Catalyst compatibility, avoid using gesture recognizers that take interactions over large portions of the view to avoid collisions with standard macOS preview behaviors. Avoid holding the file open during the duration of the preview. If access to the file is necessary for interaction, it is best to keep the file open only for the duration of the interaction.

For data-based previews, subclass QLPreviewProvider which conforms to this protocol.

## Topics

### Instance Methods

- [`func preparePreviewOfFile(at: URL, completionHandler: ((any Error)?) -> Void)`](/documentation/quicklook/qlpreviewingcontroller/preparepreviewoffile(at:completionhandler:))
- [`func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler: ((any Error)?) -> Void)`](/documentation/quicklook/qlpreviewingcontroller/preparepreviewofsearchableitem(identifier:querystring:completionhandler:))
- [`func providePreview(for: QLFilePreviewRequest, completionHandler: (QLPreviewReply?, (any Error)?) -> Void)`](/documentation/quicklook/qlpreviewingcontroller/providepreview(for:completionhandler:))

## Relationships

### Inherits From

- [NSObjectProtocol](/documentation/objectivec/nsobjectprotocol)

## See Also

### QuickLookUI symbols

- [`class QLFilePreviewRequest`](/documentation/quicklook/qlfilepreviewrequest)
- [`class QLPreviewProvider`](/documentation/quicklook/qlpreviewprovider)
- [`class QLPreviewReply`](/documentation/quicklook/qlpreviewreply)
- [`class QLPreviewReplyAttachment`](/documentation/quicklook/qlpreviewreplyattachment)
- [`protocol QLPreviewItem`](/documentation/quicklook/qlpreviewitem)