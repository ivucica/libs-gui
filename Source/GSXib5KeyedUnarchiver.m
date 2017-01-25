/** <title>GSXib5KeyedUnarchiver.m</title>
 
 <abstract>The XIB 5 keyed unarchiver</abstract>
 
 Copyright (C) 1996-2017 Free Software Foundation, Inc.
 
 Author:  Marcian Lytwyn <gnustep@advcsi.com>
 Date: 12/28/16
 
 This file is part of the GNUstep GUI Library.
 
 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2 of the License, or (at your option) any later version.
 
 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 Lesser General Public License for more details.
 
 You should have received a copy of the GNU Lesser General Public
 License along with this library; see the file COPYING.LIB.
 If not, see <http://www.gnu.org/licenses/> or write to the
 Free Software Foundation, 51 Franklin Street, Fifth Floor,
 Boston, MA 02110-1301, USA.
 */

#import "GSXib5KeyedUnarchiver.h"
#import "GNUstepGUI/GSNibLoading.h"
#import "GNUstepGUI/GSXibLoading.h"
#import "GNUstepGUI/GSXibElement.h"

#import "AppKit/NSApplication.h"
#import "AppKit/NSBox.h"
#import "AppKit/NSButtonCell.h"
#import "AppKit/NSCell.h"
#import "AppKit/NSClipView.h"
#import "AppKit/NSImage.h"
#import "AppKit/NSMatrix.h"
#import "AppKit/NSMenu.h"
#import "AppKit/NSMenuItem.h"
#import "AppKit/NSNib.h"
#import "AppKit/NSPopUpButton.h"
#import "AppKit/NSPopUpButtonCell.h"
#import "AppKit/NSScroller.h"
#import "AppKit/NSScrollView.h"
#import "AppKit/NSSliderCell.h"
#import "AppKit/NSSplitView.h"
#import "AppKit/NSTableColumn.h"
#import "AppKit/NSTableView.h"
#import "AppKit/NSTabView.h"
#import "AppKit/NSView.h"


//#define DEBUG_XIB5

@interface NSString (GSXib5KeyedUnarchiver)

#pragma mark - NSString method(s)...
- (NSString*) stringByDeletingPrefix: (NSString*) prefix;
@end

@implementation NSString (GSXib5KeyedUnarchiver)

- (NSString*) stringByDeletingPrefix: (NSString*) prefix
{
  if ([self length] > [prefix length])
  {
    if ([[self substringWithRange:NSMakeRange(0, [prefix length])] isEqualToString:prefix])
    {
      NSString *key = [self substringWithRange:NSMakeRange([prefix length], [self length]-[prefix length])];
      return key;
    }
  }
  
  return nil;
}

@end

@interface NSCustomObject5 : NSCustomObject
{
  NSString *_userLabel;
}

- (NSString*) userLabel;
@end

@implementation NSCustomObject5

static NSString *ApplicationClass = nil;

- (id) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  
  if (self)
  {
    _userLabel = [coder decodeObjectForKey:@"userLabel"];
    
    if (_className)
    {
      // If we've not set the general application class yet...
      if (([NSClassFromString(_className) isKindOfClass: [NSApplication class]]) &&
          (ApplicationClass == nil))
      {
        @synchronized([self class])
        {
          ASSIGN(ApplicationClass, _className);
        }
      }
    }
    
    // Override thie one type...
    if (_userLabel)
    {
      if ([@"Application" isEqualToString:_userLabel])
      {
        if (ApplicationClass == nil)
          ASSIGN(_className, @"NSApplication");
        else
          ASSIGN(_className, ApplicationClass);
      }
    }
  }
  
  return self;
}

- (NSString *)userLabel
{
  return _userLabel;
}

@end


@interface NSWindowTemplate5 : NSWindowTemplate
{
  BOOL _visibleAtLaunch;
}
@end

@implementation NSWindowTemplate5

- (id) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self)
    {
      _visibleAtLaunch = YES;
      
      if ([coder containsValueForKey: @"visibleAtLaunch"])
        _visibleAtLaunch = [coder decodeBoolForKey: @"visibleAtLaunch"];
    }
  
  return self;
}

- (id) nibInstantiate
{
  // Instantiate the real object...
  id object = [super nibInstantiate];
  
  // >= XIB 5 - startup visible windows...
  if (_visibleAtLaunch)
    {
      // bring visible windows to front...
      [(NSWindow *)object orderFront: self];
    }
  
  return object;
}

@end

@interface IBOutletConnection5 : IBOutletConnection
@end

@implementation IBOutletConnection5

- (instancetype)initWithCoder:(NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self)
    {
      if ([coder allowsKeyedCoding])
        {
          if ([coder containsValueForKey: @"property"])
            {
              ASSIGN(label, [coder decodeObjectForKey: @"property"]);
            }
        }
      else
        {
          [NSException raise: NSInvalidArgumentException
                      format: @"Can't decode %@ with %@.",NSStringFromClass([self class]),
           NSStringFromClass([coder class])];
        }
    }
  return self;
}

@end

@interface IBUserDefinedRuntimeAttribute5 : IBUserDefinedRuntimeAttribute
@end


@implementation IBUserDefinedRuntimeAttribute5

- (id) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  
  if (self)
    {
    if([coder allowsKeyedCoding])
      {
        [self setTypeIdentifier: [coder decodeObjectForKey: @"type"]];
        
        // Decode value properly...
        if ([@"boolean" isEqualToString: typeIdentifier])
          [self setValue: [NSNumber numberWithBool: ([@"YES" isEqualToString: value] ? YES : NO)]];
        else if ([@"image" isEqualToString: typeIdentifier])
          [self setValue: [NSImage imageNamed: value]];
#if 0
        else if ([@"number" isEqualToString: typeIdentifier])
          [self setValue [coder decodeObjectForKey: @"value"]];
        else if ([@"point" isEqualToString: typeIdentifier])
          [self setValue: [coder decodeObjectForKey: @"point"]];
        else if ([@"size" isEqualToString: typeIdentifier])
          [self setValue: [code decodeObjectForKey: @"size"]];
        else if ([@"rect" isEqualToString: typeIdentifier])
          [self setValue: [coder decodeObjectForKey: @"value"]];
        NSWarnMLog(@"type: %@ value: %@ (%@)", typeIdentifier, value, [value class]);
#endif
      }
    }
  
  return self;
}

@end


@implementation GSXib5KeyedUnarchiver

static NSDictionary *XmltagToObjectClassCrossReference = nil;
static NSArray      *XmltagsNotStacked = nil;
static NSArray      *XmltagsToSkip = nil;
static NSArray      *ClassNamePrefixes = nil;
static NSDictionary *XmlKeyMapTable = nil;
static NSDictionary *XmlTagToDecoderSelectorMap = nil;
static NSDictionary *XmlKeyToDecoderSelectorMap = nil;
static NSArray      *XmlKeysDefined  = nil;
static NSArray      *XmlReferenceAttributes  = nil;

+ (void) initialize
{
  if (self == [GSXib5KeyedUnarchiver class])
    {
      @synchronized(self)
      {
        // Only check one since we're going to load all once...
        if (XmltagToObjectClassCrossReference == nil)
          {
            XmltagToObjectClassCrossReference = @{ @"objects"                       : @"NSMutableArray",
                                                   @"items"                         : @"NSMutableArray",
                                                   @"tabViewItems"                  : @"NSMutableArray",
                                                   @"connections"                   : @"NSMutableArray",
                                                   @"subviews"                      : @"NSMutableArray",
                                                   @"tableColumns"                  : @"NSMutableArray",
                                                   @"cells"                         : @"NSMutableArray",
                                                   @"column"                        : @"NSMutableArray",
                                                   @"tabStops"                      : @"NSMutableArray",
                                                   @"userDefinedRuntimeAttributes"  : @"NSMutableArray",
                                                   @"customObject"                  : @"NSCustomObject5",
                                                   @"userDefinedRuntimeAttribute"   : @"IBUserDefinedRuntimeAttribute5",
                                                   //@"outlet"                        : @"IBOutletConnection5",
                                                   //@"action"                        : @"IBActionConnection",
                                                   @"window"                        : @"NSWindowTemplate5" };
            RETAIN(XmltagToObjectClassCrossReference);

            XmltagsNotStacked = @[ @"document" ];
            RETAIN(XmltagsNotStacked);

            XmltagsToSkip = @[ @"dependencies" ];
            RETAIN(XmltagsToSkip);

            ClassNamePrefixes = @[ @"NS", @"IB" ];
            RETAIN(ClassNamePrefixes);

            XmlReferenceAttributes = @[ @"headerView", @"initialItem" ];
            RETAIN(XmlReferenceAttributes);

            XmlKeyMapTable = @{ @"NSIsSeparator"          : @"isSeparatorItem",
                                //@"NSName"                 : @"systemMenu",
                                @"NSClassName"            : @"customClass",
                                @"NSCatalogName"          : @"catalog",
                                @"NSColorName"            : @"name",
                                @"NSSelectedIndex"        : @"selectedItem",
                                @"NSNoAutoenable"         : @"autoenablesItems",
                                @"NSPullDown"             : @"pullsDown",
                                @"NSProtoCell"            : @"prototype",
                                @"IBIsSystemFont"         : @"metaFont",
                                //@"NSHeaderClipView"       : @"headerView",
                                @"NSHScroller"            : @"horizontalScroller",
                                @"NSVScroller"            : @"verticalScroller",
                                @"NSKeyEquiv"             : @"keyEquivalent",
                                @"NSKeyEquivModMask"      : @"keyEquivalentModifierMask",
                                @"NSOffsets"              : @"contentViewMargins",
                                @"NSWindowStyleMask"      : @"styleMask",
                                @"NSWindowView"           : @"contentView",
                                @"NSWindowClass"          : @"customClass",
                                @"NSWindowTitle"          : @"title",
                                @"windowPositionMask"     : @"initialPositionMask",
                                @"NSWindowRect"           : @"contentRect",
                                @"NSInsertionColor"       : @"insertionPointColor",
                                @"NSIsVertical"           : @"vertical",
                                @"NSSelectedTabViewItem"  : @"initialItem" };
            RETAIN(XmlKeyMapTable);
            
            XmlKeysDefined = @[ @"NSWTFlags", @"NSvFlags", @"NSBGColor",
                                @"NSSize", //@"IBIsSystemFont",
                                @"NSHeaderClipView", @"NSHScroller", @"NSVScroller", @"NSsFlags",
                                @"NSTvFlags", @"NScvFlags",
                                @"NSSupport", @"NSName",
                                @"NSMenuItem",
                                @"NSDocView",
                                @"NSSliderType",
                                @"NSWhite", @"NSRGB", @"NSCYMK",
                                //@"NSContents", @"NSAlternateContents", @"NSAlternateImage",
                                @"NSCellFlags", @"NSCellFlags2",
                                @"NSButtonFlags", @"NSButtonFlags2",
                                @"NSSelectedIndex", @"NSAltersState",
                                @"NSNormalImage", @"NSAlternateImage",
                                @"NSBorderType", @"NSBoxType", @"NSTitlePosition",
                                @"NSTitleCell", @"NSOffsets",
                                @"NSMatrixFlags", @"NSNumCols", @"NSNumRows",
                                @"NSSharedData", @"NSFlags",
                                @"NSpiFlags" ];
            RETAIN(XmlKeysDefined);
            
            XmlTagToDecoderSelectorMap = @{ @"tableColumnResizingMask"  : @"decodeTableColumnResizingMaskForElement:",
                                            @"autoresizingMask"         : @"decodeAutoresizingMaskForElement:",
                                            @"windowStyleMask"          : @"decodeWindowStyleMaskForElement:",
                                            @"windowPositionMask"       : @"decodeWindowPositionMaskForElement:",
                                            //@"modifierMask"             : @"decodeModifierMaskForElement:",
                                            @"tableViewGridLines"       : @"decodeTableViewGridLinesForElement" };
            RETAIN(XmlTagToDecoderSelectorMap);
            
            XmlKeyToDecoderSelectorMap = @{ @"NSIntercellSpacingHeight"   : @"decodeIntercellSpacingHeightForElement:",
                                            @"NSIntercellSpacingWidth"    : @"decodeIntercellSpacingWidthForElement:",
                                            @"NSColumnAutoresizingStyle"  : @"decodeColumnAutoresizingStyleForElement:",
                                            @"NSName"                     : @"decodeNameForElement:",
                                            @"NSSliderType"               : @"decodeSliderCellTypeForElement:",
                                            @"NSTickMarkPosition"         : @"decodeSliderCellTickMarkPositionForElement:",
                                            @"NSCells"                    : @"decodeCellsForElement:",
                                            @"NSNumCols"                  : @"decodeNumberOfColumnsInMatrixForElement:",
                                            @"NSNumRows"                  : @"decodeNumberOfRowsInMatrixForElement:",
                                            @"pullsDown"                  : @"decodePullsDownForElement:",
                                            @"autoenablesItems"           : @"decodeAutoenablesItemsForElement:",
                                            @"NSAltersState"              : @"decodeAltersStateForElement:",
                                            @"NSMenuItem"                 : @"decodeMenuItemForElement:",
                                            @"selectedItem"               : @"decodeSelectedIndexForElement:",
                                            @"NSTitleCell"                : @"decodeTitleCellForElement:",
                                            @"NSBorderType"               : @"decodeBorderTypeForElement:",
                                            @"NSBoxType"                  : @"decodeBoxTypeForElement:",
                                            @"NSTitlePosition"            : @"decodeTitlePositionForElement:",
                                            //@"NSSearchButtonCell"         : @"decodeSearchButtonForElement:",
                                            //@"NSCancelButtonCell"         : @"decodeSearchButtonForElement:",
                                            @"keyEquivalentModifierMask"  : @"decodeModifierMaskForElement:",
                                            @"NSState"                    : @"decodeButtonStateForElement:",
                                            @"NSCell"                     : @"decodeCellForElement:",
                                            @"NSSize"                     : @"decodeFontSizeForElement:",
                                            //@"IBIsSystemFont"             : @"decodeFontTypeForElement:",
                                            @"NSpiFlags"                  : @"decodeProgressIndicatorFlagsForElement:",
                                            @"NSFlags"                    : @"decodeTextViewFlagsForElement:",
                                            @"NSSharedData"               : @"decodeSharedDataForElement:",
                                            @"NSMatrixFlags"              : @"decodeMatrixFlagsForElement:",
                                            @"NSsFlags"                   : @"decodeScrollClassFlagsForElement:",
                                            @"NSHeaderClipView"           : @"decodeScrollViewHeaderClipViewForElement:",
                                            @"NSBGColor"                  : @"decodeBackgroundColorForElement:",
                                            @"NScvFlags"                  : @"decodeClipViewFlagsForElement:",
                                            @"NSTvFlags"                  : @"decodeTViewFlagsForElement:",
                                            @"NSvFlags"                   : @"decodeViewFlagsForElement:",
                                            @"NSContents"                 : @"decodeCellContentsForElement:",
                                            @"NSAlternateContents"        : @"decodeCellAlternateContentsForElement:",
                                            @"NSCellFlags"                : @"decodeCellFlags1ForElement:",
                                            @"NSCellFlags2"               : @"decodeCellFlags2ForElement:",
                                            @"NSButtonFlags"              : @"decodeButtonFlags1ForElement:",
                                            @"NSButtonFlags2"             : @"decodeButtonFlags2ForElement:",
                                            @"NSNormalImage"              : @"decodeCellNormalImageForElement:",
                                            @"NSAlternateImage"           : @"decodeCellAlternateImageForElement:",
                                            @"NSWTFlags"                  : @"decodeWindowTemplateFlagsForElement:",
                                            @"NSDocView"                  : @"decodeClipViewDocumentViewForElement:",
                                            @"NSWhite"                    : @"decodeColorWhiteForElement:",
                                            @"NSRGB"                      : @"decodeColorRGBForElement:",
                                            @"NSColorSpace"               : @"decodeColorSpaceForElement:",
                                            @"NSCYMK"                     : @"decodeColorCYMKForElement:" };
            RETAIN(XmlKeyToDecoderSelectorMap);
        }
    }
  }
}

#pragma mark - Class level support method(s)...
+ (NSInteger) coderVersion
{
  return 5;
}

+ (NSString*) classNameForXibTag: (NSString*)xibTag
{
  NSString *className = [XmltagToObjectClassCrossReference objectForKey:xibTag];

  if (nil == className)
  {
    NSEnumerator *iter       = [ClassNamePrefixes objectEnumerator];
    NSString     *prefix     = nil;
    NSString     *baseString = [[xibTag substringToIndex:1] capitalizedString];
    baseString               = [baseString stringByAppendingString:[xibTag substringFromIndex:1]];
    
    // Try to generate a default name from tag...
    while ((prefix = [iter nextObject]))
    {
      NSString *theClassName = [NSString stringWithFormat:@"%@%@",prefix,baseString];
#if defined(DEBUG_XIB5)
      NSWarnMLog(@"%@ - trying: %@", xibTag, theClassName);
#endif
      if (NSClassFromString(theClassName))
      {
        className = theClassName;
        break;
      }
    }
  }
  
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"xibTag: %@ className: %@", xibTag, className);
#endif
  return className;
}

+ (Class) classForXibTag: (NSString*)xibTag
{
  return NSClassFromString([self classNameForXibTag:xibTag]);
}

#pragma mark - Instance level support method(s)...
- (void)setContext: (NSDictionary *)context
{
  ASSIGN(_context, context);
}

#pragma mark - Instance initialization method(s)...
- (id) initForReadingWithData: (NSData*)data
{
#if     GNUSTEP_BASE_HAVE_LIBXML
  NSXMLParser *theParser;
  NSData *theData = data;

  if (theData == nil)
  {
    return nil;
  }
  
  objects = [[NSMutableDictionary alloc] init];
  stack = [[NSMutableArray alloc] init];
  decoded = [[NSMutableDictionary alloc] init];
  
  theParser = [[NSXMLParser alloc] initWithData: theData];
  [theParser setDelegate: self];
  
  NS_DURING
  {
    // Parse the XML data
    [theParser parse];
  }
  NS_HANDLER
  {
    NSLog(@"Exception occurred while parsing Xib: %@",[localException reason]);
    DESTROY(self);
  }
  NS_ENDHANDLER
  
  DESTROY(theParser);
#endif
  
  return self;
}

- (void)dealloc
{
  RELEASE(_context);
  [super dealloc];
}

#pragma mark - XML decoding method(s)...
- (void) parser: (NSXMLParser*)parser
didStartElement: (NSString*)elementName
   namespaceURI: (NSString*)namespaceURI
  qualifiedName: (NSString*)qualifiedName
     attributes: (NSDictionary*)attributeDict
{
  NSMutableDictionary *attributes  = AUTORELEASE([attributeDict mutableCopy]);
  NSString            *className   = nil;
  NSString            *elementType = elementName;
  
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"elementName: %@ className: %@ namespaceURI: %@ qName: %@ attrs: %@", elementName, className, namespaceURI, qualifiedName, attributes);
#endif

  // Skip certain element names - for now...
  if ([XmltagsToSkip containsObject:elementName] == NO)
    {
      if (([@"window" isEqualToString: elementName] == NO) &&
          ([@"customView" isEqualToString: elementName] == NO) &&
          ([@"customObject" isEqualToString: elementName] == NO))
        className = [attributes objectForKey: @"customClass"];
      if (nil == className)
        className = [[self class] classNameForXibTag:elementName];
      
      if (nil != className)
        {
          if ([NSClassFromString(className) isSubclassOfClass:[NSArray class]])
            elementType = @"array";
          else if ([@"string" isEqualToString: elementName] == NO)
            elementType = @"object";
        }
      
      // Add the necessary attribute(s)...
      if (className)
        [attributes setObject: className forKey: @"class"];
      
      if ([attributes objectForKey:@"key"] == nil)
        {
          // Special cases to allow current initWithCoder methods to obtain objects...
          if ([@"objects" isEqualToString:elementName])
            {
              [attributes setObject:@"IBDocument.RootObjects" forKey:@"key"];
            }
          else if (([@"items" isEqualToString:elementName]) &&
                   ([[currentElement attributeForKey: @"class"] isEqualToString:@"NSMenu"]))
            {
              [attributes setObject: @"NSMenuItems" forKey: @"key"];
            }
          else
            {
              [attributes setObject: elementName forKey: @"key"];
            }
        }
      
      if (([attributes objectForKey: @"customClass"] == nil) ||
          ([NSClassFromString([attributes objectForKey: @"customClass"]) isSubclassOfClass: [NSApplication class]] == NO))
        if ([[attributes objectForKey: @"userLabel"] isEqualToString: @"Application"])
          [attributes setObject:@"NSApplication" forKey:@"customClass"];
      
      // FOR DEBUG...CAN BE REMOVED...
      [attributes setObject: elementName forKey: @"key5"];

      // Generate the XIB element object...
      GSXib5Element *element = [[GSXib5Element alloc] initWithType: elementType
                                                     andAttributes: attributes];
      NSString      *key     = [attributes objectForKey: @"key"];
      NSString      *ref     = [attributes objectForKey: @"id"];
      
      // FIXME: We should use proper memory management here
      AUTORELEASE(element);
      
      if ([@"array" isEqualToString: [currentElement type]])
        {
          // For arrays
          [currentElement addElement: element];
        }
      else
        {
          // For elements...
          [currentElement setElement: element forKey: key];
        }

      // Reference(s)...
      if (ref != nil)
        {
          [objects setObject: element forKey: ref];
        }
      
      if ([XmltagsNotStacked containsObject:elementName] == NO)
        {
          // Push element onto stack...
          [stack addObject: currentElement];
        }

      // Set as current element being processed...
      currentElement = element;
    }
}

- (void) parser: (NSXMLParser*)parser
  didEndElement: (NSString*)elementName
   namespaceURI: (NSString*)namespaceURI
  qualifiedName: (NSString*)qName
{
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"%s:elementName: %@ namespaceURI: %@ qName: %@", __PRETTY_FUNCTION__,
             elementName, namespaceURI, qName);
#endif
  
  // Skip certain element names - for now...
  if ([XmltagsToSkip containsObject:elementName] == NO)
    {
      if ([XmltagsNotStacked containsObject:elementName] == NO)
        {
          // Pop element...
          currentElement = [stack lastObject];
          [stack removeLastObject];
        }
    }
}

#pragma mark - Decoding method(s)...
// All this code should eventually move into their respective initWithCoder class
// methods - however note - there are a couple that may be duplicated...
- (id) decodeIntercellSpacingHeightForElement: (GSXib5Element*)element
{
  element = (GSXib5Element*)[element elementForKey: @"intercellSpacing"];
  return [element attributeForKey: @"height"];
}

- (id) decodeIntercellSpacingWidthForElement: (GSXib5Element*)element
{
  element = (GSXib5Element*)[element elementForKey: @"intercellSpacing"];
  return [element attributeForKey: @"width"];
}

- (id) decodeColumnAutoresizingStyleForElement: (GSXib5Element*)element
{
  NSString    *style = [element attributeForKey: @"columnAutoresizingStyle"];
  NSUInteger   value = NSTableViewUniformColumnAutoresizingStyle;
  
  if ([@"none" isEqualToString: style])
    value = NSTableViewNoColumnAutoresizing;
  else if ([@"firstColumnOnly" isEqualToString: style])
    value = NSTableViewFirstColumnOnlyAutoresizingStyle;
  else if ([@"lastColumnOnly" isEqualToString: style])
    value = NSTableViewLastColumnOnlyAutoresizingStyle;
  else if ([@"sequential" isEqualToString: style])
    value = NSTableViewSequentialColumnAutoresizingStyle;
  else if ([@"reverseSequential" isEqualToString: style])
    value = NSTableViewReverseSequentialColumnAutoresizingStyle;
  
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"value: %lu", value);
#endif
  
  return [NSNumber numberWithUnsignedInteger: value];
}

- (id) decodeWindowStyleMaskForElement: (GSXib5Element*)element
{
  NSDictionary *attributes = [element attributes];
  
  if (attributes)
  {
    NSUInteger mask = 0;
    
    if ([[attributes objectForKey: @"titled"] boolValue])
      mask |= NSTitledWindowMask;
    if ([[attributes objectForKey: @"closable"] boolValue])
      mask |= NSClosableWindowMask;
    if ([[attributes objectForKey: @"miniaturizable"] boolValue])
      mask |= NSMiniaturizableWindowMask;
    if ([[attributes objectForKey: @"resizable"] boolValue])
      mask |= NSResizableWindowMask;
    
#if defined(DEBUG_XIB5)
    NSWarnMLog(@"mask: %lu", mask);
#endif
    
    return [NSNumber numberWithUnsignedInteger: mask];
  }
  
  return nil;
}

- (id) decodeTableColumnResizingMaskForElement: (GSXib5Element*)element
{
  NSDictionary *attributes = [element attributes];
  
  if (attributes)
    {
      NSUInteger mask = NSTableColumnNoResizing;
      
      if ([[attributes objectForKey: @"resizeWithTable"] boolValue])
        mask |= NSTableColumnAutoresizingMask;
      if ([[attributes objectForKey: @"userResizable"] boolValue])
        mask |= NSTableColumnUserResizingMask;
      
#if defined(DEBUG_XIB5)
      NSWarnMLog(@"mask: %lu", mask);
#endif
      return [NSNumber numberWithUnsignedInteger: mask];
    }
  
  return nil;
}

- (id) decodeAutoresizingMaskForElement: (GSXib5Element*)element
{
  NSDictionary *attributes = [element attributes];

  if (attributes)
  {
    NSUInteger mask = NSViewNotSizable;
    
    if ([[attributes objectForKey: @"flexibleMinX"] boolValue])
      mask |= NSViewMinXMargin;
    if ([[attributes objectForKey: @"widthSizable"] boolValue])
      mask |= NSViewWidthSizable;
    if ([[attributes objectForKey: @"flexibleMaxX"] boolValue])
      mask |= NSViewMaxXMargin;
    if ([[attributes objectForKey: @"flexibleMinY"] boolValue])
      mask |= NSViewMinYMargin;
    if ([[attributes objectForKey: @"heightSizable"] boolValue])
      mask |= NSViewHeightSizable;
    if ([[attributes objectForKey: @"flexibleMaxY"] boolValue])
      mask |= NSViewMaxYMargin;
    
#if defined(DEBUG_XIB5)
    NSWarnMLog(@"attributes: %@ mask: %p", attributes, mask);
#endif
    return [NSNumber numberWithUnsignedInt: mask];
  }
  
  return nil;
}

- (id) decodeModifierMaskForElement: (GSXib5Element*)element
{
  id            object     = nil;
  NSDictionary *attributes = [[element elementForKey: @"keyEquivalentModifierMask"] attributes];

  if (attributes == nil)
    {
      // Seems that Apple decided to omit this attribute IF Control key alone
      // is applied.  If this key is present WITH NO setting then that NULL
      // value is used for the modifier mask...
      object = [NSNumber numberWithUnsignedInteger: NSCommandKeyMask];
    }
  else
    {
      // If the modifier mask element is present then no modifier attributes
      // equates to no key modifiers applied...
      NSUInteger mask = 0;
      
      if ([[attributes objectForKey:@"option"] boolValue])
      {
        mask |= NSAlternateKeyMask;
      }
      if ([[attributes objectForKey:@"alternate"] boolValue])
      {
        mask |= NSAlternateKeyMask;
      }
      if ([[attributes objectForKey:@"command"] boolValue])
      {
        mask |= NSCommandKeyMask;
      }
      if ([[attributes objectForKey:@"control"] boolValue])
      {
        mask |= NSControlKeyMask;
      }
      if ([[attributes objectForKey:@"shift"] boolValue])
      {
        mask |= NSShiftKeyMask;
      }
      if ([[attributes objectForKey:@"numeric"] boolValue])
      {
        mask |= NSNumericPadKeyMask;
      }
      if ([[attributes objectForKey:@"help"] boolValue])
      {
        mask |= NSHelpKeyMask;
      }
      if ([[attributes objectForKey:@"function"] boolValue])
      {
        mask |= NSFunctionKeyMask;
      }
      
#if defined(DEBUG_XIB5)
      NSWarnMLog(@"mask: %lu", mask);
#endif
      
      object = [NSNumber numberWithUnsignedInteger: mask];
    }
  
  return object;
}

- (id) decodeTableViewGridLinesForElement: (GSXib5Element*)element
{
  NSUInteger    mask       = NSTableViewGridNone;
  NSDictionary *attributes = [element attributes];

  if ([[attributes objectForKey: @"dashed"] boolValue])
    mask |= NSTableViewDashedHorizontalGridLineMask;
  else if ([[attributes objectForKey: @"horizontal"] boolValue])
    mask |= NSTableViewSolidHorizontalGridLineMask;

  if ([[attributes objectForKey: @"vertical"] boolValue])
    mask |= NSTableViewSolidHorizontalGridLineMask;

#if defined(DEBUG_XIB5)
  NSWarnMLog(@"mask: %p", mask);
#endif
  
  return [NSNumber numberWithUnsignedInteger: mask];
}

- (id) decodeClipViewDocumentViewForElement: (GSXib5Element*)element
{
  NSArray *subviews = [self decodeObjectForKey: @"subviews"];
  
  if ([subviews count] == 0)
    NSWarnMLog(@"no clipview document view for element: %@", element);
  else
    return [subviews objectAtIndex: 0];
  
  return nil;
}

- (id) decodeWindowTemplateFlagsForElement: (GSXib5Element*)element
{
  NSDictionary *attributes = [element attributes];
  
  if (attributes)
  {
    typedef union _GSWindowTemplateFlagsUnion
    {
      GSWindowTemplateFlags  flags;
      uint32_t               value;
    } GSWindowTemplateFlagsUnion;
    
    GSWindowTemplateFlagsUnion   mask = { { 0 } };
    GSXib5Element               *winPosMaskEleme  = (GSXib5Element*)[currentElement elementForKey: @"initialPositionMask"];
    NSUInteger                   winPosMask       = [[self decodeWindowPositionMaskForElement:winPosMaskEleme] unsignedIntegerValue];
    
    mask.flags.isHiddenOnDeactivate =  [[attributes objectForKey: @"hidesOnDeactivate"] boolValue];
    mask.flags.isNotReleasedOnClose = ![[attributes objectForKey: @"releasedWhenClosed"] boolValue];
    mask.flags.isDeferred           = ![[attributes objectForKey: @"visibleAtLaunch"] boolValue];
    mask.flags.isOneShot            =  ([attributes objectForKey: @"oneShot"] ?
                                        [[attributes objectForKey: @"oneShot"] boolValue] : YES);
    
    mask.flags.isVisible            =  [[attributes objectForKey: @"visibleAtLaunch"] boolValue];
    mask.flags.wantsToBeColor       =  0; //[[attributes objectForKey: @"visibleAtLaunch"] boolValue];
    mask.flags.dynamicDepthLimit    =  0; //[[attributes objectForKey: @"visibleAtLaunch"] boolValue];
    mask.flags.autoPositionMask     =  winPosMask;
    mask.flags.savePosition         =  [attributes objectForKey: @"frameAutosaveName"] != nil;
    mask.flags.style                =  0; //[[attributes objectForKey: @"visibleAtLaunch"] boolValue];
    
    return [NSNumber numberWithUnsignedInteger: mask.value];
  }
  
  return nil;
}

- (id) decodeWindowPositionMaskForElement: (GSXib5Element*)element
{
  NSDictionary *attributes = [element attributes];
  
  if (attributes)
  {
    NSUInteger mask = 0;
    
    return [NSNumber numberWithUnsignedInteger: mask];
  }
  
  return nil;
}

- (id)decodeMatrixFlagsForElement: (GSXib5Element*)element
{
  NSString           *mode                 = [element attributeForKey: @"mode"];
  NSString           *allowsEmptySelection = [element attributeForKey: @"allowsEmptySelection"];
  NSString           *autosizesCells       = [element attributeForKey: @"autosizesCells"];
  NSString           *drawsBackground      = [element attributeForKey: @"drawsBackground"];
  NSString           *selectionByRect      = [element attributeForKey: @"selectionByRect"];
  GSMatrixFlagsUnion  mask                 = { { 0 } };

  // mode...
  if ([@"list" isEqualToString: mode])
  {
    mask.flags.isList = 1;
  }
  else if ([@"highlight" isEqualToString: mode])
  {
    mask.flags.isHighlight = 1;
  }
  else if ([@"radio" isEqualToString: mode])
  {
    mask.flags.isRadio = 1;
  }
  else if ([@"track" isEqualToString: mode])
  {
    // What do we do with this type???
  }
  else if (mode)
  {
    NSWarnMLog(@"unknown matrix mode: %@", mode);
  }
  
  // allows empty selection...
  if (allowsEmptySelection == nil)
    mask.flags.allowsEmptySelection = 1;
  else
    mask.flags.allowsEmptySelection = [allowsEmptySelection boolValue];
  
  // autosizes cells...
  if (autosizesCells == nil)
    mask.flags.autosizesCells = 1;
  else
    mask.flags.autosizesCells = [autosizesCells boolValue];
  
  // draw background/cell background...
  if (drawsBackground)
    mask.flags.drawBackground = [drawsBackground boolValue];
  mask.flags.drawCellBackground = mask.flags.drawBackground;
  
  // selection by rectangle...
  if (selectionByRect == nil)
    mask.flags.selectionByRect = 1;
  else
    mask.flags.selectionByRect = [selectionByRect boolValue];
  
  return [NSNumber numberWithUnsignedInt: mask.value];
}

- (id)decodeNumberOfColumnsInMatrixForElement: (GSXib5Element*)element
{
  id    object  = nil;
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  
  if ([class isSubclassOfClass: [NSMatrix class]])
  {
    NSArray *cells = [self decodeObjectForKey: @"cells"];
    object         = [NSNumber numberWithUnsignedInteger: [cells count]];
  }
  
  return object;
}

- (id)decodeNumberOfRowsInMatrixForElement: (GSXib5Element*)element
{
  id    object  = nil;
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  
  if ([class isSubclassOfClass: [NSMatrix class]])
  {
    NSArray *cells  = [self decodeObjectForKey: @"cells"];
    NSArray *column = [cells objectAtIndex: 0];
    object          = [NSNumber numberWithUnsignedInteger: [column count]];
  }
  
  return object;
}

- (id)decodeFormCellsForElement: (GSXib5Element*)element
{
  id         object  = [NSMutableArray array];
  NSArray   *columns = [self decodeObjectForKey: @"cells"];
  NSInteger  numCols = [columns count];
  NSInteger  numRows = [[columns objectAtIndex: 0] count];
  NSInteger  row     = 0;
  NSInteger  col     = 0;
  
  // NSForm's cells now encoded as two dimensional array but we need
  // the cells in a single array by column/row...
  for (row = 0; row < numRows; ++row)
  {
    for (col = 0; col < numCols; ++col)
    {
      // Add the row/column object...
      [object addObject: [[columns objectAtIndex: col] objectAtIndex: row]];
    }
  }
  
  return object;
}

- (id)decodeNameForElement: (GSXib5Element*)element
{
  id    object = nil;
  Class class  = NSClassFromString([element attributeForKey: @"class"]);
  
  if ([class isSubclassOfClass: [NSMenu class]])
    {
      object = [element attributeForKey: @"systemMenu"];
      
      if (([@"main" isEqualToString: object]) &&
          ([@"MainMenu" isEqualToString: [element attributeForKey: @"userLabel"]]))
        object = @"_NSMainMenu";
    }
  else if ([element attributeForKey: @"name"])
    {
      object = [self decodeObjectForKey: @"name"];
    }
  else if ([class isSubclassOfClass: [NSFont class]] == NO)
    {
      NSWarnMLog(@"no name object for class: %@", [element attributeForKey: @"class"]);
    }
  
  return object;
}

- (id)decodeSliderCellTickMarkPositionForElement: (GSXib5Element*)element
{
  NSUInteger  value            = NSTickMarkBelow; // Default...
  NSString   *tickMarkPosition = [element attributeForKey: @"tickMarkPosition"];

  if ([@"below" isEqualToString: tickMarkPosition])
    value = NSTickMarkBelow;
  else if ([@"above" isEqualToString: tickMarkPosition])
    value = NSTickMarkAbove;
  else if ([@"leading" isEqualToString: tickMarkPosition])
    value = NSTickMarkLeft;
  else if ([@"trailing" isEqualToString: tickMarkPosition])
    value = NSTickMarkRight;
  else if (tickMarkPosition)
    NSWarnMLog(@"unknown slider cell tick mark position: %@", tickMarkPosition);
  
  return [NSNumber numberWithUnsignedInteger: value];
}

- (id)decodeSliderCellTypeForElement: (GSXib5Element*)element
{
  NSUInteger  value      = NSCircularSlider; // Default...
  NSString   *sliderType = [element attributeForKey: @"sliderType"];

  if ([@"linear" isEqualToString: sliderType])
    value = NSLinearSlider;
  else if ([@"circular" isEqualToString: sliderType])
    value = NSCircularSlider;
  else if (sliderType)
    NSWarnMLog(@"unknown slider cell type: %@", sliderType);
  
  return [NSNumber numberWithUnsignedInteger: value];
}

- (id)decodeCellsForElement: (GSXib5Element*)element
{
  id    object = nil;
  Class class  = NSClassFromString([element attributeForKey: @"class"]);
  
  if ([class isSubclassOfClass: [NSMatrix class]])
    object = [self decodeFormCellsForElement: element];
  else
    object = [self decodeObjectForKey: @"cells"];
  
  return object;
}

- (id)decodePullsDownForElement: (GSXib5Element*)element
{
  NSString  *pullsDown = [element attributeForKey: @"pullsDown"];
  BOOL       value     = YES; // Default if not present...
  
  if (pullsDown)
    value = [pullsDown boolValue];
  
  return [NSNumber numberWithBool: value];
}

- (id)decodeAutoenablesItemsForElement: (GSXib5Element*)element
{
  NSString  *autoenablesItems = [element attributeForKey: @"autoenablesItems"];
  BOOL       value            = YES; // Default if not present...
  
  if (autoenablesItems)
    value = [autoenablesItems boolValue];
  
  return [NSNumber numberWithBool: value];
}

- (id)decodeAltersStateForElement: (GSXib5Element*)element
{
  NSString  *altersState = [element attributeForKey: @"altersStateOfSelectedItem"];
  BOOL       value       = YES; // Default if not present...
  
  if (altersState)
    value = [altersState boolValue];

  return [NSNumber numberWithBool: value];
}

- (id)decodeMenuItemForElement: (GSXib5Element*)element
{
  NSString      *itemID   = [element attributeForKey: @"selectedItem"];
  GSXib5Element *itemElem = [objects objectForKey: itemID];
  id             object   = [self objectForXib: itemElem];
  
  return object;
}

- (id)decodeSelectedIndexForElement: (GSXib5Element*)element
{
  // We need to get the index into the menuitems for menu...
  NSMenu      *menu     = [self decodeObjectForKey: @"menu"];
  NSMenuItem  *item     = [self decodeMenuItemForElement: element];
  NSArray     *items    = [menu itemArray];
  NSUInteger   index    = [items indexOfObjectIdenticalTo: item];
  
  return [NSNumber numberWithUnsignedInteger: index];
}

- (id)decodeTitleCellForElement: (GSXib5Element*)element
{
  id        object  = nil;
  NSString *title   = [element attributeForKey: @"title"];
  
  if (title)
    {
      NSFont *font = [self decodeObjectForKey: @"titleFont"];
      
      // IF no font...
      if (font == nil) // default to system-11...
        font = [NSFont systemFontOfSize: 11];
      
      object = [[NSCell alloc] initTextCell: title];
      [object setAlignment: NSCenterTextAlignment];
      [object setBordered: NO];
      [object setEditable: NO];
      [object setFont: font];
    }
  
  return object;
}

- (id)decodeBorderTypeForElement: (GSXib5Element*)element
{
  NSString      *borderType = [element attributeForKey: @"borderType"];
  NSBorderType   value      = NSGrooveBorder; // Cocoa default...

  if (borderType)
    {
      if ([@"bezel" isEqualToString: borderType])
        value = NSBezelBorder;
      else if ([@"line" isEqualToString: borderType])
        value = NSLineBorder;
      else if ([@"none" isEqualToString: borderType])
        value = NSNoBorder;
      else
        NSWarnMLog(@"unknown border type: %@", borderType);
    }
  
  return [NSNumber numberWithUnsignedInteger: value];
}

- (id)decodeBoxTypeForElement: (GSXib5Element*)element
{
  NSString  *boxType = [element attributeForKey: @"boxType"];
  NSBoxType  value   = NSBoxPrimary; // Cocoa default...

  if (boxType)
  {
    if ([@"secondary" isEqualToString: boxType])
      value = NSBoxSecondary;
    else if ([@"oldStyle" isEqualToString: boxType])
      value = NSBoxOldStyle;
    else if ([@"custom" isEqualToString: boxType])
      value = NSBoxCustom;
    else if ([@"primary" isEqualToString: boxType])
      value = NSBoxPrimary;
    else
      NSWarnMLog(@"unknown box type: %@", boxType);
  }
  
  return [NSNumber numberWithUnsignedInteger: value];
}

- (id)decodeTitlePositionForElement: (GSXib5Element*)element
{
  NSString        *titlePosition = [element attributeForKey: @"titlePosition"];
  NSTitlePosition  value         = NSAtTop; // Default if not present...

  if (titlePosition)
    {
      if ([@"noTitle" isEqualToString: titlePosition])
        value = NSNoTitle;
      else if ([@"aboveTop" isEqualToString: titlePosition])
        value = NSAboveTop;
      else if ([@"belowTop" isEqualToString: titlePosition])
        value = NSBelowTop;
      else if ([@"aboveBottom" isEqualToString: titlePosition])
        value = NSAboveTop;
      else if ([@"atBottom" isEqualToString: titlePosition])
        value = NSAtBottom;
      else if ([@"belowBottom" isEqualToString: titlePosition])
        value = NSBelowBottom;
      else if ([@"atTop" isEqualToString: titlePosition])
        value = NSAtTop;
      else
        NSWarnMLog(@"unknown title position: %@", titlePosition);
    }
  
  return [NSNumber numberWithUnsignedInteger: value];
}

- (id)decodeFontSizeForElement: (GSXib5Element*)element
{
  NSDictionary *attributes = [element attributes];
  CGFloat       size       = [[attributes objectForKey: @"size"] floatValue];
  
  if (size == 0)
    {
      NSString *metaFont = [[attributes objectForKey: @"metaFont"] lowercaseString];
      
      // Default the value per Cocoa...
      size = 13;
      
      if ([metaFont containsString: @"system"])
        size = 13;
      else if ([metaFont containsString: @"small"])
        size = 11;
      else if ([metaFont containsString: @"mini"])
        size = 9;
      else if ([metaFont containsString: @"medium"])
        size = 13;
      else if ([metaFont containsString: @"menu"])
        size = 13;
      else if (metaFont)
        NSWarnMLog(@"unknown meta font value: %@", metaFont);
    }
  
  return [NSNumber numberWithFloat: size];
}

- (id)decodeFontTypeForElement: (GSXib5Element*)element
{
  static NSArray *MetaFontSystemNames = nil;
  if (MetaFontSystemNames == nil)
    {
      MetaFontSystemNames = @[ @"system", @"message" ];
      RETAIN(MetaFontSystemNames);
    }
  
  NSDictionary *attributes = [element attributes];
  NSString     *metaFont   = [[attributes objectForKey: @"metaFont"] lowercaseString];
  BOOL          isSystem   = [MetaFontSystemNames containsObject: metaFont];
  NSWarnMLog(@"isSystemFont %ld", (long)isSystem);
  return [NSNumber numberWithBool: isSystem];
}

- (id) decodeDividerStyleForElement: (GSXib5Element*)element
{
  NSString                *dividerStyle = [element attributeForKey: @"dividerStyle"];
  NSSplitViewDividerStyle  style        = NSSplitViewDividerStyleThick; // Default...
  
  if (dividerStyle)
    {
      if ([@"thin" isEqualToString: dividerStyle])
        style = NSSplitViewDividerStyleThin;
      else if ([@"paneSplitter" isEqualToString: dividerStyle])
        style = NSSplitViewDividerStylePaneSplitter;
#if 0 // DEFAULT - see above...
      else if ([@"thick" isEqualToString: dividerStyle])
        style = NSSplitViewDividerStyleThick;
#endif
      else
        NSWarnMLog(@"unknown divider style: %@", dividerStyle);
    }
  
  return [NSNumber numberWithInteger: style];
}

- (id) decodeProgressIndicatorFlagsForElement: (GSXib5Element*)element
{
  unsigned int  flags                 = 0;
#if 0
  NSString     *bezeled               = [element attributeForKey: @"bezeled"];
#endif
  NSString     *style                 = [element attributeForKey: @"style"];
  NSString     *controlSize           = [element attributeForKey: @"controlSize"];
  NSString     *indeterminate         = [element attributeForKey: @"indeterminate"];
  NSString     *displayedWhenStopped  = [element attributeForKey: @"displayedWhenStopped"];
  
  if ([indeterminate boolValue])
    flags |= 0x02;
  if ([@"small" isEqualToString: controlSize])
    flags |= 0x100;
  if ([@"spinning" isEqualToString: style])
    flags |= 0x1000;
  if ((displayedWhenStopped == nil) || ([displayedWhenStopped boolValue]))
    flags |= 0x2000;
  
  return [NSNumber numberWithInt: flags];
}

- (id) decodeTextViewFlagsForElement: (GSXib5Element*)element
{
  unsigned int  flags              = 0;
  NSString     *allowsUndo         = [element attributeForKey: @"allowsUndo"];
  NSString     *importsGraphics    = [element attributeForKey: @"importsGraphics"];
  NSString     *editable           = [element attributeForKey: @"editable"];
  NSString     *selectable         = [element attributeForKey: @"selectable"];
  NSString     *fieldEditor        = [element attributeForKey: @"fieldEditor"];
  NSString     *findStyle          = [element attributeForKey: @"findStyle"];
  NSString     *richText           = [element attributeForKey: @"richText"];
  NSString     *smartInsertDelete  = [element attributeForKey: @"smartInsertDelete"];
  NSString     *usesFontPanel      = [element attributeForKey: @"usesFontPanel"];
  NSString     *usesRuler          = [element attributeForKey: @"usesRuler"];
  NSString     *drawsBackground    = [element attributeForKey: @"drawsBackground"];
  NSString     *continuousSpellChecking = [element attributeForKey: @"continuousSpellChecking"];
  
#if 0
  // FIXME: if and when these are added to NSTextView...
  NSString     *allowsNonContiguousLayout           = [element attributeForKey: @"allowsNonContiguousLayout"];
  NSString     *spellingCorrection                  = [element attributeForKey: @"spellingCorrection"];
  NSString     *allowsImageEditing                  = [element attributeForKey: @"allowsImageEditing"];
  NSString     *allowsDocumentBackgroundColorChange = [element attributeForKey: @"allowsDocumentBackgroundColorChange"];
#endif
  
  if ((selectable == nil) || ([selectable boolValue]))
    flags |= 0x01;
  if ((editable == nil) || ([editable boolValue]))
    flags |= 0x02;
  if ((richText == nil) || ([richText boolValue]))
    flags |= 0x04;
  if ([importsGraphics boolValue])
    flags |= 0x08;
  if ([fieldEditor boolValue])
    flags |= 0x10;
  if ([usesFontPanel boolValue])
    flags |= 0x20;
  if ([usesRuler boolValue])
    flags |= 0x40;
  if ([continuousSpellChecking boolValue])
    flags |= 0x80;
  if ([usesRuler boolValue])
    flags |= 0x100;
  if ([smartInsertDelete boolValue])
    flags |= 0x200;
  if ([allowsUndo boolValue])
    flags |= 0x400;
  if ((drawsBackground == nil) || ([drawsBackground boolValue]))
    flags |= 0x800;
  if (findStyle) //([@"panel" isEqualToString: findStyle])
    flags |= 0x2000;
  
#if 0
  // FIXME: when added to NSTextView...
  if ([allowsImageEditing boolValue])
    flags |= 0x00;
  if ([allowsDocumentBackgroundColorChange boolValue])
    flags |= 0x00;
#endif
  
  return [NSNumber numberWithUnsignedInt: flags];
}

- (id) decodeSharedDataForElement: (GSXib5Element*)element
{
  id object = [[NSClassFromString(@"NSTextViewSharedData") alloc] initWithCoder: self];
  
  return AUTORELEASE(object);
}

- (id) decodeColorSpaceForElement: (GSXib5Element*)element
{
  // <color key="textColor" name="labelColor" catalog="System" colorSpace="catalog"/>
  // <color key="backgroundColor" white="1" alpha="1" colorSpace="calibratedWhite"/>
  // <color key="textColor" red="0.0" green="0.0" blue="1" alpha="1" colorSpace="calibratedRGB"/>
  // <color key="insertionPointColor" name="controlTextColor" catalog="System" colorSpace="catalog"/>
  // <color key="backgroundColor" cyan="0.61524784482758621" magenta="0.17766702586206898" yellow="0.48752693965517241" black="0.60991379310344829"
  //  alpha="1" colorSpace="custom" customColorSpace="genericCMYKColorSpace"/>
  NSDictionary *attributes = [element attributes];
  NSString     *colorSpace = [attributes objectForKey: @"colorSpace"];
  
  if (colorSpace)
    {
      NSUInteger value = 0;
      
      // Put most common first???
      if ([@"catalog" isEqualToString: colorSpace])
        {
          value = 6;
        }
      else if ([@"calibratedRGB" isEqualToString: colorSpace])
        {
          value = 1;
        }
      else if ([@"deviceRGB" isEqualToString: colorSpace])
        {
          value = 2;
        }
      else if ([@"calibratedWhite" isEqualToString: colorSpace])
        {
          value = 3;
        }
      else if ([@"deviceWhite" isEqualToString: colorSpace])
        {
          value = 4;
        }
      else if ([@"custom" isEqualToString: colorSpace])
      {
        NSString *customSpace = [attributes objectForKey: @"customColorSpace"];
        
        if ([@"genericCMYKColorSpace" isEqualToString: customSpace])
          {
            value = 5;
          }
        else if (customSpace)
          {
            NSWarnMLog(@"unknown custom color space: %@", customSpace);
          }
      }
      else
        {
          NSWarnMLog(@"unknown color space: %@", colorSpace);
        }

      return [NSNumber numberWithUnsignedInteger: value];
    }
  
  return nil;
}

- (id) decodeColorCYMKForElement: (GSXib5Element*)element
{
  // <color key="backgroundColor" cyan="0.61524784482758621" magenta="0.17766702586206898"
  //  yellow="0.48752693965517241" black="0.60991379310344829"
  //  alpha="1" colorSpace="custom" customColorSpace="genericCMYKColorSpace"/>
  double     cyan    = [self decodeDoubleForKey: @"cyan"];
  double     yellow  = [self decodeDoubleForKey: @"yellow"];
  double     magenta = [self decodeDoubleForKey: @"magenta"];
  double     black   = [self decodeDoubleForKey: @"black"];
  double     alpha   = [self decodeDoubleForKey: @"alpha"];
  NSString  *string  = [NSString stringWithFormat: @"%f %f %f %f %f", cyan, yellow, magenta, black, alpha];
  
  return [string dataUsingEncoding: NSUTF8StringEncoding];
}

- (id) decodeColorRGBForElement: (GSXib5Element*)element
{
  // <color key="textColor" red="0.0" green="0.0" blue="1" alpha="1" colorSpace="calibratedRGB"/>
  double     red    = [self decodeDoubleForKey: @"red"];
  double     green  = [self decodeDoubleForKey: @"green"];
  double     blue   = [self decodeDoubleForKey: @"blue"];
  double     alpha  = [self decodeDoubleForKey: @"alpha"];
  NSString  *string = [NSString stringWithFormat: @"%f %f %f %f", red, green, blue, alpha];
  
  return [string dataUsingEncoding: NSUTF8StringEncoding];
}

- (id) decodeColorWhiteForElement: (GSXib5Element*)element
{
  // <color key="backgroundColor" white="1" alpha="1" colorSpace="calibratedWhite"/>
  double     white  = [self decodeDoubleForKey: @"white"];
  double     alpha  = [self decodeDoubleForKey: @"alpha"];
  NSString  *string = [NSString stringWithFormat: @"%f %f", white, alpha];

  return [string dataUsingEncoding: NSUTF8StringEncoding];
}

- (id) decodeBackgroundColorForElement: (GSXib5Element*)element
{
  id    object  = nil;
  
  // Return value...
  object = [NSColor whiteColor];
  
  return object;
}

- (id) decodeScrollerFlagsForElement: (GSXib5Element*)element
{
  NSUInteger    mask                  = NSBezelBorder; // Default...
  NSDictionary *attributes            = [element attributes];
  NSString     *borderType            = [attributes objectForKey: @"borderType"];
  NSString     *hasHorizontalScroller = [attributes objectForKey: @"hasHorizontalScroller"];
  NSString     *hasVerticalScroller   = [attributes objectForKey: @"hasVerticalScroller"];
  NSString     *autohidesScrollers    = [attributes objectForKey: @"autohidesScrollers"];
  
  // borderType - do this one first to avoid or'ing...
  if (borderType == nil)
  {
    mask = NSBezelBorder;
  }
  else if ([@"none" isEqualToString: borderType])
  {
    mask = NSNoBorder;
  }
  else if ([@"line" isEqualToString: borderType])
  {
    mask = NSLineBorder;
  }
  else if ([@"groove" isEqualToString: borderType])
  {
    mask = NSGrooveBorder;
  }
  else if (borderType)
  {
    NSWarnMLog(@"unknown border type: %@", borderType);
  }

  if (hasHorizontalScroller)
    mask |= ([hasHorizontalScroller boolValue] ? (1 << 4) : 0);
  else // otherwise  the default is 'has'...
    mask |= (1 << 4);
  
  if (hasVerticalScroller)
    mask |= ([hasVerticalScroller boolValue] ? (1 << 5) : 0);
  else // otherwise the default is 'has'...
    mask |= (1 << 5);
  
  if (autohidesScrollers)
    mask |= ([autohidesScrollers boolValue] ? (1 << 9) : 0);
  else // otherwise the default is 'has'...
    mask |= (1 << 9);
  
  // Return value...
  return [NSNumber numberWithUnsignedInt: mask];
}

- (id) decodeScrollViewFlagsForElement: (GSXib5Element*)element
{
  NSUInteger    mask       = NSBezelBorder; // Default...
  NSDictionary *attributes = [element attributes];
  NSString     *borderType = [attributes objectForKey: @"borderType"];
  
  // borderType
  if (borderType == nil)
    {
      mask = NSBezelBorder;
    }
  else if ([@"none" isEqualToString: borderType])
    {
      mask = NSNoBorder;
    }
  else if ([@"line" isEqualToString: borderType])
    {
      mask = NSLineBorder;
    }
  else if ([@"groove" isEqualToString: borderType])
    {
      mask = NSGrooveBorder;
    }
  else if (borderType)
    {
      NSWarnMLog(@"unknown border type: %@", borderType);
    }
  
  // hasVerticalScroller
  if ([attributes objectForKey: @"hasVerticalScroller"] == nil)
    mask |= (1 << 4);
  else
    mask |= ([[attributes objectForKey: @"hasVerticalScroller"] boolValue] ? (1 << 4) : 0);
  
  // hasHorizontalScroller
  if ([attributes objectForKey: @"hasHorizontalScroller"] == nil)
    mask |= (1 << 5);
  else
    mask |= ([[attributes objectForKey: @"hasHorizontalScroller"] boolValue] ? (1 << 5) : 0);
  
  // autohidesScrollers
  if ([attributes objectForKey: @"autohidesScrollers"] == nil)
    mask |= (1 << 9);
  else
    mask |= ([[attributes objectForKey: @"autohidesScrollers"] boolValue] ? (1 << 9) : 0);
  
  // Return value...
  return [NSNumber numberWithUnsignedInt: mask];
}

- (id) decodeScrollViewHeaderClipViewForElement: (GSXib5Element*)element
{
  NSTableHeaderView *headerView = [self decodeObjectForKey: @"headerView"];
  id                 object     = [[NSClipView alloc] initWithFrame: [headerView frame]];
#if 0
  [object setAutoresizesSubviews: YES];
  [object setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin];
  [object setDocumentView: headerView];
#endif
  
  return object;
}

- (id) decodeScrollClassFlagsForElement: (GSXib5Element*)element
{
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  id    object  = nil;
  
  if ([class isSubclassOfClass: [NSScrollView class]])
    {
      object = [self decodeScrollViewFlagsForElement: element];
    }
  else if ([class isSubclassOfClass: [NSScroller class]])
    {
      object = [self decodeScrollerFlagsForElement: element];
    }
  else
    {
      NSWarnMLog(@"called for a class that is NOT a sub-class of NSScrollView/NSScroller - class: %@", NSStringFromClass(class));
    }
  
  return object;
}

- (id) decodeTableViewFlagsForElement: (GSXib5Element*)element
{
  typedef union _GSTableViewFlagsUnion
  {
    GSTableViewFlags flags;
    uint32_t         value;
  } GSTableViewFlagsUnion;
  
  GSTableViewFlagsUnion  mask          = { { 0 } };
  NSDictionary          *attributes    = [element attributes];
  NSDictionary          *gridStyleMask = [[element elementForKey: @"gridStyleMask"] attributes];
  
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"gridStyleMask: %@", gridStyleMask);
#endif
  
  mask.flags.columnOrdering     = [[attributes objectForKey: @"columnReordering"] boolValue];
  mask.flags.columnResizing     = [[attributes objectForKey: @"columnResizing"] boolValue];
  mask.flags.drawsGrid          = (gridStyleMask != nil);
  mask.flags.emptySelection     = YES; // check if present - see below...
  mask.flags.multipleSelection  = [[attributes objectForKey: @"multipleSelection"] boolValue];
  mask.flags.columnSelection    = [[attributes objectForKey: @"columnSelection"] boolValue];
  mask.flags.columnAutosave     = [[attributes objectForKey: @"autosaveColumns"] boolValue];
  
  if ([attributes objectForKey: @"emptySelection"])
    mask.flags.emptySelection = [[attributes objectForKey: @"emptySelection"] boolValue];
  
  // Unknown: typeSelect,
  
  return [NSNumber numberWithUnsignedInteger: mask.value];
}

- (id) decodeTabViewFlagsForElement: (GSXib5Element*)element
{
  GSTabViewTypeFlagsUnion  mask         = { { 0 } };
  NSDictionary            *attributes   = [element attributes];
  NSString                *type         = [attributes objectForKey: @"type"];
  NSString                *controlSize  = [attributes objectForKey: @"controlSize"];
  NSString                *controlTint  = [attributes objectForKey: @"controlTint"];
  
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"attributes: %@", attributes);
#endif
  
  // Set defaults...
  mask.flags.controlTint        = NSDefaultControlTint;
  mask.flags.controlSize        = NSControlSizeRegular;
  mask.flags.tabViewBorderType  = NSTopTabsBezelBorder;

  // Decode type...
  if ([@"leftTabsBezelBorder" isEqualToString: type])
    mask.flags.tabViewBorderType = NSLeftTabsBezelBorder;
  else if ([@"bottomTabsBezelBorder" isEqualToString: type])
    mask.flags.tabViewBorderType = NSBottomTabsBezelBorder;
  else if ([@"rightTabsBezelBorder" isEqualToString: type])
    mask.flags.tabViewBorderType = NSRightTabsBezelBorder;
  else if ([@"noTabsBezelBorder" isEqualToString: type])
    mask.flags.tabViewBorderType = NSNoTabsBezelBorder;
  else if ([@"noTabsLineBorder" isEqualToString: type])
    mask.flags.tabViewBorderType = NSNoTabsLineBorder;
  else if ([@"noTabsNoBorder" isEqualToString: type])
    mask.flags.tabViewBorderType = NSNoTabsNoBorder;
  else if (type)
    NSWarnMLog(@"unknown tabview type: %@", type);
  
  // Decode control size...
  if ([@"small" isEqualToString: controlSize])
    mask.flags.controlSize = NSControlSizeSmall;
  else if ([@"mini" isEqualToString: controlSize])
    mask.flags.controlSize = NSControlSizeMini;
  else if ([@"regular" isEqualToString: controlSize])
    mask.flags.controlSize = NSControlSizeRegular;
  else if (controlSize)
    NSWarnMLog(@"unknown control size: %@", controlSize);
  
  // Decode control tint...
  if ([@"blue" isEqualToString: controlTint])
    mask.flags.controlTint = NSBlueControlTint;
  else if ([@"graphite" isEqualToString: controlTint])
    mask.flags.controlTint = NSGraphiteControlTint;
  else if ([@"clear" isEqualToString: controlTint])
    mask.flags.controlTint = NSClearControlTint;
  else if (controlTint)
    NSWarnMLog(@"unknown control tint: %@", controlTint);

  return [NSNumber numberWithUnsignedInteger: mask.value];
}

- (id) decodeTViewFlagsForElement: (GSXib5Element*)element
{
  NSString *classname = [element attributeForKey: @"class"];
  id        object    = nil;
  
  // Invoke decoding based on class type...
  if ([NSClassFromString(classname) isSubclassOfClass: [NSTableView class]])
    object = [self decodeTableViewFlagsForElement: element];
  else
    object = [self decodeTabViewFlagsForElement: element];
  
  return object;
}

- (id) decodeClipViewFlagsForElement: (GSXib5Element*)element
{
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  id    object  = nil;
  
  if ([class isSubclassOfClass: [NSClipView class]] == NO)
    {
      NSWarnMLog(@"called for a class that is NOT a sub-class of NSClipView - class: %@", NSStringFromClass(class));
    }
  else
    {
      NSUInteger    mask = 0;
      NSDictionary *attributes = [element attributes];
      
      // copiesOnScroll - defaults to ON...
      if ([attributes objectForKey: @"copiesOnScroll"] == nil)
        mask |= (1 << 2);
      else
        mask |= ([[attributes objectForKey: @"copiesOnScroll"] boolValue] ? (1 << 2) : 0);
      
      // drawsBackground - defaults to ON...
      if ([attributes objectForKey: @"drawsBackground"] == nil)
        mask |= (1 << 4);
      else
        mask |= ([[attributes objectForKey: @"drawsBackground"] boolValue] ? (1 << 4) : 0);
      
      
      // Return value...
      object = [NSNumber numberWithUnsignedInt: mask];
    }
  
  return object;
}

- (id) decodeViewFlagsForElement: (GSXib5Element*)element
{
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  id    object  = nil;
  
  if ([class isSubclassOfClass: [NSView class]] == NO)
    {
      NSWarnMLog(@"called for a class that is NOT a sub-class of NSView - class: %@", NSStringFromClass(class));
    }
  else
    {
      typedef union _GSvFlagsUnion
      {
        GSvFlags flags;
        uint32_t value;
      } GSvFlagsUnion;

      GSvFlagsUnion  mask             = { { 0 } };
      NSDictionary  *attributes       = [element attributes];
      GSXib5Element *autoresizingMask = (GSXib5Element*)[element elementForKey: @"autoresizingMask"];
      
      mask.flags.autoresizingMask    = [[self decodeAutoresizingMaskForElement: autoresizingMask] unsignedIntegerValue];
      mask.flags.isHidden            = [[attributes objectForKey: @"hidden"] boolValue];
      mask.flags.autoresizesSubviews = YES;

      if ([attributes objectForKey: @"autoresizesSubviews"])
        mask.flags.autoresizesSubviews = [[attributes objectForKey: @"autoresizesSubviews"] boolValue];
      
      // Return value...
      object = [NSNumber numberWithUnsignedInt: mask.value];
    }
  
  return object;
}

- (id) decodeCellContentsForElement: (GSXib5Element*)element
{
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  id    object  = @"";
  
  if ([class isSubclassOfClass: [NSCell class]] == NO)
    {
      NSWarnMLog(@"called for a class that is NOT a sub-class of NSCell - class: %@", NSStringFromClass(class));
    }
  else
    {
      // Try the title attribute first as it's the common encoding...
      if ([element attributeForKey: @"title"])
        {
          object = [element attributeForKey: @"title"];
        }
      else if ([element elementForKey: @"title"])
        {
          // If the attribute does not exist check for a title element encoded
          // the old way via <string>TITLE</string>...
          object = [self decodeObjectForKey: @"title"];
        }
      else if ([element attributeForKey: @"image"])
        {
          object = [NSImage imageNamed: [element attributeForKey: @"image"]];
        }
      
#if 0
      // If a font is encoded then change the title to an attributed
      // string and set the font on it...
      if ([object isKindOfClass: [NSString class]] && [element elementForKey: @"font"])
        {
          NSFont       *font        = [self decodeObjectForKey: @"font"];
          NSDictionary *attributes  = [NSDictionary dictionaryWithObject: font forKey: NSFontAttributeName];
          object                    = [[NSAttributedString alloc] initWithString: object attributes: attributes];
        }
#endif
      
#if defined(DEBUG_XIB5)
      NSWarnMLog(@"object: %@", object);
#endif
    }
  
  return object;
}

- (id) decodeCellAlternateContentsForElement: (GSXib5Element*)element
{
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  id    object  = @"";
  
  if ([class isSubclassOfClass: [NSCell class]])
    {
      if ([element attributeForKey: @"alternateTitle"])
        {
          object = [element attributeForKey: @"alternateTitle"];
        }
      else if ([element attributeForKey: @"alternateImage"])
        {
          object = [NSImage imageNamed: [element attributeForKey: @"alternateImage"]];
        }
#if defined(DEBUG_XIB5)
      NSWarnMLog(@"object: %@", object);
#endif
    }
  
  return object;
}

- (unsigned int) decodeLineBreakModeForAttributes: (NSDictionary*)attributes
{
  unsigned int  value = 0;
  NSString     *lineBreakMode = [attributes objectForKey: @"lineBreakMode"];
  
  value = NSLineBreakByWordWrapping;
  if ([@"clipping" isEqualToString: lineBreakMode])
    value = NSLineBreakByClipping;
  else if ([@"charWrapping" isEqualToString: lineBreakMode])
    value = NSLineBreakByCharWrapping;
  else if ([@"wordWrapping" isEqualToString: lineBreakMode])
    value = NSLineBreakByWordWrapping;
  else if ([@"truncatingHead" isEqualToString: lineBreakMode])
    value = NSLineBreakByTruncatingHead;
  else if ([@"truncatingMiddle" isEqualToString: lineBreakMode])
    value = NSLineBreakByTruncatingMiddle;
  else if ([@"truncatingTail" isEqualToString: lineBreakMode])
    value = NSLineBreakByTruncatingTail;
#if 0
  else
    NSWarnMLog(@"unknown line break mode: %@", lineBreakMode);
#endif
  
  return value;
}

- (id) decodeCellFlags1ForElement: (GSXib5Element*)element
{
  NSNumber *value = nil;
  Class     class = NSClassFromString([element attributeForKey: @"class"]);
  
  if ([class isSubclassOfClass: [NSCell class]])
  {
    GSCellFlagsUnion   mask          = { { 0 } };
    NSDictionary      *attributes    = [element attributes];
#if 0
    NSString          *title         = [attributes objectForKey: @"title"];
    NSString          *lineBreakMode = [attributes objectForKey: @"lineBreakMode"];
    NSString          *bezelStyle    = [attributes objectForKey: @"bezelStyle"];
#endif
    NSString          *imageName     = [attributes objectForKey: @"image"];
    NSString          *focusRingType = [attributes objectForKey: @"focusRingType"];
    NSString          *borderStyle   = [attributes objectForKey: @"borderStyle"];
#if defined(DEBUG_XIB5)
    NSWarnMLog(@"attributes: %@", attributes);
#endif
    
    mask.flags.state                    = [[attributes objectForKey:@"state"] isEqualToString: @"on"];
    mask.flags.highlighted              = [[attributes objectForKey: @"highlighted"] boolValue];
    mask.flags.disabled                 = ([attributes objectForKey: @"enabled"] ?
                                           [[attributes objectForKey: @"enabled"] boolValue] == NO : NO);
    mask.flags.editable                 = [[attributes objectForKey: @"editable"] boolValue];
    mask.flags.vCentered                = [[attributes objectForKey: @"alignment"] isEqualToString: @"center"];
    mask.flags.hCentered                = [[attributes objectForKey: @"alignment"] isEqualToString: @"center"];
    mask.flags.bordered                 = [[borderStyle lowercaseString] containsString: @"border"];
    //mask.flags.bezeled                  = ((bezelStyle != nil) && ([@"regularSquare" isEqualToString: bezelStyle] == NO));
    mask.flags.bezeled                  = [[borderStyle lowercaseString] containsString: @"bezel"];
    mask.flags.selectable               = [[attributes objectForKey: @"selectable"] boolValue];
    mask.flags.scrollable               = [[attributes objectForKey: @"scrollable"] boolValue];
    mask.flags.lineBreakMode            = [self decodeLineBreakModeForAttributes: attributes];
    mask.flags.truncateLastLine         = [[attributes objectForKey: @"truncatesLastVisibleLine"] boolValue];
    mask.flags.continuous               = [[attributes objectForKey: @"continuous"] boolValue];
    mask.flags.singleLineMode           = [[attributes objectForKey: @"usesSingleLineMode"] boolValue];

    // FIXME: these are unknowns for now...
    mask.flags.actOnMouseDown           = NO;
    mask.flags.isLeaf                   = NO;
    mask.flags.invalidObjectValue       = NO;
    mask.flags.invalidFont              = NO;
    mask.flags.weakTargetHelperFlag     = NO;
    mask.flags.allowsAppearanceEffects  = NO;
    mask.flags.actOnMouseDragged        = NO;
    mask.flags.isLoaded                 = NO;
    mask.flags.dontActOnMouseUp         = NO;
    mask.flags.isWhite                  = NO;
    mask.flags.useUserKeyEquivalent     = NO;
    mask.flags.showsFirstResponder      = NO;
    
#if 0
    if ((title == nil) && (imageName == nil))
      mask.flags.type = NSNullCellType;
    else if (title == nil)
      mask.flags.type = NSImageCellType;
    else
      mask.flags.type = NSTextCellType;
#else
    if (imageName)
      mask.flags.type = NSImageCellType;
    else
      mask.flags.type = NSTextCellType;
#endif
    
    mask.flags.focusRingType = NSFocusRingTypeDefault;
    if ([@"exterior" isEqualToString: focusRingType])
      mask.flags.focusRingType = NSFocusRingTypeExterior;
    else if ([@"none" isEqualToString: focusRingType])
      mask.flags.focusRingType = NSFocusRingTypeNone;
    
    // Return mask...
    value = [NSNumber numberWithUnsignedInteger: mask.value];
  }
  
  return value;
}

- (id) decodeCellFlags2ForElement: (GSXib5Element*)element
{
  NSNumber *value = nil;
  Class     class = NSClassFromString([element attributeForKey: @"class"]);

  if ([class isSubclassOfClass: [NSCell class]])
  {
    GSCellFlags2Union  mask         = { { 0 } };
    NSDictionary      *attributes   = [element attributes];
#if 0
    NSString          *type         = [attributes objectForKey: @"type"];
#endif
    NSString          *alignment    = [attributes objectForKey: @"alignment"];
    NSString          *controlSize  = [attributes objectForKey: @"controlSize"];
    
#if defined(DEBUG_XIB5)
    NSWarnMLog(@"attributes: %@", attributes);
#endif
    
    mask.flags.allowsEditingTextAttributes  = 0;
    mask.flags.importsGraphics              = 0;
    mask.flags.lineBreakMode                = [self decodeLineBreakModeForAttributes: attributes];
    mask.flags.refusesFirstResponder        = [[attributes objectForKey: @"refusesFirstResponder"] boolValue];
    mask.flags.allowsMixedState             = [[attributes objectForKey: @"allowsMixedState"] boolValue];
    mask.flags.sendsActionOnEndEditing      = [[attributes objectForKey: @"sendsActionOnEndEditing"] boolValue];
    mask.flags.controlSize                  = NSRegularControlSize;
    mask.flags.doesNotAllowUndo             = 0;
    mask.flags.controlTint                  = NSDefaultControlTint;

    // Alignment
    mask.flags.alignment = NSNaturalTextAlignment;
    if ([@"left" isEqualToString: alignment])
      mask.flags.alignment = NSLeftTextAlignment;
    else if ([@"center" isEqualToString: alignment])
      mask.flags.alignment = NSCenterTextAlignment;
    else if ([@"right" isEqualToString: alignment])
      mask.flags.alignment = NSRightTextAlignment;
    else if ([@"justified" isEqualToString: alignment])
      mask.flags.alignment = NSJustifiedTextAlignment;
    else if (alignment)
      NSWarnMLog(@"unknown text alignment: %@", alignment);
    
    // Control size...
    if ([@"small" isEqualToString: controlSize])
      mask.flags.controlSize = NSSmallControlSize;
    else if ([@"mini" isEqualToString: controlSize])
      mask.flags.controlSize = NSMiniControlSize;
    else if ([@"regular" isEqualToString: controlSize])
      mask.flags.controlSize = NSRegularControlSize;
    else if (controlSize)
      NSWarnMLog(@"unknown control size: %@", controlSize);
    
    value = [NSNumber numberWithUnsignedInteger: mask.value];
  }
  
  return value;
}

- (id) decodeButtonFlags1ForElement: (GSXib5Element*)element
{
  NSNumber *value = nil;
  Class     class = NSClassFromString([element attributeForKey: @"class"]);

  if ([class isSubclassOfClass: [NSButtonCell class]])
  {
    typedef union _GSButtonCellFlagsUnion
    {
      GSButtonCellFlags flags;
      uint32_t          value;
    } GSButtonCellFlagsUnion;
    
    GSButtonCellFlagsUnion   mask       = { { 0 } };
    NSDictionary            *behavior   = [[element elementForKey: @"behavior"] attributes];
    NSDictionary            *attributes = [element attributes];
    NSString                *imagePos   = [attributes objectForKey: @"imagePosition"];
    
    mask.flags.isPushin               = [[behavior objectForKey: @"pushIn"]  boolValue];
    mask.flags.changeContents         = [[behavior objectForKey: @"changeContents"]  boolValue];
    mask.flags.changeBackground       = [[behavior objectForKey: @"changeBackground"]  boolValue];
    mask.flags.changeGray             = [[behavior objectForKey: @"changeGray"]  boolValue];
    
    mask.flags.highlightByContents    = [[behavior objectForKey: @"lightByContents"]  boolValue];
    mask.flags.highlightByBackground  = [[behavior objectForKey: @"lightByBackground"]  boolValue];
    mask.flags.highlightByGray        = [[behavior objectForKey: @"lightByGray"]  boolValue];
    mask.flags.drawing                = [[behavior objectForKey: @"drawing"]  boolValue];
    
    mask.flags.isBordered             = [attributes objectForKey: @"borderStyle"] != nil;
    mask.flags.imageDoesOverlap       = [@"only" isEqualToString: imagePos];
    mask.flags.imageDoesOverlap      |= [@"overlaps" isEqualToString: imagePos];
    mask.flags.isHorizontal           = [@"left" isEqualToString: imagePos];
    mask.flags.isHorizontal          |= [@"right" isEqualToString: imagePos];
    mask.flags.isBottomOrLeft         = [@"left" isEqualToString: imagePos];
    mask.flags.isBottomOrLeft        |= [@"bottom" isEqualToString: imagePos];
    
    mask.flags.isImageAndText         = [@"only" isEqualToString: [attributes objectForKey: @"imagePosition"]] == NO;
    mask.flags.isImageSizeDiff        = 1; // FIXME...
    //mask.flags.hasKeyEquiv            = [[behavior objectForKey: @"hasKeyEquiv"]  boolValue];
    //mask.flags.lastState              = [[behavior objectForKey: @"lastState"]  boolValue];

    mask.flags.isTransparent          = [[behavior objectForKey: @"transparent"]  boolValue];
    mask.flags.inset                  = [[attributes objectForKey: @"inset"] intValue];
    mask.flags.doesNotDimImage        = [[behavior objectForKey: @"doesNotDimImage"] boolValue];
    mask.flags.useButtonImageSource   = 0; //[attributes objectForKey: @"imagePosition"] != nil;
    //mask.flags.unused2                = [[behavior objectForKey: @"XXXXX"]  boolValue]; // alt mnem loc???
    
    // Return the value...
    value = [NSNumber numberWithUnsignedInteger: mask.value];
  }
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"mask: %@", value);
#endif
  
  return value;
}

- (id) decodeButtonFlags2ForElement: (GSXib5Element*)element
{
  NSNumber *value = nil;
  Class     class = NSClassFromString([element attributeForKey: @"class"]);
  
  if ([class isSubclassOfClass: [NSButtonCell class]])
  {
    typedef union _GSButtonCellFlags2Union
    {
      GSButtonCellFlags2 flags;
      uint32_t           value;
    } GSButtonCellFlags2Union;
    
    GSButtonCellFlags2Union  mask         = { { 0 } };
    NSDictionary            *attributes   = [element attributes];
    NSString                *bezelStyle   = [attributes objectForKey:@"bezelStyle"];
    NSString                *imageScaling = [attributes objectForKey:@"imageScaling"];
    
    if (bezelStyle)
    {
      uint32_t flag = NSRegularSquareBezelStyle; // Default if not specified...
      
      if ([@"rounded" isEqualToString: bezelStyle])
        flag = NSRoundedBezelStyle;
      else if ([@"regularSquare" isEqualToString: bezelStyle])
        flag = NSRegularSquareBezelStyle;
      else if ([@"disclosure" isEqualToString: bezelStyle])
        flag = NSDisclosureBezelStyle;
      else if ([@"shadowlessSquare" isEqualToString: bezelStyle])
        flag = NSShadowlessSquareBezelStyle;
      else if ([@"circular" isEqualToString: bezelStyle])
        flag = NSCircularBezelStyle;
      else if ([@"texturedSquare" isEqualToString: bezelStyle])
        flag = NSTexturedSquareBezelStyle;
      else if ([@"helpButton" isEqualToString: bezelStyle])
        flag = NSHelpButtonBezelStyle;
      else if ([@"smallSquare" isEqualToString: bezelStyle])
        flag = NSSmallSquareBezelStyle;
      else if ([@"texturedRounded" isEqualToString: bezelStyle])
        flag = NSTexturedRoundedBezelStyle;
      else if ([@"roundedRectangle" isEqualToString: bezelStyle])
        flag = NSRoundRectBezelStyle;
      else if ([@"roundedRect" isEqualToString: bezelStyle])
        flag = NSRoundRectBezelStyle;
      else if ([@"recessed" isEqualToString: bezelStyle])
        flag = NSRecessedBezelStyle;
      else if ([@"roundedDisclosure" isEqualToString: bezelStyle])
        flag = NSRoundedDisclosureBezelStyle;
#if 0
      else if ([@"inline" isEqualToString: bezelStyle])
        flag = NSInlineBezelStyle; // New value added in Cocoa version???
#endif
      else
        NSWarnMLog(@"unknown bezelStyle: %@", bezelStyle);
      
      mask.flags.bezelStyle  = (flag & 7);
      mask.flags.bezelStyle2 = (flag & 8) >> 3;
      if (flag == 0)
        NSWarnMLog(@"_bezel_style: %ld", (long)mask.value);
    }
    
    // Image scaling...
    if ([@"axesIndependently" isEqualToString: imageScaling])
    {
      mask.flags.imageScaling = 3;
    }
    else if ([@"proportionallyDown" isEqualToString: imageScaling])
    {
      mask.flags.imageScaling = 2;
    }
    else if ([@"proportionallyUpOrDown" isEqualToString: imageScaling])
    {
      mask.flags.imageScaling = 1;
    }
    else
    {
      // Warn about unknown image scaling to add later...
      if (imageScaling && [imageScaling length])
        NSWarnMLog(@"unknown image scaling: %@", imageScaling);
      mask.flags.imageScaling = 0;
    }
    
    // Return value...
    value = [NSNumber numberWithUnsignedInteger: mask.value];
  }
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"mask: %@", value);
#endif
  
  return value;
}

- (id) decodeCellNormalImageForElement: (GSXib5Element*)element
{
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  id    object  = nil;
  
  if ([class isSubclassOfClass: [NSCell class]])
  {
    if ([element attributeForKey: @"image"])
    {
      object = [NSImage imageNamed: [element attributeForKey: @"image"]];
    }
    else
    {
      NSString *type = [element attributeForKey: @"type"];
      
      if ([@"radio" isEqualToString: type])
      {
        object = [NSImage imageNamed: @"NSRadioButton"];
      }
      else if ([@"check" isEqualToString: type])
      {
        object = [NSImage imageNamed: @"NSSwitch"];
      }
    }
#if defined(DEBUG_XIB5)
    NSWarnMLog(@"object: %@", object);
#endif
  }
  
  return object;
}

- (id) decodeCellAlternateImageForElement: (GSXib5Element*)element
{
  Class class   = NSClassFromString([element attributeForKey: @"class"]);
  id    object  = nil;
  
  if ([class isSubclassOfClass: [NSCell class]])
  {
    if ([element attributeForKey: @"alternateImage"])
    {
      object = [NSImage imageNamed: [element attributeForKey: @"alternateImage"]];
    }
    else
    {
      NSString *type = [element attributeForKey: @"type"];
      
      if ([@"radio" isEqualToString: type])
      {
        object = [NSImage imageNamed: @"NSRadioButton"];
      }
      else if ([@"check" isEqualToString: type])
      {
        object = [NSImage imageNamed: @"NSSwitch"];
      }
    }
  }
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"object: %@", object);
#endif
  
  return object;
}

- (id) decodeButtonStateForElement: (GSXib5Element*)element
{
  id          object = nil;
  NSUInteger  state  = NSOffState;

  // If the current cell definition has no custom class defined...
  if ([element attributeForKey: @"state"])
    {
      // Check encompassing class for cellClass diversion...
      NSString *refstate = [element attributeForKey: @"state"];
      
      if ([@"on" isEqualToString: refstate])
        {
          state = NSOnState;
        }
      else if ([@"mized" isEqualToString: refstate])
        {
          state = NSMixedState;
        }
      else if (state)
        {
          NSWarnMLog(@"unknown cell state: %@", refstate);
        }
      
      // Generate the object normally...
      object = [NSNumber numberWithUnsignedInteger: state];
    }

  return object;
}

- (id) decodeCellForElement: (GSXib5Element*)topElement
{
  // Unfortunately cell classes can be overridden by their encompassing class so
  // we need to check for these manually...
  GSXib5Element *element = (GSXib5Element*)[topElement elementForKey: @"cell"];
  id             object  = nil;

  if (element != nil)
    {
      // If the current cell definition has no custom class defined...
      if ([element attributeForKey: @"customClass"] == nil)
        {
          // Check encompassing class for cellClass diversion...
          Class class = NSClassFromString([topElement attributeForKey: @"class"]);
          
          // If the encompassing class supports cellClass type...
          if ([class respondsToSelector: @selector(cellClass)])
            [element setAttribute: NSStringFromClass([class cellClass]) forKey: @"class"];
        }
      
      // Generate the object normally...
      object = [self objectForXib: element];
    }
  
  return object;
}

#pragma mark - Overridden decoding methods from base class...
- (id) objectForXib: (GSXibElement*)element
{
  id object = [super objectForXib: element];
  
  if (object == nil)
    {
      NSString *elementName = [element type];

      if (([@"outlet" isEqualToString: elementName]) ||
          ([@"action" isEqualToString: elementName]))
        {
          // Use the attributes for this result...
          object = [element attributes];
          
          if ([element attributeForKey: @"id"])
            [decoded setObject: object forKey: [element attributeForKey: @"id"]];
        }
      else if ([@"range" isEqualToString: elementName])
        {
          NSRange range = [self decodeRangeForKey: [element attributeForKey: @"key"]];
          object        = [NSValue valueWithRange: range];
          
          if ([element attributeForKey: @"id"])
            [decoded setObject: object forKey: [element attributeForKey: @"id"]];
        }
      else if ([XmlTagToDecoderSelectorMap objectForKey: elementName])
        {
          SEL selector = NSSelectorFromString([XmlTagToDecoderSelectorMap objectForKey: elementName]);
          object       = [self performSelector: selector withObject: element];
          
          if ([element attributeForKey: @"id"])
            [decoded setObject: object forKey: [element attributeForKey: @"id"]];
        }
#if 0
      else if ([[[elementName substringFromIndex:[elementName length]-4] lowercaseString] isEqualToString:@"mask"])
        {
          object = AUTORELEASE([[element attributes] copy]);
        }
#endif
    }
  
  return object;
}

- (id) nibInstantiate: (id)object
{
  id theObject = object;
  
  // Check whether object needs to be instantiated and awaken...
  if ([theObject respondsToSelector: @selector(nibInstantiate)])
  {
    // If this is the file's owner see if there is a value in the context...
    if ([theObject isKindOfClass: [NSCustomObject5 class]])
    {
      // Cross reference the file's owner object from the context data...
      if ([[(NSCustomObject5*)theObject userLabel] isEqualToString: @"File's Owner"])
      {
        if ([_context objectForKey: NSNibOwner])
        {
          [(NSCustomObject*)theObject setRealObject: [_context objectForKey: NSNibOwner]];
        }
      }
    }
    
    // Instantiate the real object...
    theObject = [theObject nibInstantiate];
  }
  
  return theObject;
}

- (void) awakeObjectFromNib: (id)object
{
  // We are going to awaken objects here - we're assuming that all
  // have been nibInstantiated when needed...
  if ([object respondsToSelector: @selector(awakeFromNib)])
    [object awakeFromNib];
}

- (Ivar) getClassVariableForObject: (id)object forName: (NSString*)property
{
  const char *name  = [property cString];
  Class       class = object_getClass(object);
  Ivar        ivar  = class_getInstanceVariable(class, name);
  
  // If not found...
  if (ivar == 0)
  {
    // Try other permutations...
    if ([property characterAtIndex: 0] == '_')
    {
      // Try removing the '_' prefix automatically added by Xcode...
      ivar = [self getClassVariableForObject: object forName: [property substringFromIndex: 1]];
    }
  }
  
  return ivar;
}

- (id) decodeObjectForXib: (GSXibElement*)element
             forClassName: (NSString*)classname
                   withID: (NSString*)objID
{
  id object     = [super decodeObjectForXib: element forClassName: classname withID: objID];
  id theObject  = [self nibInstantiate:object];

  // XIB 5 now stores connections etc as part of element objects...
  // NOTE: This code should follow the normal IBRecord-type processing.  However,
  //       obejcts are no longer referenced within the action/outlets/tooltips/etc
  //       constructs.  The connection constructs are now embedded within the object
  //       defined constructs so can be cross-referenced and instiated in real-time.
  //       We can eventually reconstruct the constructs manually to eventually follow
  //       the XIB loading process that was defined by the previous XIB format, but to
  //       expedite this code for use by Testplant I've decided to short cut that for now.
  //
  // Process tooltips...
  if ([element attributeForKey: @"toolTip"])
    {
      if ([theObject respondsToSelector: @selector(setToolTip:)])
        [theObject setToolTip: [element attributeForKey: @"toolTip"]];
      else if ([object respondsToSelector: @selector(setHeaderToolTip:)])
        [theObject setHeaderToolTip: [element attributeForKey: @"toolTip"]];
#if defined(DEBUG_XIB5)
      NSWarnMLog(@"object: %@ toolTip: %@", theObject, [element attributeForKey: @"toolTip"]);
#endif
    }
  
  // Process actions/outlets...
  if ([element elementForKey: @"connections"])
    {
      NSArray *connections = [self objectForXib: [element elementForKey: @"connections"]];

      // Process actions for object...
      {
        NSPredicate *predicate    = [NSPredicate predicateWithFormat:@"key == 'action'"];
        NSArray     *actions      = [connections filteredArrayUsingPredicate: predicate];
        
        if ([actions count])
        {
          NSDictionary *action   = [actions objectAtIndex: 0];
          NSString     *targetID = [action objectForKey: @"target"];
          id            target   = [self objectForXib: [objects objectForKey: targetID]];
          NSString     *selector = [action objectForKey: @"selector"];
          
          // Check whether target needs instantiation and awakening...
          target = [self nibInstantiate: target];

          [theObject setTarget: target];
          [theObject setAction: NSSelectorFromString(selector)];
        }
      }
  
      // Process outlets for object...
      {
        NSPredicate   *predicate    = [NSPredicate predicateWithFormat:@"key == 'outlet'"];
        NSArray       *outlets      = [connections filteredArrayUsingPredicate: predicate];
        NSEnumerator  *iter         = [outlets objectEnumerator];
        NSDictionary  *outlet       = nil;

        while ((outlet = [iter nextObject]) != nil)
        {
#if defined(DEBUG_XIB5)
          NSWarnMLog(@"processing outlet: %@", outlet);
#endif
          NSString      *property     = [outlet objectForKey: @"property"];
          NSString      *destID       = [outlet objectForKey: @"destination"];
          GSXib5Element *destElem     = [objects objectForKey: destID];
          id             destination  = [self objectForXib: destElem];
          NSString      *selectorName = [NSString stringWithFormat: @"set%@%@:",
                                         [[property substringToIndex: 1] uppercaseString],
                                         [property substringFromIndex: 1]];
          SEL            selector     = NSSelectorFromString(selectorName);
          
          
          // Check whether destination needs instantiation and awakening...
          destination = [self nibInstantiate: destination];
          
#if defined(DEBUG_XIB5)
          NSWarnMLog(@"source: %@ dest: %@ property: %@", theObject, destination, property);
#endif

          if (selector && [theObject respondsToSelector: selector])
          {
            [theObject performSelector: selector withObject: destination];
          }
          else
          {
            /*
             * We cannot use the KVC mechanism here, as this would always retain _dst
             * and it could also affect _setXXX methods and _XXX ivars that aren't
             * affected by the Cocoa code.
             */
            Ivar ivar = [self getClassVariableForObject: theObject forName: property];
            
            if (ivar != 0)
            {
              // This shouldn't be needed...
              RETAIN(destination);
              
              // Set the iVar...
              object_setIvar(theObject, ivar, destination);
            }
            else
            {
              NSWarnMLog(@"class '%@' has no instance var named: %@", [theObject className], property);
            }
          }
        }
      }
    }

  // Process runtime attributes for object...
  if ([element elementForKey: @"userDefinedRuntimeAttributes"])
    {
      GSXib5Element                   *ibDefinedRuntimeAttr = (GSXib5Element*)[element elementForKey: @"userDefinedRuntimeAttributes"];
      NSArray                         *runtimeAttributes    = [self objectForXib: ibDefinedRuntimeAttr];
      NSEnumerator                    *iter                 = [runtimeAttributes objectEnumerator];
      IBUserDefinedRuntimeAttribute5  *runtimeAttribute     = nil;
      
      while ((runtimeAttribute = [iter nextObject]) != nil)
      {
#if defined(DEBUG_XIB5)
        NSWarnMLog(@"processing object (%@) runtime attr: %@", object, runtimeAttribute);
#endif
        [theObject setValue: [runtimeAttribute value] forKeyPath: [runtimeAttribute keyPath]];
      }
    }
  
  // Awake from nib...
  [self awakeObjectFromNib: theObject];
  
  return object;
}

- (id)decodeObjectForKey:(NSString *)key
{
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"STARTING: key: %@ currentElement: %@ id: %@", key, [currentElement type], [currentElement attributeForKey: @"id"]);
#endif
  id object = [super decodeObjectForKey:key];
  
  // If not object try some other cases before defaulting to remove 'NS' prefix if present...
  if (object == nil)
    {
      // Try to reinterpret the request...
      if ([XmlKeyMapTable objectForKey: key])
        {
          object = [self decodeObjectForKey: [XmlKeyMapTable objectForKey: key]];
        }
      else if ([XmlKeyToDecoderSelectorMap objectForKey: key])
        {
          SEL selector = NSSelectorFromString([XmlKeyToDecoderSelectorMap objectForKey: key]);
          object       = [self performSelector: selector withObject: currentElement];
        }
      else if (([@"NSSearchButtonCell" isEqualToString: key]) ||
               ([@"NSCancelButtonCell" isEqualToString: key]))
        {
          // Search field encoding is real basic now...does not include these by default...
          // So we're going to generate them here for now...again should be moved into
          // class initWithCoder method eventually...
          object = AUTORELEASE([NSButtonCell new]);

          unsigned int      bFlags = 0x8444000;
          GSButtonCellFlags buttonCellFlags;

#if defined(DEBUG_XIB5)
          NSWarnMLog(@"title: %@ bFlags: %u", [object title], bFlags);
#endif
          
          memcpy((void *)&buttonCellFlags,(void *)&bFlags,sizeof(struct _GSButtonCellFlags));
          
          if ([@"NSSearchButtonCell" isEqualToString: key])
            [object setTitle: @"search"];
          else
            [object setTitle: @"clear"];
          
          [object setTransparent: buttonCellFlags.isTransparent];
          [object setBordered: buttonCellFlags.isBordered];
          
          [object setCellAttribute: NSPushInCell to: buttonCellFlags.isPushin];
          [object setCellAttribute: NSCellLightsByBackground to: buttonCellFlags.highlightByBackground];
          [object setCellAttribute: NSCellLightsByContents to: buttonCellFlags.highlightByContents];
          [object setCellAttribute: NSCellLightsByGray to: buttonCellFlags.highlightByGray];
          [object setCellAttribute: NSChangeBackgroundCell to: buttonCellFlags.changeBackground];
          [object setCellAttribute: NSCellChangesContents to: buttonCellFlags.changeContents];
          [object setCellAttribute: NSChangeGrayCell to: buttonCellFlags.changeGray];
          
          if (buttonCellFlags.imageDoesOverlap)
          {
            if (buttonCellFlags.isImageAndText)
              [object setImagePosition: NSImageOverlaps];
            else
              [object setImagePosition: NSImageOnly];
          }
          else if (buttonCellFlags.isImageAndText)
          {
            if (buttonCellFlags.isHorizontal)
            {
              if (buttonCellFlags.isBottomOrLeft)
                [object setImagePosition: NSImageLeft];
              else
                [object setImagePosition: NSImageRight];
            }
            else
            {
              if (buttonCellFlags.isBottomOrLeft)
                [object setImagePosition: NSImageBelow];
              else
                [object setImagePosition: NSImageAbove];
            }
          }
          else
          {
            [object setImagePosition: NSNoImage];
          }
#if 0
          [object setBordered: NO];
          [object setCellAttribute: NSPushInCell to: NO];
          [object setCellAttribute: NSChangeBackgroundCell to: NO];
          [object setCellAttribute: NSCellChangesContents to: NO];
          [object setCellAttribute: NSChangeGrayCell to: NO];
          [object setCellAttribute: NSCellLightsByContents to: YES];
          [object setCellAttribute: NSCellLightsByBackground to: NO];
          [object setCellAttribute: NSCellLightsByGray to: NO];
          [object setImagePosition: NSImageOnly];
          [object setImageScaling: NSImageScaleNone];
          [object setBezelStyle: NSRoundedBezelStyle];
#endif
        }
      else if (([@"NSSupport" isEqualToString: key]))
        {
          // This is the key Cocoa uses for fonts...
          // OR images - depending on what's encoded
          object = [self decodeObjectForKey: @"font"];
        }
      else if (([@"NSName" isEqualToString: key]) && ([@"font" isEqualToString: [currentElement attributeForKey: @"key"]]))
        {
          // We have to be careful with NSName as it is used by Cocoa in at least three places...
          object = [currentElement attributeForKey: @"name"];
        }
      else if ([key hasPrefix:@"NS"])
        {
          // Try a key minus a (potential) NS prefix...
          NSString *newKey = [key stringByDeletingPrefix: @"NS"];
          newKey           = [[[newKey substringToIndex:1] lowercaseString] stringByAppendingString:[newKey substringFromIndex:1]];
          object           = [self decodeObjectForKey:newKey];
        }
      else if ([XmlReferenceAttributes containsObject: key])
        {
          // Elements not stored INSIDE current element potentially need to be cross
          // referenced via attribute references...
          NSString      *idString = [currentElement attributeForKey: key];
          GSXib5Element *element  = [objects objectForKey:idString];
          object                  = [self objectForXib: element];
        }
      else
        {
          // New xib stores values as attributes...
          object = [currentElement attributeForKey: key];
        }
    }
  
#if 0
  if (object == nil)
    NSWarnMLog(@"no object for key: %@", key);
#endif
#if defined(DEBUG_XIB5)
  NSWarnMLog(@"DONE: key: %@ currentElement: %@ id: %@", key, [currentElement type], [currentElement attributeForKey: @"id"]);
#endif
  
  return object;
}

- (BOOL)decodeBoolForKey:(NSString *)key
{
  BOOL flag = NO;
  
  if ([super containsValueForKey:key])
  {
    flag = [super decodeBoolForKey:key];
  }
  else if ([XmlKeyMapTable objectForKey: key])
  {
    flag = [self decodeBoolForKey: [XmlKeyMapTable objectForKey: key]];
  }
  else if ([XmlKeyToDecoderSelectorMap objectForKey: key])
  {
    SEL selector = NSSelectorFromString([XmlKeyToDecoderSelectorMap objectForKey: key]);
    flag         = [[self performSelector: selector withObject: currentElement] boolValue];
  }
  else if ([currentElement attributeForKey: key])
  {
    flag = [[currentElement attributeForKey: key] boolValue];
  }
  else if ([key hasPrefix:@"NS"])
  {
    NSString *newKey = [key stringByDeletingPrefix:@"NS"];
    newKey = [[[newKey substringToIndex:1] lowercaseString] stringByAppendingString:[newKey substringFromIndex:1]];
    flag = [self decodeBoolForKey:newKey];
  }
#if 0
  else
  {
    NSWarnMLog(@"no BOOL for key: %@", key);
  }
#endif
  
  return flag;
}

- (double)decodeDoubleForKey:(NSString *)key
{
  double value = 0;
  
  if ([self containsValueForKey:key])
    {
      value = [super decodeDoubleForKey:key];
    }
  else if ([XmlKeyMapTable objectForKey: key])
  {
    value = [self decodeDoubleForKey: [XmlKeyMapTable objectForKey: key]];
  }
  else if ([XmlKeyToDecoderSelectorMap objectForKey: key])
  {
    SEL selector = NSSelectorFromString([XmlKeyToDecoderSelectorMap objectForKey: key]);
    value        = [[self performSelector: selector withObject: currentElement] doubleValue];
  }
  else if ([currentElement attributeForKey: key])
    {
      value = [[currentElement attributeForKey: key] doubleValue];
    }
  else if ([key hasPrefix:@"NS"])
    {
      NSString *newKey = [key stringByDeletingPrefix:@"NS"];
      newKey = [[[newKey substringToIndex:1] lowercaseString] stringByAppendingString:[newKey substringFromIndex:1]];
      value = [self decodeDoubleForKey:newKey];
    }
  else
    {
      NSWarnMLog(@"no DOUBLE for key: %@", key);
    }
  
  return value;
}

- (float)decodeFloatForKey:(NSString *)key
{
  return (float)[self decodeDoubleForKey: key];
}

- (int)decodeIntForKey:(NSString *)key
{
  int value = 0;
  
  if ([self containsValueForKey:key])
  {
    value = [super decodeIntForKey:key];
  }
  else if ([XmlKeyMapTable objectForKey: key])
  {
    value = [self decodeIntForKey: [XmlKeyMapTable objectForKey: key]];
  }
  else if ([XmlKeyToDecoderSelectorMap objectForKey: key])
  {
    SEL selector = NSSelectorFromString([XmlKeyToDecoderSelectorMap objectForKey: key]);
    value        = [[self performSelector: selector withObject: currentElement] intValue];
  }
  else if ([currentElement attributeForKey: key])
  {
    value = [[currentElement attributeForKey: key] integerValue];
  }
  else if ([key hasPrefix:@"NS"])
  {
    NSString *newKey = [key stringByDeletingPrefix:@"NS"];
    newKey = [[[newKey substringToIndex:1] lowercaseString] stringByAppendingString:[newKey substringFromIndex:1]];
    value = [self decodeIntegerForKey:newKey];
  }
  else
  {
    NSWarnMLog(@"no INT for key: %@", key);
  }
  
  return value;
}

- (NSInteger)decodeIntegerForKey:(NSString *)key
{
  NSInteger value = 0;
  
  if ([self containsValueForKey:key])
    {
      value = [super decodeIntegerForKey:key];
    }
  else if ([XmlKeyToDecoderSelectorMap objectForKey: key])
    {
      SEL selector = NSSelectorFromString([XmlKeyToDecoderSelectorMap objectForKey: key]);
      value        = [[self performSelector: selector withObject: currentElement] integerValue];
    }
  else if ([currentElement attributeForKey: key])
    {
      value = [[currentElement attributeForKey: key] integerValue];
    }
  else if ([key hasPrefix:@"NS"])
    {
      NSString *newKey = [key stringByDeletingPrefix:@"NS"];
      newKey = [[[newKey substringToIndex:1] lowercaseString] stringByAppendingString:[newKey substringFromIndex:1]];
      value = [self decodeIntegerForKey:newKey];
    }
  else
    {
      NSWarnMLog(@"no INTEGER for key: %@", key);
    }
  
  return value;
}

- (NSPoint) decodePointForKey:(NSString *)key
{
  NSPoint point = NSZeroPoint;
  
  // If the request element exists...
  if ([currentElement elementForKey: key])
  {
    GSXib5Element *element = (GSXib5Element*)[currentElement elementForKey: key];
    NSDictionary  *object  = [element attributes];
    
    point.x = [[object objectForKey:@"x"] doubleValue];
    point.y = [[object objectForKey:@"y"] doubleValue];
  }
  else if ([XmlKeyMapTable objectForKey: key])
  {
    point = [self decodePointForKey: [XmlKeyMapTable objectForKey: key]];
  }
  else if ([key hasPrefix:@"NS"])
  {
    NSString *newKey = [key stringByDeletingPrefix: @"NS"];
    newKey = [[[newKey substringToIndex:1] lowercaseString] stringByAppendingString: [newKey substringFromIndex:1]];
    point = [self decodePointForKey: newKey];
  }
  else
  {
    NSWarnMLog(@"no POINT for key: %@", key);
  }
  
  return point;

}

- (NSSize) decodeSizeForKey: (NSString*)key
{
  NSSize size = NSZeroSize;
  
  // If the request element exists...
  if ([currentElement elementForKey: key])
  {
    GSXib5Element *element = (GSXib5Element*)[currentElement elementForKey: key];
    NSDictionary  *object  = [element attributes];
    
    size.width  = [[object objectForKey:@"width"] doubleValue];
    size.height = [[object objectForKey:@"height"] doubleValue];
  }
  else if ([XmlKeyMapTable objectForKey: key])
  {
    size = [self decodeSizeForKey: [XmlKeyMapTable objectForKey: key]];
  }
  else if ([key hasPrefix:@"NS"])
  {
    NSString *newKey = [key stringByDeletingPrefix: @"NS"];
    NSString *prefix = [[newKey substringToIndex:1] lowercaseString];
    newKey           = [prefix stringByAppendingString: [newKey substringFromIndex:1]];
    size             = [self decodeSizeForKey: newKey];
  }
  else
  {
    NSWarnMLog(@"no SIZE for key: %@", key);
  }
  
  return size;
}

- (NSRect) decodeRectForKey: (NSString*)key
{
  NSRect frame = NSZeroRect;
  
  // If the request element exists...
  if ([currentElement elementForKey: key])
  {
    frame.origin  = [self decodePointForKey: key];
    frame.size    = [self decodeSizeForKey: key];
  }
  else if ([XmlKeyMapTable objectForKey: key])
  {
    frame = [self decodeRectForKey: [XmlKeyMapTable objectForKey: key]];
  }
  else if ([key hasPrefix:@"NS"])
  {
    NSString *newKey = [key stringByDeletingPrefix: @"NS"];
    newKey = [[[newKey substringToIndex:1] lowercaseString] stringByAppendingString: [newKey substringFromIndex:1]];
    frame = [self decodeRectForKey: newKey];
  }
  else
  {
    NSWarnMLog(@"no RECT for key: %@", key);
  }
  
  return frame;
}

- (NSRange) decodeRangeForKey: (NSString*)key
{
  NSRange        range   = NSMakeRange(0, 0);
  GSXib5Element *element = (GSXib5Element*)[currentElement elementForKey: key];

  // If the request element exists...
  if (element)
  {
    range.location  = [[element attributeForKey: @"location"] integerValue];
    range.length    = [[element attributeForKey: @"length"] integerValue];
  }
  else
  {
    NSWarnMLog(@"no RANGE for key: %@", key);
  }
  
  return range;
}

- (BOOL)containsValueForKey:(NSString *)key
{
  BOOL hasValue = [super containsValueForKey:key];
  
  // Check attributes (for XIB 5 and above) for additional values...
  if (hasValue == NO)
    {
      hasValue = [currentElement attributeForKey: key] != nil;
    }
  
  // If that didn't work...
  if (hasValue == NO)
    {
      // Try reinterpreting the request...
      if ([XmlKeyMapTable objectForKey: key])
        {
          hasValue = [self containsValueForKey: [XmlKeyMapTable objectForKey: key]];
        }
      else if (([@"NSIntercellSpacingHeight" isEqualToString: key]) ||
               ([@"NSIntercellSpacingWidth" isEqualToString: key]))
        {
          hasValue = [currentElement elementForKey: @"intercellSpacing"] != nil;
        }
      else if ([@"NSContents" isEqualToString: key])
        {
          hasValue  = [currentElement attributeForKey: @"title"] != nil;
          hasValue |= [currentElement attributeForKey: @"image"] != nil;
        }
      else if ([@"NSAlternateImage" isEqualToString: key])
        {
          hasValue = [currentElement attributeForKey: @"alternateImage"] != nil;
        }
      else if ([@"NSAlternateContents" isEqualToString: key])
        {
          hasValue = [currentElement attributeForKey: @"alternateTitle"] != nil;
        }
      else if ([XmlKeysDefined containsObject: key])
        {
          // These are arbitrarily defined through hard-coding...
          hasValue = YES;
        }
      else if ([key hasPrefix:@"NS"])
        {
          // Try a key minus a (potential) NS prefix...
          NSString *newKey = [key stringByDeletingPrefix:@"NS"];
          newKey = [[[newKey substringToIndex:1] lowercaseString] stringByAppendingString:[newKey substringFromIndex:1]];
          hasValue = [self containsValueForKey:newKey];
        }
      else
        {
          // Check special cases...
          if (([@"action" isEqualToString: key]) || ([@"target" isEqualToString: key]))
            {
              // Target is stored in the action XIB element - if present - which is
              // stored under the connections array element...
              NSArray     *connections = [self objectForXib: [currentElement elementForKey: @"connections"]];
              NSPredicate *predicate   = [NSPredicate predicateWithFormat:@"key == 'action'"];
              NSArray     *actions     = [connections filteredArrayUsingPredicate: predicate];
              hasValue = ([actions count] != 0);
              
#if defined(DEBUG_XIB5)
              // FOR DEBUG...
              if ([actions count] == 0)
              {
                NSWarnMLog(@"no action available for target request");
              }
#endif
            }
        }
    }
  
  return hasValue;
}

@end

#if 0
#pragma mark - NSObject (NSKeyedUnarchiverDelegate) Protocol...
@implementation NSObject (NSKeyedUnarchiverDelegate)
/** <override-dummy />
 */
- (Class) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
cannotDecodeObjectOfClassName: (NSString*)aName
     originalClasses: (NSArray*)classNames
{
  return nil;
}
/** <override-dummy />
 */
- (id) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  didDecodeObject: (id)anObject
{
  return anObject;
}
/** <override-dummy />
 */
- (void) unarchiverDidFinish: (NSKeyedUnarchiver*)anUnarchiver
{
}
/** <override-dummy />
 */
- (void) unarchiverWillFinish: (NSKeyedUnarchiver*)anUnarchiver
{
}
/** <override-dummy />
 */
- (void) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  willReplaceObject: (id)anObject
         withObject: (id)newObject
{
}
@end

@implementation NSObject (NSKeyedUnarchiverObjectSubstitution)
+ (Class) classForKeyedUnarchiver
{
  return self;
}
@end
#endif
