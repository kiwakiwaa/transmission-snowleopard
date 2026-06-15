// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#include <libtransmission/transmission.h>

#import "FileNameCellView.h"
#import "FileListNode.h"
#import "Torrent.h"
#import "NSStringAdditions.h"

static CGFloat const kPaddingHorizontal = 2.0;
static CGFloat const kImageFolderSize = 16.0;
static CGFloat const kImageIconSize = 32.0;
static CGFloat const kPaddingBetweenImageAndTitle = 4.0;
static CGFloat const kPaddingAboveTitleFile = 2.0;
static CGFloat const kPaddingBelowStatusFile = 2.0;
static CGFloat const kPaddingBetweenNameAndFolderStatus = 4.0;

@interface FileNameCellView ()
@property(nonatomic, TR_OBJC_WEAK) NSImageView* iconView;
@property(nonatomic, TR_OBJC_WEAK) NSTextField* nameField;
@property(nonatomic, TR_OBJC_WEAK) NSTextField* statusField;
@property(nonatomic, strong) NSArray* dynamicConstraints;
@end

@implementation FileNameCellView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]))
    {
        // Create icon view
        NSImageView* iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        iconView.translatesAutoresizingMaskIntoConstraints = YES;
#else
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
#endif
        iconView.imageScaling = NSImageScaleProportionallyDown;
        [self addSubview:iconView];
        _iconView = iconView;

        // Create name field
        NSTextField* nameField = [[NSTextField alloc] initWithFrame:NSZeroRect];
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        nameField.translatesAutoresizingMaskIntoConstraints = YES;
#else
        nameField.translatesAutoresizingMaskIntoConstraints = NO;
#endif
        nameField.editable = NO;
        nameField.selectable = NO;
        nameField.bordered = NO;
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        nameField.backgroundColor = [NSColor clearColor];
#else
        nameField.backgroundColor = NSColor.clearColor;
#endif
        nameField.font = [NSFont messageFontOfSize:12.0];
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        [[nameField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
#else
        nameField.lineBreakMode = NSLineBreakByTruncatingMiddle;
#endif
        [self addSubview:nameField];
        _nameField = nameField;
        self.textField = nameField;

        // Create status field
        NSTextField* statusField = [[NSTextField alloc] initWithFrame:NSZeroRect];
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        statusField.translatesAutoresizingMaskIntoConstraints = YES;
#else
        statusField.translatesAutoresizingMaskIntoConstraints = NO;
#endif
        statusField.editable = NO;
        statusField.selectable = NO;
        statusField.bordered = NO;
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        statusField.backgroundColor = [NSColor clearColor];
#else
        statusField.backgroundColor = NSColor.clearColor;
#endif
        statusField.font = [NSFont messageFontOfSize:9.0];
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        statusField.textColor = [NSColor disabledControlTextColor];
        [[statusField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
#else
        statusField.textColor = NSColor.secondaryLabelColor;
        statusField.lineBreakMode = NSLineBreakByTruncatingTail;
#endif
        [self addSubview:statusField];
        _statusField = statusField;

        // Setup constraints
        [self setupConstraints];
    }
    return self;
}

- (void)setupConstraints
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
    NSImageView* iconView = self.iconView;
    NSTextField* nameField = self.nameField;

    // Fixed constraints that don't change
    [NSLayoutConstraint activateConstraints:@[
        // Icon view constraints
        [iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kPaddingHorizontal],
        [iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:kImageIconSize],
        [iconView.heightAnchor constraintEqualToConstant:kImageIconSize],

        // Name field leading constraint
        [nameField.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:kPaddingBetweenImageAndTitle],
    ]];

    self.dynamicConstraints = @[];
#endif
}

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

    // Update icon
    self.iconView.image = node.icon;

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
    // Update icon size constraints based on folder/file
    CGFloat const imageSize = node.isFolder ? kImageFolderSize : kImageIconSize;
    for (NSLayoutConstraint* constraint in self.iconView.constraints)
    {
        if (constraint.firstAttribute == NSLayoutAttributeWidth || constraint.firstAttribute == NSLayoutAttributeHeight)
        {
            constraint.constant = imageSize;
        }
    }
#endif

    // Update name
    self.nameField.stringValue = node.name;

    // Update status
    Torrent* torrent = node.torrent;
    CGFloat const progress = [torrent fileProgress:node];
    NSString* percentString = [NSString percentString:progress longDecimals:YES];

    NSString* status = [NSString stringWithFormat:NSLocalizedString(@"%@ of %@", "Inspector -> Files tab -> file status string"),
                                                  percentString,
                                                  [NSString stringForFileSize:node.size]];
    self.statusField.stringValue = status;

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
    [self setNeedsDisplay:YES];
    [self layout];
#else
    // Update layout constraints based on folder vs file
    [NSLayoutConstraint deactivateConstraints:self.dynamicConstraints];

    NSTextField* nameField = self.nameField;
    NSTextField* statusField = self.statusField;

    if (node.isFolder)
    {
        // For folders, status appears next to name, both centered
        self.statusField.hidden = NO;
        self.dynamicConstraints = @[
            [nameField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [nameField.trailingAnchor constraintLessThanOrEqualToAnchor:statusField.leadingAnchor
                                                               constant:-kPaddingBetweenNameAndFolderStatus],

            [statusField.leadingAnchor constraintEqualToAnchor:nameField.trailingAnchor constant:kPaddingBetweenNameAndFolderStatus],
            [statusField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [statusField.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],
        ];
    }
    else
    {
        // For files, status appears below name
        self.statusField.hidden = NO;
        self.dynamicConstraints = @[
            [nameField.topAnchor constraintEqualToAnchor:self.topAnchor constant:kPaddingAboveTitleFile],
            [nameField.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],

            [statusField.leadingAnchor constraintEqualToAnchor:nameField.leadingAnchor],
            [statusField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [statusField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-kPaddingBelowStatusFile],
        ];
    }

    [NSLayoutConstraint activateConstraints:self.dynamicConstraints];
#endif

    // Update colors based on background style and check state
    [self updateColors];

    // Update tooltip
    [self updateTooltip];
}

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
- (void)layout
{
    [super layout];

    if (!self.node)
    {
        return;
    }

    NSRect bounds = self.bounds;
    CGFloat imageSize = self.node.isFolder ? kImageFolderSize : kImageIconSize;
    CGFloat iconSlot = kImageIconSize;
    CGFloat iconX = kPaddingHorizontal + (iconSlot - imageSize) / 2.0;
    CGFloat iconY = NSMidY(bounds) - imageSize / 2.0;
    self.iconView.frame = NSMakeRect(iconX, iconY, imageSize, imageSize);

    CGFloat textX = kPaddingHorizontal + iconSlot + kPaddingBetweenImageAndTitle;
    CGFloat textWidth = MAX(0.0, NSWidth(bounds) - textX);

    if (self.node.isFolder)
    {
        [self.statusField sizeToFit];
        CGFloat statusWidth = MIN(NSWidth(self.statusField.frame), textWidth / 2.0);
        CGFloat nameWidth = MAX(0.0, textWidth - statusWidth - kPaddingBetweenNameAndFolderStatus);
        CGFloat fieldHeight = 17.0;
        CGFloat fieldY = NSMidY(bounds) - fieldHeight / 2.0;

        self.nameField.frame = NSMakeRect(textX, fieldY, nameWidth, fieldHeight);
        self.statusField.frame = NSMakeRect(NSMaxX(self.nameField.frame) + kPaddingBetweenNameAndFolderStatus, fieldY, statusWidth, fieldHeight);
    }
    else
    {
        CGFloat nameHeight = 17.0;
        CGFloat statusHeight = 13.0;
        self.nameField.frame = NSMakeRect(textX, NSHeight(bounds) - nameHeight - kPaddingAboveTitleFile, textWidth, nameHeight);
        self.statusField.frame = NSMakeRect(textX, kPaddingBelowStatusFile, textWidth, statusHeight);
    }
}
#endif

- (void)updateTooltip
{
    if (!self.node)
    {
        return;
    }

    FileListNode* node = self.node;
    Torrent* torrent = node.torrent;

    NSString* path = [torrent fileLocation:node];
    if (!path)
    {
        path = [node.path stringByAppendingPathComponent:node.name];
    }
    self.toolTip = path;
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    [self updateColors];
}

- (void)updateColors
{
    if (!self.node)
    {
        return;
    }

    FileListNode* node = self.node;
    Torrent* torrent = node.torrent;

    if (self.backgroundStyle == NSBackgroundStyleEmphasized)
    {
        self.nameField.textColor = NSColor.whiteColor;
        self.statusField.textColor = NSColor.whiteColor;
    }
    else if ([torrent checkForFiles:node.indexes] == NSControlStateValueOff)
    {
        self.nameField.textColor = NSColor.disabledControlTextColor;
        self.statusField.textColor = NSColor.disabledControlTextColor;
    }
    else
    {
        self.nameField.textColor = NSColor.controlTextColor;
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1090
        self.statusField.textColor = [NSColor disabledControlTextColor];
#else
        self.statusField.textColor = NSColor.secondaryLabelColor;
#endif
    }
}

@end
