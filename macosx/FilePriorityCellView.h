// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

@class FileListNode;

@interface FilePriorityCellView : NSTableCellView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    __weak FileListNode* _node;
    BOOL _hovered;
    __weak NSSegmentedControl* _segmentedControl;
    __weak NSView* _iconsContainerView;
#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
    NSStackView* _stackView;
    NSImageView* _lowPriorityView;
    NSImageView* _mediumPriorityView;
    NSImageView* _highPriorityView;
#endif
    NSTrackingArea* _trackingArea;
}
#endif

@property(nonatomic, weak) FileListNode* node;
@property(nonatomic) BOOL hovered;

@end
