// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "FileCheckCellView.h"

#include <libtransmission/macos-version.h>

#import "FileListNode.h"
#import "FileOutlineItemDisplay.h"
#import "LegacyConstraints.h"
#import "Torrent.h"

@interface FileCheckCellView ()
@property(nonatomic, weak) NSButton* checkButton;
@end

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
@interface FileCheckCellView ()
- (void)layoutSubviewsForLegacyFrame;
@end
#endif

@implementation FileCheckCellView

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
@synthesize node = _node;
@synthesize checkButton = _checkButton;
#endif

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]))
    {
        // Create checkbox button
        NSButton* checkButton = [[NSButton alloc] initWithFrame:NSZeroRect];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
        checkButton.translatesAutoresizingMaskIntoConstraints = YES;
        checkButton.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin;
#else
        checkButton.translatesAutoresizingMaskIntoConstraints = NO;
#endif
#if TR_MACOS_SDK_BEFORE_10_12
        [checkButton setButtonType:NSSwitchButton];
#else
        [checkButton setButtonType:NSButtonTypeSwitch];
#endif
        checkButton.title = @"";
        checkButton.allowsMixedState = YES;
        checkButton.target = self;
        checkButton.action = @selector(checkButtonClicked:);
        [self addSubview:checkButton];
        _checkButton = checkButton;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_9
        // Setup constraints
        TRActivateConstraints(self,
            @[
                TRMakeLayoutConstraint(checkButton, NSLayoutAttributeCenterX, NSLayoutRelationEqual, self, NSLayoutAttributeCenterX, 0.0),
                TRMakeLayoutConstraint(checkButton, NSLayoutAttributeCenterY, NSLayoutRelationEqual, self, NSLayoutAttributeCenterY, 0.0),
            ]);
#endif
    }
    return self;
}

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self layoutSubviewsForLegacyFrame];
}

- (void)layoutSubviewsForLegacyFrame
{
    CGFloat const size = 18.0;
    self.checkButton.frame = NSMakeRect(floor(NSMidX(self.bounds) - size * 0.5), floor(NSMidY(self.bounds) - size * 0.5), size, size);
}
#endif

- (void)setNode:(FileListNode*)node
{
    _node = node;
    [self updateDisplay];
}

- (void)updateDisplay
{
    if (!self.node)
    {
        return;
    }

    FileListNode* node = self.node;
    Torrent* torrent = node.torrent;

    // Update checkbox state
    self.checkButton.state = [torrent checkForFiles:node.indexes];
    self.checkButton.enabled = [torrent canChangeDownloadCheckForFiles:node.indexes];

    // Update tooltip
    [self updateTooltip];
}

- (void)updateTooltip
{
    if (!self.node)
    {
        return;
    }

    self.checkButton.toolTip = TRFileOutlineCheckTooltip(self.checkButton.state);
}

- (void)checkButtonClicked:(NSButton*)sender
{
    if (!self.node)
    {
        return;
    }

    FileListNode* node = self.node;
    Torrent* torrent = node.torrent;

    NSIndexSet* indexSet;
#if TR_MACOS_SDK_BEFORE_10_12
    if ([NSEvent modifierFlags] & NSAlternateKeyMask)
#else
    if (NSEvent.modifierFlags & NSEventModifierFlagOption)
#endif
    {
        indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, torrent.fileCount)];
    }
    else
    {
        indexSet = node.indexes;
    }

    [torrent setFileCheckState:sender.state != NSControlStateValueOff ? NSControlStateValueOn : NSControlStateValueOff
                    forIndexes:indexSet];

    // Notify that we need to refresh
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateUI" object:nil];
}

@end
