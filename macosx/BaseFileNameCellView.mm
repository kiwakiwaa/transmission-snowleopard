// This file Copyright © Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#include <libtransmission/macos-version.h>

#import "BaseFileNameCellView.h"
#import "FileListNode.h"
#import "LegacyConstraints.h"
#import "NSStringAdditions.h"
#import "Torrent.h"

static CGFloat const kPaddingHorizontal = 2.0;
static CGFloat const kImageFolderSize = 16.0;
static CGFloat const kImageIconSize = 32.0;
static CGFloat const kPaddingBetweenImageAndTitle = 4.0;
static CGFloat const kPaddingAboveTitleFile = 2.0;
static CGFloat const kPaddingBelowStatusFile = 2.0;
static CGFloat const kPaddingBetweenNameAndFolderStatus = 4.0;

@interface BaseFileNameCellView ()
@property(nonatomic, weak) NSImageView* iconView;
@property(nonatomic, weak) NSTextField* nameField;
@property(nonatomic, weak) NSTextField* statusField;
@end

@implementation BaseFileNameCellView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]))
    {
        NSImageView* iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.imageScaling = NSImageScaleProportionallyDown;
        [self addSubview:iconView];
        _iconView = iconView;

        NSTextField* nameField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        nameField.translatesAutoresizingMaskIntoConstraints = NO;
        nameField.editable = NO;
        nameField.selectable = NO;
        nameField.bordered = NO;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        nameField.backgroundColor = [NSColor clearColor];
#else
        nameField.backgroundColor = NSColor.clearColor;
#endif
        nameField.font = [NSFont messageFontOfSize:12.0];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        [[nameField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
#else
        nameField.lineBreakMode = NSLineBreakByTruncatingMiddle;
#endif
        [self addSubview:nameField];
        _nameField = nameField;
        self.textField = nameField;

        NSTextField* statusField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        statusField.translatesAutoresizingMaskIntoConstraints = NO;
        statusField.editable = NO;
        statusField.selectable = NO;
        statusField.bordered = NO;
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        statusField.backgroundColor = [NSColor clearColor];
#else
        statusField.backgroundColor = NSColor.clearColor;
#endif
        statusField.font = [NSFont messageFontOfSize:9.0];
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        statusField.textColor = [NSColor disabledControlTextColor];
        [[statusField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
#else
        statusField.textColor = NSColor.secondaryLabelColor;
        statusField.lineBreakMode = NSLineBreakByTruncatingTail;
#endif
        [self addSubview:statusField];
        _statusField = statusField;

        [self setupConstraints];
    }
    return self;
}

- (void)setupConstraints
{
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

    self.iconView.image = node.icon;

    self.nameField.stringValue = node.name;

    Torrent* torrent = node.torrent;
    CGFloat const progress = [torrent fileProgress:node];
    NSString* percentString = [NSString percentString:progress longDecimals:YES];

    NSString* status = [NSString stringWithFormat:NSLocalizedString(@"%@ of %@", "Inspector -> Files tab -> file status string"),
                                                  percentString,
                                                  [NSString stringForFileSize:node.size]];
    self.statusField.stringValue = status;

    [self updateColors];
    [self updateTooltip];
}

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
#if TR_MACOS_DEPLOYMENT_BEFORE_10_10
        self.statusField.textColor = NSColor.disabledControlTextColor;
#else
        self.statusField.textColor = NSColor.secondaryLabelColor;
#endif
    }
}

@end

@implementation FileNameCellView

- (void)setupConstraints
{
    NSImageView* iconView = self.iconView;
    NSTextField* nameField = self.nameField;
    NSTextField* statusField = self.statusField;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_11
    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kPaddingHorizontal],
        [iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:kImageIconSize],
        [iconView.heightAnchor constraintEqualToConstant:kImageIconSize],

        [nameField.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:kPaddingBetweenImageAndTitle],
        [nameField.topAnchor constraintEqualToAnchor:self.topAnchor constant:kPaddingAboveTitleFile],
        [nameField.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],

        [statusField.leadingAnchor constraintEqualToAnchor:nameField.leadingAnchor],
        [statusField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [statusField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-kPaddingBelowStatusFile],
    ]];
#else
    TRActivateConstraints(self,
        @[
            TRMakeLayoutConstraint(iconView, NSLayoutAttributeLeading, NSLayoutRelationEqual, self, NSLayoutAttributeLeading, kPaddingHorizontal),
            TRMakeLayoutConstraint(iconView, NSLayoutAttributeCenterY, NSLayoutRelationEqual, self, NSLayoutAttributeCenterY, 0.0),
            TRMakeLayoutConstraint(iconView, NSLayoutAttributeWidth, NSLayoutRelationEqual, nil, NSLayoutAttributeNotAnAttribute, kImageIconSize),
            TRMakeLayoutConstraint(iconView, NSLayoutAttributeHeight, NSLayoutRelationEqual, nil, NSLayoutAttributeNotAnAttribute, kImageIconSize),

            TRMakeLayoutConstraint(nameField, NSLayoutAttributeLeading, NSLayoutRelationEqual, iconView, NSLayoutAttributeTrailing, kPaddingBetweenImageAndTitle),
            TRMakeLayoutConstraint(nameField, NSLayoutAttributeTop, NSLayoutRelationEqual, self, NSLayoutAttributeTop, kPaddingAboveTitleFile),
            TRMakeLayoutConstraint(nameField, NSLayoutAttributeTrailing, NSLayoutRelationLessThanOrEqual, self, NSLayoutAttributeTrailing, 0.0),

            TRMakeLayoutConstraint(statusField, NSLayoutAttributeLeading, NSLayoutRelationEqual, nameField, NSLayoutAttributeLeading, 0.0),
            TRMakeLayoutConstraint(statusField, NSLayoutAttributeTrailing, NSLayoutRelationEqual, self, NSLayoutAttributeTrailing, 0.0),
            TRMakeLayoutConstraint(statusField, NSLayoutAttributeBottom, NSLayoutRelationEqual, self, NSLayoutAttributeBottom, -kPaddingBelowStatusFile),
        ]);
#endif
}

@end

@implementation FolderNameCellView

- (void)setupConstraints
{
    NSImageView* iconView = self.iconView;
    NSTextField* nameField = self.nameField;
    NSTextField* statusField = self.statusField;

#if !TR_MACOS_DEPLOYMENT_BEFORE_10_11
    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kPaddingHorizontal],
        [iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:kImageFolderSize],
        [iconView.heightAnchor constraintEqualToConstant:kImageFolderSize],

        [nameField.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:kPaddingBetweenImageAndTitle],
        [nameField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [nameField.trailingAnchor constraintLessThanOrEqualToAnchor:statusField.leadingAnchor constant:-kPaddingBetweenNameAndFolderStatus],

        [statusField.leadingAnchor constraintEqualToAnchor:nameField.trailingAnchor constant:kPaddingBetweenNameAndFolderStatus],
        [statusField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [statusField.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],
    ]];
#else
    TRActivateConstraints(self,
        @[
            TRMakeLayoutConstraint(iconView, NSLayoutAttributeLeading, NSLayoutRelationEqual, self, NSLayoutAttributeLeading, kPaddingHorizontal),
            TRMakeLayoutConstraint(iconView, NSLayoutAttributeCenterY, NSLayoutRelationEqual, self, NSLayoutAttributeCenterY, 0.0),
            TRMakeLayoutConstraint(iconView, NSLayoutAttributeWidth, NSLayoutRelationEqual, nil, NSLayoutAttributeNotAnAttribute, kImageFolderSize),
            TRMakeLayoutConstraint(iconView, NSLayoutAttributeHeight, NSLayoutRelationEqual, nil, NSLayoutAttributeNotAnAttribute, kImageFolderSize),

            TRMakeLayoutConstraint(nameField, NSLayoutAttributeLeading, NSLayoutRelationEqual, iconView, NSLayoutAttributeTrailing, kPaddingBetweenImageAndTitle),
            TRMakeLayoutConstraint(nameField, NSLayoutAttributeCenterY, NSLayoutRelationEqual, self, NSLayoutAttributeCenterY, 0.0),
            TRMakeLayoutConstraint(
                nameField,
                NSLayoutAttributeTrailing,
                NSLayoutRelationLessThanOrEqual,
                statusField,
                NSLayoutAttributeLeading,
                -kPaddingBetweenNameAndFolderStatus),

            TRMakeLayoutConstraint(statusField, NSLayoutAttributeLeading, NSLayoutRelationEqual, nameField, NSLayoutAttributeTrailing, kPaddingBetweenNameAndFolderStatus),
            TRMakeLayoutConstraint(statusField, NSLayoutAttributeCenterY, NSLayoutRelationEqual, self, NSLayoutAttributeCenterY, 0.0),
            TRMakeLayoutConstraint(statusField, NSLayoutAttributeTrailing, NSLayoutRelationLessThanOrEqual, self, NSLayoutAttributeTrailing, 0.0),
        ]);
#endif
}

@end
