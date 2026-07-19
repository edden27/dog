---
title: "QLPreviewReply"
description: "The class you create when providing a data-based Quick Look preview extension."
source: "https://developer.apple.com/documentation/quicklookui/qlpreviewreply"
saved: 2026-07-17T01:32:33
sections:
  - L27: Overview
  - L31: Topics
  - L55: Relationships
  - L70: See Also
---

Technologies > Quick Look UI

# QLPreviewReply

Class

macOS 12.0+

The class you create when providing a data-based Quick Look preview extension.

```swift
class QLPreviewReply
```

## Overview

Create an instance of [QLPreviewReply](/documentation/quicklookui/qlpreviewreply) from the method [providePreview(for:completionHandler:)](/documentation/quicklookui/qlpreviewingcontroller/providepreview(for:completionhandler:)) in your subclass of [QLPreviewProvider](/documentation/quicklookui/qlpreviewprovider). Create an instance to return data; for example, an image, PDF, or HTML; that the system displays as the preview for the content that the system indicates with [QLFilePreviewRequest](/documentation/quicklookui/qlfilepreviewrequest).

## Topics

### Creating a preview reply

- [`init(fileURL: URL)`](/documentation/quicklookui/qlpreviewreply/init(fileurl:))

### Create a PDF preview reply

- [`convenience init(forPDFWithPageSize: CGSize, createDocumentUsing: (QLPreviewReply) throws -> PDFDocument)`](/documentation/quicklookui/qlpreviewreply/init(forpdfwithpagesize:createdocumentusing:))

### Generating a preview reply

- [`convenience init(dataOfContentType: UTType, contentSize: CGSize, createDataUsing: (QLPreviewReply) throws -> Data)`](/documentation/quicklookui/qlpreviewreply/init(dataofcontenttype:contentsize:createdatausing:))

### Drawing a preview reply

- [`convenience init(contextSize: CGSize, isBitmap: Bool, drawUsing: (CGContext, QLPreviewReply) throws -> Void)`](/documentation/quicklookui/qlpreviewreply/init(contextsize:isbitmap:drawusing:))

### Inspecting a preview reply

- [`var title: String`](/documentation/quicklookui/qlpreviewreply/title)
- [`var attachments: [String : QLPreviewReplyAttachment]`](/documentation/quicklookui/qlpreviewreply/attachments)
- [`var stringEncoding: String.Encoding`](/documentation/quicklookui/qlpreviewreply/stringencoding-8ahm8)

## Relationships

### Inherits From

- [NSObject](/documentation/objectivec/nsobject-swift.class)

### Conforms To

- [CVarArg](/documentation/swift/cvararg)
- [CustomDebugStringConvertible](/documentation/swift/customdebugstringconvertible)
- [CustomStringConvertible](/documentation/swift/customstringconvertible)
- [Equatable](/documentation/swift/equatable)
- [Hashable](/documentation/swift/hashable)
- [NSObjectProtocol](/documentation/objectivec/nsobjectprotocol)

## See Also

### Data-based Preview Extensions

- [`class QLPreviewProvider`](/documentation/quicklookui/qlpreviewprovider)
- [`class QLFilePreviewRequest`](/documentation/quicklookui/qlfilepreviewrequest)
- [`class QLPreviewReplyAttachment`](/documentation/quicklookui/qlpreviewreplyattachment)