// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <libtransmission/macos-version.h>

#import "TorrentTableView.h"

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
#import "LegacyStackView.h"
#endif

@interface TorrentCell : NSTableCellView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSButton* _fActionButton;
    IBOutlet NSButton* _fControlButton;
    IBOutlet NSButton* _fRevealButton;
    IBOutlet NSImageView* _fIconView;
    IBOutlet NSImageView* _fGroupIndicatorView;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
    IBOutlet LegacyStackView* _fStackView;
#else
    IBOutlet NSStackView* _fStackView;
#endif
    IBOutlet NSTextField* _fTorrentTitleField;
    IBOutlet NSImageView* _fTorrentPriorityView;
    IBOutlet NSLayoutConstraint* _fTorrentPriorityViewWidthConstraint;
    IBOutlet NSTextField* _fTorrentProgressField;
    IBOutlet NSTextField* _fTorrentStatusField;
    IBOutlet NSView* _fTorrentProgressBarView;
    TorrentTableView* __weak _fTorrentTableView;
}
#endif

@property(nonatomic) IBOutlet NSButton* fActionButton;
@property(nonatomic) IBOutlet NSButton* fControlButton;
@property(nonatomic) IBOutlet NSButton* fRevealButton;

@property(nonatomic) IBOutlet NSImageView* fIconView;
@property(nonatomic) IBOutlet NSImageView* fGroupIndicatorView;

#if TR_MACOS_DEPLOYMENT_BEFORE_10_9
@property(nonatomic) IBOutlet LegacyStackView* fStackView;
#else
@property(nonatomic) IBOutlet NSStackView* fStackView;
#endif
@property(nonatomic) IBOutlet NSTextField* fTorrentTitleField;
@property(nonatomic) IBOutlet NSImageView* fTorrentPriorityView;
@property(nonatomic) IBOutlet NSLayoutConstraint* fTorrentPriorityViewWidthConstraint;

@property(nonatomic) IBOutlet NSTextField* fTorrentProgressField;
@property(nonatomic) IBOutlet NSTextField* fTorrentStatusField;

@property(nonatomic) IBOutlet NSView* fTorrentProgressBarView;

@property(nonatomic, weak) TorrentTableView* fTorrentTableView;

@end
