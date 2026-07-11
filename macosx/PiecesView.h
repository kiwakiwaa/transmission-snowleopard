// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

#include <stdint.h>

@class Torrent;

#if TR_MACOS_OBJC_FRAGILE_RUNTIME
enum
{
    TRPiecesViewMaxAcross = 18,
    TRPiecesViewMaxCells = TRPiecesViewMaxAcross * TRPiecesViewMaxAcross,
};

typedef struct PieceInfo
{
    int8_t available[TRPiecesViewMaxCells];
    float complete[TRPiecesViewMaxCells];
} PieceInfo;
#endif

@interface PiecesView : NSImageView
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
    Torrent* _torrent;
    PieceInfo fPieceInfo;
    NSString* fRenderedHashString;
}
#endif

@property(nonatomic) Torrent* torrent;

- (void)clearView;
- (void)updateView;

@end
