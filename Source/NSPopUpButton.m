/* 
   NSPopUpButton.m

   Popup list class

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996
   Author: Michael Hanni <mhanni@sprintmail.com>
   Date: June 1999
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#include <gnustep/gui/config.h>
#import <Foundation/Foundation.h>
#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSPopUpButtonCell.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSMenuView.h>
#include <AppKit/NSFont.h>

//
// NSPopUpButton implementation
//

@implementation NSPopUpButton

///////////////////////////////////////////////////////////////
//
// Class methods
//
+ (void)initialize
{
  if (self == [NSPopUpButton class])
    {
      // Initial version
      [self setVersion:1];
    }
}

//
// Initializing an NSPopUpButton 
//
- init
{
  return [self initWithFrame:NSZeroRect pullsDown:NO];
}

- (id)initWithFrame:(NSRect)frameRect
{
  return [self initWithFrame:frameRect pullsDown:NO];
}

- (id)initWithFrame:(NSRect)frameRect
	  pullsDown:(BOOL)flag
{
  [super initWithFrame:frameRect];
  list_items = [NSMutableArray new];

  popb_view = [[NSMenuView alloc] initWithFrame:frameRect 
		cellSize: NSMakeSize (frameRect.size.width,
		frameRect.size.height)];
  [popb_view setPopUpButton: self];

  is_up = NO;
  pulls_down = flag;
  selected_item = 0;

  return self;
}

- (void) dealloc
{
  [list_items release];
  [super dealloc];
}

//
// Target and Action 
//
- (SEL)action
{
  return pub_action;
}

- (void)setAction:(SEL)aSelector
{
  pub_action = aSelector;
}

- (id)target
{
  return pub_target;
}

- (void)setTarget:(id)anObject
{
  pub_target = anObject;
}

- (void)buttonSelected:(id)sender
{
  if (!pulls_down)
    selected_item = [self indexOfItemWithTitle:[sender title]];
  else
    selected_item = 0;

  [self synchronizeTitleAndSelectedItem];

  [self close];

  [self lockFocus];
  [self drawRect:[self frame]];
  [self unlockFocus];
  [self setNeedsDisplay:YES];

  if (pub_target && pub_action)
    [pub_target performSelector:pub_action withObject:self];
}

//
// Adding Items 
//
- (void)addItemWithTitle:(NSString *)title
{
  [self insertItemWithTitle:title atIndex:[list_items count]];
}

- (void)addItemsWithTitles:(NSArray *)itemTitles
{
  int i, count = [itemTitles count];

  for (i = 0; i < count; i++)
    [self addItemWithTitle:[itemTitles objectAtIndex:i]];
}

- (void)insertItemWithTitle:(NSString *)title
		    atIndex:(unsigned int)index
{
  id menuCell = [[NSPopUpButtonCell new] autorelease];

  [menuCell setFont: [NSFont systemFontOfSize:12]];
  [menuCell setTitle: title];
  [menuCell setTarget: self];
  [menuCell setAction: @selector(buttonSelected:)];
                                
  [list_items insertObject: menuCell atIndex: index];   

  [self synchronizeTitleAndSelectedItem];
}

//
// Removing Items 
//
- (void)removeAllItems
{
  [list_items removeAllObjects];
}

- (void)removeItemWithTitle:(NSString *)title
{
  int index = [self indexOfItemWithTitle:title];

  if (index != NSNotFound)
    [list_items removeObjectAtIndex:index];
}

- (void)removeItemAtIndex:(int)index
{
  [list_items removeObjectAtIndex:index];
}

//
// Querying the NSPopUpButton about Its Items 
//
- (int)indexOfItemWithTitle:(NSString *)title
{
  int i, count = [list_items count];

  for (i = 0; i < count; i++)
    if ([[[list_items objectAtIndex:i] title] isEqual:title])
      return i;

  return NSNotFound;
}

- (int)indexOfSelectedItem
{
  return selected_item;
}

- (int)numberOfItems
{
  return [list_items count];
}

- (id <NSMenuItem>)itemAtIndex:(int)index
{
  return [list_items objectAtIndex:index];
}

- (NSArray *)itemArray
{
  return list_items;
}

- (NSString *)itemTitleAtIndex:(int)index
{
  return [[list_items objectAtIndex:index] title];
}

- (NSArray *)itemTitles
{
  int i, count = [list_items count];
  NSMutableArray* titles = [NSMutableArray arrayWithCapacity:count];

  for (i = 0; i < count; i++)
    [titles addObject:[[list_items objectAtIndex:i] title]];

  return titles;
}

- (id <NSMenuItem>)itemWithTitle:(NSString *)title
{
  int index = [self indexOfItemWithTitle:title];

  if (index != NSNotFound)
    return [list_items objectAtIndex:index];
  return nil;
}

- (id <NSMenuItem>)lastItem
{
  if ([list_items count])
    return [list_items lastObject];
  else
    return nil;
}

- (id <NSMenuItem>)selectedItem
{
  return [list_items objectAtIndex:selected_item];
}

- (NSString *)titleOfSelectedItem
{
  return [[self selectedItem] title];
}

//
// Manipulating the NSPopUpButton
//
- (NSFont *)font
{
  return nil;
}

- (BOOL)pullsDown
{
  return pulls_down;
}

- (void)selectItemAtIndex:(int)index
{
  if ((index >= 0) && (index < [list_items count]))
    {
      selected_item = index;
      [self synchronizeTitleAndSelectedItem];
    }
}

- (void)selectItemWithTitle:(NSString *)title
{
  int index = [self indexOfItemWithTitle:title];

  if (index != NSNotFound)
    [self selectItemAtIndex:index];
}

- (void)setFont:(NSFont *)fontObject
{}

- (void)setPullsDown:(BOOL)flag
{
  pulls_down = flag;
}

- (void)setTitle:(NSString *)aString
{}

- (NSString *)stringValue
{
  return nil;
}

- (void)synchronizeTitleAndSelectedItem
{
//  if (!pulls_down)
//    [list_items setIndexOfSelectedItem:selected_item];
//  else
//    [list_items setIndexOfSelectedItem:0];
}

//
// Displaying the NSPopUpButton's Items 
//
- (BOOL)autoenablesItems
{
  return NO;
}

- (void)setAutoenablesItems:(BOOL)flag
{}

//
// Handle events
//
- (void)mouseDown:(NSEvent *)theEvent
{
}

- (void)mouseUp:(NSEvent *)theEvent
{
}

- (void)mouseMoved:(NSEvent *)theEvent
{
}

- (NSView *)hitTest:(NSPoint)aPoint
{
  // First check ourselves
//  if ([self mouse:aPoint inRect:bounds]) return self;
  if ([self mouse:aPoint inRect:[self frame]]) return self;

  return nil;
}

//
// Displaying
//
- (void)drawRect:(NSRect)rect
{
  id aCell;

  if ([list_items count] == 0)
    return;

  if (!pulls_down)
    aCell  = [list_items objectAtIndex:selected_item]; 
  else
    aCell  = [list_items objectAtIndex:0]; 

  [aCell drawWithFrame:rect inView:self]; 
}

//
// NSCoding protocol
//
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];

  [aCoder encodeObject: list_items];
  [aCoder encodeRect: list_rect];
  [aCoder encodeValueOfObjCType: @encode(int) at: &selected_item];
  [aCoder encodeConditionalObject: pub_target];
  [aCoder encodeValueOfObjCType: @encode(SEL) at: &pub_action];
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &is_up];
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &pulls_down];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  [super initWithCoder: aDecoder];

  [aDecoder decodeValueOfObjCType: @encode(id) at: &list_items];
  list_rect = [aDecoder decodeRect];
  [aDecoder decodeValueOfObjCType: @encode(int) at: &selected_item];
  pub_target = [aDecoder decodeObject];
  [aDecoder decodeValueOfObjCType: @encode(SEL) at: &pub_action];
  [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &is_up];
  [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &pulls_down];

  return self;
}

@end
