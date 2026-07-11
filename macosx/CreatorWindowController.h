// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <future>
#include <memory>

#include <libtransmission/error.h>
#include <libtransmission/transmission.h>

class tr_metainfo_builder;

@interface CreatorWindowController : NSWindowController
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet NSImageView* _fIconView;
    IBOutlet NSTextField* _fNameField;
    IBOutlet NSTextField* _fStatusField;
    IBOutlet NSTextField* _fPiecesField;
    IBOutlet NSTextField* _fLocationField;
    IBOutlet NSTableView* _fTrackerTable;
    IBOutlet NSSegmentedControl* _fTrackerAddRemoveControl;
    IBOutlet NSTextView* _fCommentView;
    IBOutlet NSButton* _fPrivateCheck;
    IBOutlet NSButton* _fOpenCheck;
    IBOutlet NSTextField* _fSource;
    IBOutlet NSStepper* _fPieceSizeStepper;
    IBOutlet NSView* _fProgressView;
    IBOutlet NSProgressIndicator* _fProgressIndicator;
    std::shared_ptr<tr_metainfo_builder> _fBuilder;
    NSURL* _fPath;
    std::shared_future<tr_error> _fFuture;
    NSURL* _fLocation;
    NSMutableArray* _fTrackers;
    NSTimer* _fTimer;
    BOOL _fStarted;
    BOOL _fOpenWhenCreated;
    NSUserDefaults* _fDefaults;
}
#endif

+ (CreatorWindowController*)createTorrentFile:(tr_session*)handle;
+ (CreatorWindowController*)createTorrentFile:(tr_session*)handle forFile:(NSURL*)file;

- (instancetype)initWithHandle:(tr_session*)handle path:(NSURL*)path;

- (IBAction)setLocation:(id)sender;
- (IBAction)create:(id)sender;
- (IBAction)cancelCreateWindow:(id)sender;
- (IBAction)cancelCreateProgress:(id)sender;
- (IBAction)incrementOrDecrementPieceSize:(id)sender;
- (IBAction)addRemoveTracker:(id)sender;

- (void)copy:(id)sender;
- (void)paste:(id)sender;

@end
