// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>
#import "TorrentTableView.h"

@interface GroupCell : NSTableCellView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSImageView* _fGroupIndicatorView;
    IBOutlet NSTextField* _fGroupTitleField;
    IBOutlet NSImageView* _fGroupDownloadView;
    IBOutlet NSImageView* _fGroupUploadAndRatioView;
    IBOutlet NSTextField* _fGroupDownloadField;
    IBOutlet NSTextField* _fGroupUploadAndRatioField;
}
#endif

@property(nonatomic) IBOutlet NSImageView* fGroupIndicatorView;
@property(nonatomic) IBOutlet NSTextField* fGroupTitleField;

@property(nonatomic) IBOutlet NSImageView* fGroupDownloadView;
@property(nonatomic) IBOutlet NSImageView* fGroupUploadAndRatioView;
@property(nonatomic) IBOutlet NSTextField* fGroupDownloadField;
@property(nonatomic) IBOutlet NSTextField* fGroupUploadAndRatioField;

@end
