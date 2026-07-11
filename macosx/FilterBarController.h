// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import <AppKit/AppKit.h>

typedef NSString* FilterType NS_TYPED_EXTENSIBLE_ENUM;

extern FilterType const FilterTypeNone;
extern FilterType const FilterTypeActive;
extern FilterType const FilterTypeDownload;
extern FilterType const FilterTypeSeed;
extern FilterType const FilterTypePause;
extern FilterType const FilterTypeError;

typedef NSString* FilterSearchType NS_TYPED_EXTENSIBLE_ENUM;

extern FilterSearchType const FilterSearchTypeName;
extern FilterSearchType const FilterSearchTypeTracker;

extern NSInteger const kGroupFilterAllTag;

@class FilterButton;

@interface FilterBarController : NSTitlebarAccessoryViewController<NSMenuItemValidation>
#if TR_MACOS_OBJC_FRAGILE_RUNTIME
{
  @private
    IBOutlet FilterButton* _fNoFilterButton;
    IBOutlet FilterButton* _fActiveFilterButton;
    IBOutlet FilterButton* _fDownloadFilterButton;
    IBOutlet FilterButton* _fSeedFilterButton;
    IBOutlet FilterButton* _fPauseFilterButton;
    IBOutlet FilterButton* _fErrorFilterButton;
    IBOutlet NSSearchField* _fSearchField;
    IBOutlet NSLayoutConstraint* _fSearchFieldMinWidthConstraint;
    IBOutlet NSPopUpButton* _fGroupsButton;
}
#endif

@property(nonatomic, readonly) NSArray* searchStrings;

- (instancetype)init;

- (IBAction)setFilter:(id)sender;
- (void)switchFilter:(BOOL)right;
- (IBAction)setSearchText:(id)sender;
- (IBAction)setSearchType:(id)sender;
- (IBAction)setGroupFilter:(id)sender;
- (void)reset;
- (void)focusSearchField;
- (BOOL)isFocused;

- (void)setCountAll:(NSUInteger)all
             active:(NSUInteger)active
        downloading:(NSUInteger)downloading
            seeding:(NSUInteger)seeding
             paused:(NSUInteger)paused
              error:(NSUInteger)error;

@end
