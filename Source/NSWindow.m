/** <title>NSWindow</title>

   <abstract>The window class</abstract>

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
	    Venkat Ajjanagadde <venkat@ocbi.com>
   Date: 1996
   Author: Felipe A. Rodriguez <far@ix.netcom.com>
   Date: June 1998
   Author: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: December 1998

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include "config.h"

#include <Foundation/NSDebug.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSUserDefaults.h>

#include "AppKit/NSApplication.h"
#include "AppKit/NSButtonCell.h"
#include "AppKit/NSCachedImageRep.h"
#include "AppKit/NSColor.h"
#include "AppKit/NSColorList.h"
#include "AppKit/NSCursor.h"
#include "AppKit/NSDocument.h"
#include "AppKit/NSDragging.h"
#include "AppKit/NSFont.h"
#include "AppKit/NSGraphics.h"
#include "AppKit/NSHelpManager.h"
#include "AppKit/NSImage.h"
#include "AppKit/NSMenu.h"
#include "AppKit/NSPasteboard.h"
#include "AppKit/NSScreen.h"
#include "AppKit/NSTextField.h"
#include "AppKit/NSTextFieldCell.h"
#include "AppKit/NSToolbar.h"
#include "AppKit/NSView.h"
#include "AppKit/NSWindow.h"
#include "AppKit/NSWindowController.h"
#include "AppKit/PSOperators.h"
#include "GNUstepGUI/GSTrackingRect.h"
#include "GNUstepGUI/GSDisplayServer.h"
#include "GNUstepGUI/GSToolbarView.h"

#include "GSWindowDecorationView.h"

static id<GSWindowDecorator> windowDecorator;


BOOL GSViewAcceptsDrag(NSView *v, id<NSDraggingInfo> dragInfo);

@interface NSObject (DragInfoBackend)
- (void) dragImage: (NSImage*)anImage
		at: (NSPoint)screenLocation
	    offset: (NSSize)initialOffset
	     event: (NSEvent*)event
	pasteboard: (NSPasteboard*)pboard
	    source: (id)sourceObject
	 slideBack: (BOOL)slideFlag;
- (void) postDragEvent: (NSEvent*)event;
@end

/*
 * Category for internal methods (for use only within the NSWindow class itself
 * or with other AppKit classes in the case of the _windowView method)
 */
@interface	NSWindow (GNUstepPrivate)
+(void) _addAutodisplayedWindow: (NSWindow *)w;
+(void) _removeAutodisplayedWindow: (NSWindow *)w;

- (void) _lossOfKeyOrMainWindow;
- (NSView *) _windowView; 
// Method used to support validation in the toolbar implementation 
@end

@implementation	NSWindow (GNUstepPrivate)


/* Window autodisplay machinery. */
- (void) _handleAutodisplay
{
  if (_f.is_autodisplay && _rFlags.needs_display)
    {
      [self disableFlushWindow];
      [self displayIfNeeded];
      [self enableFlushWindow];
      [self flushWindowIfNeeded];
    }
}

static NSArray *modes = nil;

#define GSI_ARRAY_TYPES		0
#define GSI_ARRAY_TYPE		NSWindow *
#define GSI_ARRAY_NO_RELEASE	1
#define GSI_ARRAY_NO_RETAIN	1

#ifdef GSIArray
#undef GSIArray
#endif
#include <GNUstepBase/GSIArray.h>

/* Array of windows we might need to handle autodisplay for (in practice
a list of windows that are, wrt. -gui, on-screen). */
static GSIArray_t autodisplayedWindows;

/*
This method handles all normal displaying. It is set to be run on each
runloop iteration when the first window is created

The reason why this performer is always added, as opposed to adding it
when display is needed and not re-adding it here, is that
-setNeedsDisplay* might be called from a method invoked by
-performSelector:target:argument:order:modes:, and if it is, the display
needs to happen in the same runloop iteration, before blocking for
events. If the performer were added in a call to another performer, it
wouldn't be called until the next runloop iteration, ie. after the runloop
has blocked and waited for events.
*/
+(void) _handleAutodisplay: (id)bogus
{
  int i;
  for (i = 0; i < GSIArrayCount(&autodisplayedWindows); i++)
    [GSIArrayItemAtIndex(&autodisplayedWindows, i).ext _handleAutodisplay];

  [[NSRunLoop currentRunLoop]
	 performSelector: @selector(_handleAutodisplay:)
		  target: self
		argument: nil
		   order: 600000
		   modes: modes];
}

+(void) _addAutodisplayedWindow: (NSWindow *)w
{
  int i;
  /* If it's the first time we're called, set up the performer and modes
  array. */
  if (!modes)
    {
      modes = [[NSArray alloc] initWithObjects: NSDefaultRunLoopMode,
			       NSModalPanelRunLoopMode,
			       NSEventTrackingRunLoopMode, nil];
      [[NSRunLoop currentRunLoop]
	 performSelector: @selector(_handleAutodisplay:)
		  target: self
		argument: nil
		   order: 600000
		   modes: modes];
      GSIArrayInitWithZoneAndCapacity(&autodisplayedWindows,
	NSDefaultMallocZone(), 1);
    }

  /* O(n), but it's much more important that _handleAutodisplay: can iterate
  quickly over the array. (_handleAutodisplay: is called once for every
  event, this method is only called when windows are ordered in or out.) */
  for (i = 0; i < GSIArrayCount(&autodisplayedWindows); i++)
    if (GSIArrayItemAtIndex(&autodisplayedWindows, i).ext == w)
      return;
  GSIArrayAddItem(&autodisplayedWindows, (GSIArrayItem)w);
}

+(void) _removeAutodisplayedWindow: (NSWindow *)w
{
  int i;
  for (i = 0; i < GSIArrayCount(&autodisplayedWindows); i++)
    if (GSIArrayItemAtIndex(&autodisplayedWindows, i).ext == w)
      {
	GSIArrayRemoveItemAtIndex(&autodisplayedWindows, i);
	return;
      }
  /* This happens eg. if a window is ordered out twice. In such cases,
  the window has already been removed from the list, so we don't need
  to do anything here. */
}


/* We get here if we were ordered out or miniaturized. In this case if
   we were the key or main window, go through the list of all windows
   and try to find another window that can take our place as key
   and/or main. Automatically ignore windows that cannot become
   key/main and skip the main menu window (which is the only
   non-obvious window that can become key) unless we have no choice
   (i.e. all the candidate windows were ordered out.)

   FIXME: It would really be better if we maintained a stack of the
   most recent key/main windows and went through in order of most
   recent to least recent. That's probably a lot of work, however.
*/
- (void) _lossOfKeyOrMainWindow
{
  NSArray	*windowList = GSAllWindows();
  unsigned	pos = [windowList indexOfObjectIdenticalTo: self];
  unsigned	c = [windowList count];
  unsigned	i;
  NSWindow	*w;

  if ([self isKeyWindow])
    {
      NSWindow *menu_window= [[NSApp mainMenu] window];
      [self resignKeyWindow];
      i = pos + 1;
      if (i == c)
	{
	  i = 0;
	}
      while (i != pos)
	{
	  w = [windowList objectAtIndex: i];
	  if ([w isVisible] && [w canBecomeKeyWindow] && w != menu_window)
	    {
	      [w makeKeyWindow];
	      break;
	    }

	  i++;
	  if (i == c)
	    {
	      i = 0;
	    }
	}
      /*
       * if we didn't find a possible key window - use the main menu window
       */
      if (i == pos)
	{
	  if (menu_window != nil)
	    {
	      [GSServerForWindow(menu_window) setinputfocus: 
				  [menu_window windowNumber]];
	    }
	}
    }
  if ([self isMainWindow])
    {
      NSWindow	*w = [NSApp keyWindow];

      [self resignMainWindow];
      if (w != nil && [w canBecomeMainWindow])
	{
	  [w makeMainWindow];
	}
      else
	{
	  i = pos + 1;
	  if (i == c)
	    {
	      i = 0;
	    }
	  while (i != pos)
	    {
	      w = [windowList objectAtIndex: i];
	      if ([w isVisible] && [w canBecomeMainWindow])
		{
		  [w makeMainWindow];
		  break;
		}
	    
	      i++;
	      if (i == c)
		{
		  i = 0;
		}		  
	    }
	}
    }
}

- (NSView *) _windowView
{
  return _wv;
}
@end




@interface	NSMiniWindow : NSWindow
@end

@implementation	NSMiniWindow

- (BOOL) canBecomeMainWindow
{
  return NO;
}

- (BOOL) canBecomeKeyWindow
{
  return NO;
}

- (void) _initDefaults
{
  [super _initDefaults];
  [self setExcludedFromWindowsMenu: YES];
  [self setReleasedWhenClosed: NO];
  _windowLevel = NSDockWindowLevel;
}

@end

@interface NSMiniWindowView : NSView
{
  NSCell		*imageCell;
  NSTextFieldCell	*titleCell;
}
- (void) setImage: (NSImage*)anImage;
- (void) setTitle: (NSString*)aString;
@end

static NSCell	*tileCell = nil;

@implementation NSMiniWindowView

+ (void) initialize
{
  NSImage *tileImage = [NSImage imageNamed: @"common_MiniWindowTile"];

  tileCell = [[NSCell alloc] initImageCell: tileImage];
  [tileCell setBordered: NO];
}

- (BOOL) acceptsFirstMouse: (NSEvent*)theEvent
{
  return YES;
}

- (void) dealloc
{
  TEST_RELEASE(imageCell);
  TEST_RELEASE(titleCell);
  [super dealloc];
}

- (void) drawRect: (NSRect)rect
{                                                
  [tileCell drawWithFrame: NSMakeRect(0,0,64,64) inView: self];
  [imageCell drawWithFrame: NSMakeRect(8,4,48,48) inView: self];
  [titleCell drawWithFrame: NSMakeRect(1,52,62,11) inView: self];
}

- (void) mouseDown: (NSEvent*)theEvent
{
  if ([theEvent clickCount] >= 2)
    {
      NSWindow	*w = [_window counterpart];
      [w deminiaturize: self];
    }
  else
    {
      NSPoint	lastLocation;
      NSPoint	location;
      unsigned	eventMask = NSLeftMouseDownMask | NSLeftMouseUpMask
	| NSPeriodicMask | NSOtherMouseUpMask | NSRightMouseUpMask;
      NSDate	*theDistantFuture = [NSDate distantFuture];
      BOOL	done = NO;

      lastLocation = [theEvent locationInWindow];
      [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.02];

      while (!done)
	{
	  theEvent = [NSApp nextEventMatchingMask: eventMask
					untilDate: theDistantFuture
					   inMode: NSEventTrackingRunLoopMode
					  dequeue: YES];
	
	  switch ([theEvent type])
	    {
	      case NSRightMouseUp:
	      case NSOtherMouseUp:
	      case NSLeftMouseUp:
	      /* right mouse up or left mouse up means we're done */
		done = YES;
		break;
	      case NSPeriodic:
		location = [_window mouseLocationOutsideOfEventStream];
		if (NSEqualPoints(location, lastLocation) == NO)
		  {
		    NSPoint	origin = [_window frame].origin;

		    origin.x += (location.x - lastLocation.x);
		    origin.y += (location.y - lastLocation.y);
		    [_window setFrameOrigin: origin];
		  }
		break;

	      default:
		break;
	    }
	}
      [NSEvent stopPeriodicEvents];
    }
}                                                        

- (void) setImage: (NSImage*)anImage
{
  if (imageCell == nil)
    {
      imageCell = [[NSCell alloc] initImageCell: anImage];
      [imageCell setBordered: NO];
    }
  else
    {
      [imageCell setImage: anImage];
    }
  if ([self lockFocusIfCanDraw])
    {
      [self drawRect: [self bounds]];
      [self unlockFocus];
      [_window flushWindow];
    }
}

- (void) setTitle: (NSString*)aString
{
  if (titleCell == nil)
    {
      titleCell = [[NSTextFieldCell alloc] initTextCell: aString];
      [titleCell setSelectable: NO];
      [titleCell setEditable: NO];
      [titleCell setBordered: NO];
      [titleCell setAlignment: NSCenterTextAlignment];
      [titleCell setDrawsBackground: NO];
      [titleCell setTextColor: [NSColor whiteColor]];
      [titleCell setFont: [NSFont systemFontOfSize: 8]];
    }
  else
    {
      [titleCell setStringValue: aString];
    }
  if ([self lockFocusIfCanDraw])
    {
      [self drawRect: [self bounds]];
      [self unlockFocus];
      [_window flushWindow];
    }
}

@end



/*****************************************************************************
 *
 *	NSWindow
 *
 *****************************************************************************/

/**
  <unit>
  <heading>NSWindow</heading>
  
  <p> Instances of the NSWindow class handle on-screen windows, their
  associated NSViews, and events generate by the user.  An NSWindow's
  size is defined by its frame rectangle, which encompasses its entire
  structure, and its content rectangle, which includes only the
  content.  
  </p>

  <p> Every NSWindow has a content view, the NSView which forms the
  root of the window's view hierarchy.  This view can be set using the
  <code>setContentView:</code> method, and accessed through the
  <code>contentView</code> method.  <code>setContentView:</code>
  replaces the default content view created by NSWindow.  
  </p>

  <p> Other views may be added to the window by using the content
  view's <code>addSubview:</code> method.  These subviews can also
  have subviews added, forming a tree structure, the view hierarchy.
  When an NSWindow must display itself, it causes this hierarchy to
  draw itself.  Leaf nodes in the view hierarchy are drawn last,
  causing them to potentially obscure views further up in the
  hierarchy.  
  </p>

  <p> A delegate can be specified for an NSWindow, which will receive
  notifications of events pertaining to the window.  The delegate is
  set using <code>setDelegate:</code>, and can be retrieved using
  <code>delegate</code>.  The delegate can restrain resizing by
  implementing the <code>windowWillResize: toSize:</code> method, or
  control the closing of the window by implementing
  <code>windowShouldClose:</code>.  
  </p> 

  </unit>
*/
@implementation NSWindow

typedef struct NSView_struct
{
  @defs(NSView)
} *NSViewPtr;


/*
 * Class variables
 */
static SEL	ccSel;
static SEL	ctSel;
static IMP	ccImp;
static IMP	ctImp;
static Class	responderClass;
static Class	viewClass;
static NSMutableSet	*autosaveNames;
static NSMapTable* windowmaps = NULL;
static NSNotificationCenter *nc = nil;

/*
 * Class methods
 */
+ (void) initialize
{
  if (self == [NSWindow class])
    {
      [self setVersion: 2];
      ccSel = @selector(_checkCursorRectangles:forEvent:);
      ctSel = @selector(_checkTrackingRectangles:forEvent:);
      ccImp = [self instanceMethodForSelector: ccSel];
      ctImp = [self instanceMethodForSelector: ctSel];
      responderClass = [NSResponder class];
      viewClass = [NSView class];
      autosaveNames = [NSMutableSet new];
      nc = [NSNotificationCenter defaultCenter];
    }
}

+ (void) removeFrameUsingName: (NSString*)name
{
  if (name != nil)
    {
      NSString	*key;

      key = [NSString stringWithFormat: @"NSWindow Frame %@", name];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey: key];
    }
}

+ (NSRect) contentRectForFrameRect: (NSRect)aRect
			 styleMask: (unsigned int)aStyle
{
  if (!windowDecorator)
    windowDecorator = [GSWindowDecorationView windowDecorator];

  return [windowDecorator contentRectForFrameRect: aRect
					styleMask: aStyle];
}

+ (NSRect) frameRectForContentRect: (NSRect)aRect
			 styleMask: (unsigned int)aStyle
{
  if (!windowDecorator)
    windowDecorator = [GSWindowDecorationView windowDecorator];

  return [windowDecorator frameRectForContentRect: aRect
					styleMask: aStyle];
}

+ (float) minFrameWidthWithTitle: (NSString *)aTitle
		       styleMask: (unsigned int)aStyle
{
  if (!windowDecorator)
    windowDecorator = [GSWindowDecorationView windowDecorator];

  return [windowDecorator minFrameWidthWithTitle: aTitle
				       styleMask: aStyle];
}

/* default Screen and window depth */
+ (NSWindowDepth) defaultDepthLimit
{
  return [[NSScreen deepestScreen] depth];
}

+ (void)menuChanged: (NSMenu*)aMenu
{
  // FIXME: This method is for MS Windows only, does nothing 
  // on other window systems 
}

/*
 * Instance methods
 */
- (id) init
{
  int style;

  style = NSTitledWindowMask | NSClosableWindowMask
	  | NSMiniaturizableWindowMask | NSResizableWindowMask;

  return [self initWithContentRect: NSZeroRect
			 styleMask: style
			   backing: NSBackingStoreBuffered
			     defer: NO];
}

/*
It is important to make sure that the window is in a meaningful state after
this has been called, and that the backend window can be recreated later,
since one-shot windows may have their backend windows created and terminated
many times.
*/
- (void) _terminateBackendWindow
{
  NSGraphicsContext *context = GSCurrentContext();

  /* Check for context also as it might have disappeared before us */
  if (context && _gstate)
    {
      GSUndefineGState(context, _gstate);
      _gstate = 0;
    }
  
  if (_windowNum)
    {
      [_wv setWindowNumber: 0];
      [GSServerForWindow(self) termwindow: _windowNum];
      NSMapRemove(windowmaps, (void*)_windowNum);
      _windowNum = 0;
    }
}

- (void) dealloc
{
  [nc removeObserver: self];
  [isa _removeAutodisplayedWindow: self];
  [NSApp removeWindowsItem: self];
  [NSApp _windowWillDealloc: self];

  NSAssert([NSApp keyWindow] != self, @"window being deallocated is key");
  NSAssert([NSApp mainWindow] != self, @"window being deallocated is main");

  if (_autosaveName != nil)
    {
      [autosaveNames removeObject: _autosaveName];
      _autosaveName = nil;
    }

  if (_counterpart != 0 && (_styleMask & NSMiniWindowMask) == 0)
    {
      NSWindow	*mini = [NSApp windowWithWindowNumber: _counterpart];

      _counterpart = 0;
      RELEASE(mini);
    }
  /* Clean references to this window - important if some of the views
     are not deallocated now */
  [_wv viewWillMoveToWindow: nil];
  /* NB: releasing the window view does not necessarily result in the
     deallocation of the window's views ! - some of them might be
     retained for some other reason by the programmer or by other
     parts of the code */
  DESTROY(_wv);
  TEST_RELEASE(_fieldEditor);
  TEST_RELEASE(_backgroundColor);
  TEST_RELEASE(_representedFilename);
  TEST_RELEASE(_miniaturizedTitle);
  TEST_RELEASE(_miniaturizedImage);
  TEST_RELEASE(_windowTitle);
  TEST_RELEASE(_rectsBeingDrawn);
  TEST_RELEASE(_initialFirstResponder);
  TEST_RELEASE(_defaultButtonCell);
  TEST_RELEASE(_cachedImage);
  TEST_RELEASE(_toolbar);
  DESTROY(_lastView);
  DESTROY(_lastDragView);
  RELEASE(_screen);

  /*
   * FIXME This should not be necessary - the views should have removed
   * their drag types, so we should already have been removed.
   */
  [GSServerForWindow(self) removeDragTypes: nil fromWindow: self];

  [self _terminateBackendWindow];

  if (_delegate != nil)
    {
      [nc removeObserver: _delegate  name: nil  object: self];
      _delegate = nil;
    }

  [super dealloc];
}

- (void) _initBackendWindow
{
  int screenNumber;
  NSCountedSet *dragTypes;
  NSGraphicsContext *context = GSCurrentContext();
  GSDisplayServer *srv = GSCurrentServer();

  /* If we were deferred or one shot, our drag types may not have
     been registered properly in the backend. Remove them then re-add
     them when we create the window */
  dragTypes = [srv dragTypesForWindow: self];
  if (dragTypes)
    {
      // As this is the original entry, it will change soon. 
      // We use a copy to reregister the same types later on.
      dragTypes = [dragTypes copy];

      /* Now we need to remove all the drag types for this window.  */
      [srv removeDragTypes: nil  fromWindow: self];
    }

  screenNumber = [_screen screenNumber];

  _windowNum =
    [srv window: _frame
	       : _backingType
	       : _styleMask
	       : screenNumber];
  [srv setwindowlevel: [self level] : _windowNum];
  NSMapInsert (windowmaps, (void*)_windowNum, self);

  // Set window in new _gstate
  DPSgsave(context);
  [srv windowdevice: _windowNum];
  _gstate = GSDefineGState(context);
  DPSgrestore(context);

  if (NSIsEmptyRect([_wv frame]))
    {
      NSRect frame = _frame;
      frame.origin = NSZeroPoint;
      [_wv setFrame: frame];
    }
  [_wv setNeedsDisplay: YES];

  /* Ok, now add the drag types back */
  if (dragTypes)
    {
      id type;
      NSMutableArray *dragTypesArray = [NSMutableArray array];
      NSEnumerator *enumerator = [dragTypes objectEnumerator];

      NSDebugLLog(@"NSWindow", @"Resetting drag types for window");
      /* Now we need to restore the drag types.  */
      
      /* Put all the drag types to the dragTypesArray - counted
       * with their multiplicity.
       */
      while ((type = [enumerator nextObject]) != nil)
	{
	  int i, count = [dragTypes countForObject: type];
	  
	  for (i = 0; i < count; i++)
	    {
	      [dragTypesArray addObject: type];
	    }
	}
      
      /* Now store the array.  */
      [srv addDragTypes: dragTypesArray toWindow: self];
      // Free our local copy.
      RELEASE(dragTypes);
    }

  /* Other stuff we need to do for deferred windows */
  if (!NSEqualSizes(_minimumSize, NSZeroSize))
    [self setMinSize: _minimumSize];
  if (!NSEqualSizes(_maximumSize, NSZeroSize))
    [self setMaxSize: _maximumSize];
  if (!NSEqualSizes(_increments, NSZeroSize))
    [self setResizeIncrements: _increments];

  [_wv setWindowNumber: _windowNum];

  NSDebugLLog(@"NSWindow", @"Created NSWindow window frame %@",
	      NSStringFromRect(_frame));
}

/*
 * Initializing and getting a new NSWindow object
 */
/**
  <p> Initializes the receiver with a content rect of
  <var>contentRect</var>, a style mask of <var>styleMask</var>, and a
  backing store type of <var>backingType</var>.  
  </p>

  <p> The style mask values are <code>NSTitledWindowMask</code>, for a
  window with a title, <code>NSClosableWindowMask</code>, for a window
  with a close widget, <code>NSMiniaturizableWindowMask</code>, for a
  window with a miniaturize widget, and
  <code>NSResizableWindowMask</code>, for a window with a resizing
  widget.  These mask values can be OR'd in any combination.  
  </p>
 
  <p> Backing store values are <code>NSBackingStoreBuffered</code>,
  <code>NSBackingStoreRetained</code> and
  <code>NSBackingStoreNonretained</code>.  
  </p> 
*/
- (id) initWithContentRect: (NSRect)contentRect
		 styleMask: (unsigned int)aStyle
		   backing: (NSBackingStoreType)bufferingType
		     defer: (BOOL)flag
{
  return [self initWithContentRect: contentRect
			 styleMask: aStyle
			   backing: bufferingType
			     defer: flag
			    screen: nil];
}

/**
  <p> Initializes the receiver with a content rect of
  <var>contentRect</var>, a style mask of <var>styleMask</var>, a
  backing store type of <var>backingType</var> and a boolean
  <var>flag</var>.  <var>flag</var> specifies whether the window
  should be created now (<code>NO</code>), or when it is displayed
  (<code>YES</code>).  
  </p>

  <p> The style mask values are <code>NSTitledWindowMask</code>, for a
  window with a title, <code>NSClosableWindowMask</code>, for a window
  with a close widget, <code>NSMiniaturizableWindowMask</code>, for a
  window with a miniaturize widget, and
  <code>NSResizableWindowMask</code>, for a window with a resizing
  widget.  These mask values can be OR'd in any combination.  
  </p>

  <p> Backing store values are <code>NSBackingStoreBuffered</code>,
  <code>NSBackingStoreRetained</code> and
  <code>NSBackingStoreNonretained</code>.  
  </p> 
*/
- (id) initWithContentRect: (NSRect)contentRect
		 styleMask: (unsigned int)aStyle
		   backing: (NSBackingStoreType)bufferingType
		     defer: (BOOL)flag
		    screen: (NSScreen*)aScreen
{
  NSRect  cframe;

  if (!NSApp)
    NSLog(@"No application!\n");

  NSDebugLLog(@"NSWindow", @"NSWindow start of init\n");
  if (!windowmaps)
    windowmaps = NSCreateMapTable(NSIntMapKeyCallBacks,
				 NSNonRetainedObjectMapValueCallBacks, 20);

  if (!windowDecorator)
    windowDecorator = [GSWindowDecorationView windowDecorator];

  /* Initialize attributes and flags */
  [super init];
  [self _initDefaults];

  _backingType = bufferingType;
  _styleMask = aStyle;
  if (aScreen == nil)
    aScreen = [NSScreen mainScreen];
  ASSIGN(_screen, aScreen);
  _depthLimit = [_screen depth];
  
  _frame = [NSWindow frameRectForContentRect: contentRect styleMask: aStyle];
  _minimumSize = NSMakeSize(_frame.size.width - contentRect.size.width + 1,
			    _frame.size.height - contentRect.size.height + 1);
  _maximumSize = NSMakeSize (10e4, 10e4);

  [self setNextResponder: NSApp];

  _f.cursor_rects_enabled = YES;
  _f.cursor_rects_valid = NO;

  /* Create the window view */
  cframe.origin = NSZeroPoint;
  cframe.size = _frame.size;
  _wv = [windowDecorator newWindowDecorationViewWithFrame: cframe
						   window: self];
  [_wv viewWillMoveToWindow: self];

  /* Create the content view */
  cframe.origin = NSZeroPoint;
  cframe.size = contentRect.size;
  [self setContentView: AUTORELEASE([[NSView alloc] initWithFrame: cframe])];

  /* rectBeingDrawn is variable used to optimize flushing the backing store.
     It is set by NSGraphicsContext during a lockFocus to tell NSWindow what
     part a view is drawing in, so NSWindow only has to flush that portion */
  _rectsBeingDrawn = RETAIN([NSMutableArray arrayWithCapacity: 10]);

  /* Create window (if not deferred) */
  _windowNum = 0;
  _gstate = 0;
  if (flag == NO)
    {
      NSDebugLLog(@"NSWindow", @"Creating NSWindow\n");
      [self _initBackendWindow];
    }
  else
    NSDebugLLog(@"NSWindow", @"Deferring NSWindow creation\n");

  [nc addObserver: self
	 selector: @selector(colorListChanged:)
	     name: NSColorListChangedNotification
	   object: nil];

  NSDebugLLog(@"NSWindow", @"NSWindow end of init\n");
  return self;
}

-(void) colorListChanged:(NSNotification*)notif
{
  if ([[notif object] isEqual: [NSColorList colorListNamed:@"System"]])
    {
      [_wv setNeedsDisplay:YES];
    }
}

/*
 * Accessing the content view
 */
- (id) contentView
{
  return _contentView;
}

/**
  Sets the window's content view to <var>aView</var>, replacing any
  previous content view.  */
- (void) setContentView: (NSView*)aView
{
  if (aView == nil)
    {
      aView = AUTORELEASE([[NSView alloc]
	initWithFrame:
	  [NSWindow contentRectForFrameRect: _frame
				  styleMask: _styleMask]]);
    }
  if (_contentView != nil)
    {
      [_contentView removeFromSuperview];
    }
  _contentView = aView;

  [_wv setContentView: _contentView];

  [_contentView setNextResponder: self];
}

/*
 * Window graphics
 */
- (NSColor*) backgroundColor
{
  return _backgroundColor;
}

- (NSString*) representedFilename
{
  return _representedFilename;
}

- (void) setBackgroundColor: (NSColor*)color
{
  ASSIGN(_backgroundColor, color);
}

- (void) setRepresentedFilename: (NSString*)aString
{
  ASSIGN(_representedFilename, aString);
}

/** Sets the window's title to the string <var>aString</var>. */
- (void) setTitle: (NSString*)aString
{
  if ([_windowTitle isEqual: aString] == NO)
    {
      ASSIGNCOPY(_windowTitle, aString);
      [self setMiniwindowTitle: _windowTitle];
      [_wv setTitle: _windowTitle];
      if (_f.menu_exclude == NO && _f.has_opened == YES)
	{
	  [NSApp changeWindowsItem: self
			     title: _windowTitle
			  filename: NO];
	}
    }
}

- (void) setTitleWithRepresentedFilename: (NSString*)aString
{
  [self setRepresentedFilename: aString];
  aString = [NSString stringWithFormat:
    @"%@  --  %@", [aString lastPathComponent],
    [aString stringByDeletingLastPathComponent]];
  if ([_windowTitle isEqual: aString] == NO)
    {
      ASSIGNCOPY(_windowTitle, aString);
      [self setMiniwindowTitle: _windowTitle];
      [_wv setTitle: _windowTitle];
      if (_f.menu_exclude == NO && _f.has_opened == YES)
	{
	  [NSApp changeWindowsItem: self
			     title: _windowTitle
			  filename: YES];
	}
    }
}

- (unsigned int) styleMask
{
  return _styleMask;
}

/** Returns an NSString containing the text of the window's title. */
- (NSString*) title
{
  return _windowTitle;
}

- (void) setHasShadow: (BOOL)hasShadow
{
  // FIXME: Should be send to backend
  _f.has_shadow = hasShadow;
}

- (BOOL) hasShadow
{
  return _f.has_shadow;
}

- (void) setAlphaValue: (float)windowAlpha
{
  // FIXME
  _alphaValue = windowAlpha;
}

- (float) alphaValue
{
  return _alphaValue;
}

- (void) setOpaque: (BOOL)isOpaque
{
  // FIXME
  _f.is_opaque = isOpaque;
}

- (BOOL) isOpaque
{
  return _f.is_opaque;
}

/*
 * Window device attributes
 */
- (NSBackingStoreType) backingType
{
  return _backingType;
}

- (NSDictionary*) deviceDescription
{
  return [[self screen] deviceDescription];
}

- (int) gState
{
  if (_gstate <= 0)
    NSDebugLLog(@"NSWindow", @"gState called on deferred window");
  return _gstate;
}

- (BOOL) isOneShot
{
  return _f.is_one_shot;
}

- (void) setBackingType: (NSBackingStoreType)type
{
  _backingType = type;
}

- (void) setOneShot: (BOOL)flag
{
  _f.is_one_shot = flag;
}

- (int) windowNumber
{
  if (_windowNum <= 0)
    NSDebugLLog(@"NSWindow", @"windowNumber called on deferred window");
  return _windowNum;
}

/*
 * The miniwindow
 */
- (NSImage*) miniwindowImage
{
  return _miniaturizedImage;
}

- (NSString*) miniwindowTitle
{
  return _miniaturizedTitle;
}

- (void) setMiniwindowImage: (NSImage*)image
{
  ASSIGN(_miniaturizedImage, image);
  if (_counterpart != 0 && (_styleMask & NSMiniWindowMask) == 0)
    {
      NSMiniWindow	*mini = [NSApp windowWithWindowNumber: _counterpart];
      id		v = [mini contentView];

      if ([v respondsToSelector: @selector(setImage:)])
	{
	  [v setImage: [self miniwindowImage]];
	}
    }
}

- (void) setMiniwindowTitle: (NSString*)title
{
  ASSIGN(_miniaturizedTitle, title);
  if (_counterpart != 0 && (_styleMask & NSMiniWindowMask) == 0)
    {
      NSMiniWindow	*mini = [NSApp windowWithWindowNumber: _counterpart];
      id		v = [mini contentView];

      if ([v respondsToSelector: @selector(setTitle:)])
	{
	  [v setTitle: [self miniwindowTitle]];
	}
    }
}

- (NSWindow*) counterpart
{
  if (_counterpart == 0)
    return nil;
  return [NSApp windowWithWindowNumber: _counterpart];
}

/*
 * The field editor
 */
- (void) endEditingFor: (id)anObject
{
  NSText *t = [self fieldEditor: NO
		    forObject: anObject];

  if (t && (_firstResponder == t))
    {
      [nc postNotificationName: NSTextDidEndEditingNotification
	  object: t];
      [t setText: @""];
      [t setDelegate: nil];
      [t removeFromSuperview];
      _firstResponder = self;
      [_firstResponder becomeFirstResponder];
    }
}

- (NSText*) fieldEditor: (BOOL)createFlag forObject: (id)anObject
{
  /* ask delegate if it can provide a field editor */
  if ((_delegate != anObject) 
    && [_delegate respondsToSelector:
    @selector(windowWillReturnFieldEditor:toObject:)]) 
    {
      NSText *editor;
      
      editor = [_delegate windowWillReturnFieldEditor: self   
					     toObject: anObject];
      
      if (editor != nil)
	{
	  return editor;
	}
    }
  /*
   * Each window has a global text field editor, if it doesn't exist create it
   * if create flag is set
   */
  if (!_fieldEditor && createFlag)
    {
      _fieldEditor = [NSText new];
      [_fieldEditor setFieldEditor: YES];
    }

  return _fieldEditor;
}

/*
 * Window controller
 */
- (void) setWindowController: (NSWindowController*)windowController
{
  /* The window controller owns us, we only keep a weak reference to
     it */
  _windowController = windowController;
}

- (id) windowController
{
  return _windowController;
}

/*
 * Window status and ordering
 */
- (void) becomeKeyWindow
{
  if (_f.is_key == NO)
    {
      _f.is_key = YES;

      if ((!_firstResponder) || (_firstResponder == self))
	{
	  if (_initialFirstResponder)
	    {
	      [self makeFirstResponder: _initialFirstResponder];
	    }
	}

      [_firstResponder becomeFirstResponder];
      if ((_firstResponder != self)
	  && [_firstResponder respondsToSelector: @selector(becomeKeyWindow)])
	{
	  [_firstResponder becomeKeyWindow];
	}

      [_wv setInputState: GSTitleBarKey];
      [GSServerForWindow(self) setinputfocus: _windowNum];
      [self resetCursorRects];
      [nc postNotificationName: NSWindowDidBecomeKeyNotification object: self];
      NSDebugLLog(@"NSWindow", @"%@ is now key window", [self title]);
    }
}

- (void) becomeMainWindow
{
  if (_f.is_main == NO)
    {
      _f.is_main = YES;
      if (_f.is_key == NO)
	{
	  [_wv setInputState: GSTitleBarMain];
	}
      [nc postNotificationName: NSWindowDidBecomeMainNotification object: self];
      NSDebugLLog(@"NSWindow", @"%@ is now main window", [self title]);
    }
}

/** Returns YES if the receiver can be made key. If this method returns
    NO, the window will not be made key. This implementation returns YES
    if the window is resizable or has a title bar. You can override this
    method to change it's behavior */
- (BOOL) canBecomeKeyWindow
{
  if ((NSResizableWindowMask | NSTitledWindowMask) & _styleMask)
    return YES;
  else
    return NO;
}

/** Returns YES if the receiver can be the main window. If this method
    returns NO, the window will not become the main window. This
    implementation returns YES if the window is resizable or has a
    title bar and is visible and is not an NSPanel. You can override
    this method to change it's behavior */
- (BOOL) canBecomeMainWindow
{
  if (!_f.visible)
    return NO;
  if ((NSResizableWindowMask | NSTitledWindowMask) & _styleMask)
    return YES;
  else
    return NO;
}

- (BOOL) hidesOnDeactivate
{
  return _f.hides_on_deactivate;
}

- (void) setCanHide: (BOOL)flag
{
  _f.can_hide = flag;
}

- (BOOL) canHide
{
  return _f.can_hide;
}

- (BOOL) isKeyWindow
{
  return _f.is_key;
}

- (BOOL) isMainWindow
{
  return _f.is_main;
}

- (BOOL) isMiniaturized
{
  return _f.is_miniaturized;
}

- (BOOL) isVisible
{
  return _f.visible;
}

- (int) level
{
  return _windowLevel;
}

- (void) makeKeyAndOrderFront: (id)sender
{
  [self orderFront: sender];
  [self makeKeyWindow];
  /*
   * OPENSTEP makes a window the main window when it makes it the key window.
   * So we do the same (though the documentation doesn't mention it).
   */
  [self makeMainWindow];
}

- (void) makeKeyWindow
{
  if (!_f.visible || _f.is_miniaturized || _f.is_key == YES)
    {
      return;
    }
  if (![self canBecomeKeyWindow])
    return;
  [[NSApp keyWindow] resignKeyWindow];

  [self becomeKeyWindow];
}

- (void) makeMainWindow
{
  if (!_f.visible || _f.is_miniaturized || _f.is_main == YES)
    {
      return;
    }
  if (![self canBecomeMainWindow])
    return;
  [[NSApp mainWindow] resignMainWindow];
  [self becomeMainWindow];
}

/**
  Orders the window to the back of its level. Equivalent to
  -orderWindow: NSWindowBelow relativeTo: 0.
*/
- (void) orderBack: (id)sender
{
  [self orderWindow: NSWindowBelow relativeTo: 0];
}

/**
  If the application is active, orders the window to the front in its
  level. If the application is not active, the window is ordered in as
  far forward as possible in its level without being ordered in front
  of the key or main window of the currently active app. The current key
  and main window status is not changed. Equivalent to -orderWindow:
  NSWindowAbove relativeTo: 0.
*/
- (void) orderFront: (id)sender
{
  [self orderWindow: NSWindowAbove relativeTo: 0];
}

/**
  Orders the window to the front in its level (even in front of the
  key and main windows of the current app) regardless of whether the
  app is current or not. This method should only be used in rare cases
  where the app is cooperating with another app that is displaying
  data for it.  The current key and main window status is not changed.
*/
- (void) orderFrontRegardless
{
  [self orderWindow: NSWindowAbove relativeTo: -1];
}

/**
  Orders the window out from the screen. Equivalent to -orderWindow:
  NSWindowOut relativeTo: 0.
*/
- (void) orderOut: (id)sender
{
  [self orderWindow: NSWindowOut relativeTo: 0];
}

/**
  <p> 
  If place is NSWindowOut, removes the window from the screen. If
  place is NSWindowAbove, places the window directly above otherWin,
  or directly above all windows in its level if otherWin is 0.  If
  place is NSWindowBelow, places the window directly below otherWin,
  or directly below all windows in its level if otherWin is 0.
  </p>
  <p>
  If place is NSWindowAbove or NSWindowBelow and the application is
  hidden, the application is unhidden.
  <p>
*/
/*
  As a special undocumented case (for -orderFrontRegardless), if otherWin
  is negative, then the backend should not try to keep the window below the
  current key/main window
*/
- (void) orderWindow: (NSWindowOrderingMode)place relativeTo: (int)otherWin
{
  GSDisplayServer *srv = GSServerForWindow(self);
  BOOL display = NO;

  if (place == NSWindowOut)
    {
      _f.visible = NO;
      /*
       * Don't keep trying to update the window while it is ordered out
       */
      [isa _removeAutodisplayedWindow: self];
      [self _lossOfKeyOrMainWindow];
    }
  else
    {
      /* Windows need to be constrained when displayed or resized - but only
	 titled windows are constrained. Also, and this is the tricky part,
         don't constrain if we are merely unhidding the window or if it's
         already visible and is just being reordered. */
      if ((_styleMask & NSTitledWindowMask)
	  && [NSApp isHidden] == NO
	  && _f.visible == NO)
	{
	  NSRect nframe = [self constrainFrameRect: _frame
				          toScreen: [self screen]];
	  if (_windowNum)
	    [self setFrame: nframe display: NO];
	  else
	    _frame = nframe;
	}
      // create deferred window
      if (_windowNum == 0)
	{
	  [self _initBackendWindow];
	  display = YES;
	}
    }

  // Draw content before backend window ordering
  if (display)
    [_wv display];
  else if (place != NSWindowOut)
    [_wv displayIfNeeded];

  /* The backend will keep us below the current key window unless we
     force it not too */
  if ((otherWin == 0 
       || otherWin == [[NSApp keyWindow] windowNumber] 
       || otherWin == [[NSApp mainWindow] windowNumber])
      && [NSApp isActive])
    otherWin = -1;
    
  [srv orderwindow: place : otherWin : _windowNum];
  if (display)
    [self display];

  if (place != NSWindowOut)
    {
      /*
       * Once we are ordered back in, we will want to update the window
       * whenever there is anything to do.
       */
      [isa _addAutodisplayedWindow: self];

      if (_f.has_closed == YES)
	{
	  _f.has_closed = NO;	/* A closed window has re-opened	*/
	}
      if (_f.has_opened == NO)
	{
	  _f.has_opened = YES;
	  if (_f.menu_exclude == NO)
	    {
	      BOOL	isFileName;

	      isFileName = [_windowTitle isEqual: _representedFilename];

	      [NSApp addWindowsItem: self
			      title: _windowTitle
			   filename: isFileName];
	    }
	}
      if ([self isKeyWindow] == YES)
	{
	  [_wv setInputState: GSTitleBarKey];
	  [srv setinputfocus: _windowNum];
	}
      _f.visible = YES;
    }
  else if ([self isOneShot])
    {
      [self _terminateBackendWindow];
    }
}

- (void) resignKeyWindow
{
  if (_f.is_key == YES)
    {
      if ((_firstResponder != self)
	&& [_firstResponder respondsToSelector: @selector(resignKeyWindow)])
	[_firstResponder resignKeyWindow];

      _f.is_key = NO;

      if (_f.is_main == YES)
	{
	  [_wv setInputState: GSTitleBarMain];
	}
      else
	{
	  [_wv setInputState: GSTitleBarNormal];
	}
      [self discardCursorRects];

      [nc postNotificationName: NSWindowDidResignKeyNotification object: self];
    }
}

- (void) resignMainWindow
{
  if (_f.is_main == YES)
    {
      _f.is_main = NO;
      if (_f.is_key == YES)
	{
	  [_wv setInputState: GSTitleBarKey];
	}
      else
	{
	  [_wv setInputState: GSTitleBarNormal];
	}
      [nc postNotificationName: NSWindowDidResignMainNotification object: self];
    }
}

- (void) setHidesOnDeactivate: (BOOL)flag
{
  if (flag != _f.hides_on_deactivate)
    {
      _f.hides_on_deactivate = flag;
    }
}

- (void) setLevel: (int)newLevel
{
  if (_windowLevel != newLevel)
    {
      _windowLevel = newLevel;
      if (_windowNum > 0)
	{
	  GSDisplayServer *srv = GSServerForWindow(self);
	  [srv setwindowlevel: _windowLevel : _windowNum];
	}
    }
}

/*
 * Moving and resizing the window
 */
- (NSPoint) cascadeTopLeftFromPoint: (NSPoint)topLeftPoint
{
  // FIXME: As we know nothing about the other window we can only guess
  topLeftPoint.x += 20;
  topLeftPoint.y += 20;

  [self setFrameTopLeftPoint: topLeftPoint];
  return topLeftPoint;
}

- (BOOL) showsResizeIndicator
{
  // TODO
  NSLog(@"Method %s is not implemented for class %s",
	"showsResizeIndicator", "NSWindow");
  return YES;
}

- (void) setShowsResizeIndicator: (BOOL)show
{
  // TODO
  NSLog(@"Method %s is not implemented for class %s",
	"setShowsResizeIndicator:", "NSWindow");
}

- (void) setFrame: (NSRect)frameRect
	  display: (BOOL)displayFlag
	  animate: (BOOL)animationFlag
{
  // TODO
  [self setFrame: frameRect display: displayFlag];
}

- (NSTimeInterval) animationResizeTime: (NSRect)newFrame
{
  // TODO
  NSLog(@"Method %s is not implemented for class %s",
	"animationResizeTime:", "NSWindow");
  return 333;
}

- (void) center
{
  NSSize screenSize = [[self screen] frame].size;
  NSPoint origin = _frame.origin;

  origin.x = (screenSize.width - _frame.size.width) / 2;
  origin.y = (screenSize.height - _frame.size.height) / 2;

  [self setFrameOrigin: origin];
}

/**
 * Given a proposed frame rectangle, return a modified version
 * which will fit inside the screen.
 */
- (NSRect) constrainFrameRect: (NSRect)frameRect toScreen: (NSScreen*)screen
{
  NSRect screenRect = [screen frame];
  float difference;

  /* Move top edge of the window inside the screen */
  difference = NSMaxY (frameRect) - NSMaxY (screenRect);

  if (difference > 0)
    {
      frameRect.origin.y -= difference;
    }
  else if (NSMaxY (frameRect) < NSMinY (screenRect))
    {
      float diff1 = NSMinY (frameRect) - NSMinY (screenRect);
      /* move bottom inside the screen, but keep top inside screen */
      frameRect.origin.y -= MAX(difference, diff1);
      difference = NSMaxY (frameRect) - NSMaxY (screenRect);
    }

  /* If the window is resizable, resize it (if needed) so that the
     bottom edge is on the screen too */
  if (_styleMask & NSResizableWindowMask)
    {
      difference = screenRect.origin.y - frameRect.origin.y;
      if (difference > 0)
	{
	  frameRect.size.height -= difference;
	  frameRect.origin.y += difference;
	}
      /* Ensure that rewsizing doesn't makewindow smaller than minimum */
      difference = _minimumSize.height - frameRect.size.height;
      if (difference > 0)
	{
	  frameRect.size.height += difference;
	  frameRect.origin.y -= difference;
	}
    }

  return frameRect;
}

- (NSRect) frame
{
  return _frame;
}

- (NSSize) minSize
{
  return _minimumSize;
}

- (NSSize) maxSize
{
  return _maximumSize;
}

- (void) setContentSize: (NSSize)aSize
{
  NSRect	r = _frame;

  r.size = aSize;
  r = [NSWindow frameRectForContentRect: r styleMask: _styleMask];
  r.origin = _frame.origin;
  [self setFrame: r display: YES];
}

- (void) setFrame: (NSRect)frameRect display: (BOOL)flag
{
  if (_maximumSize.width > 0 && frameRect.size.width > _maximumSize.width)
    {
      frameRect.size.width = _maximumSize.width;
    }
  if (_maximumSize.height > 0 && frameRect.size.height > _maximumSize.height)
    {
      frameRect.size.height = _maximumSize.height;
    }
  if (frameRect.size.width < _minimumSize.width)
    {
      frameRect.size.width = _minimumSize.width;
    }
  if (frameRect.size.height < _minimumSize.height)
    {
      frameRect.size.height = _minimumSize.height;
    }

  if (NSEqualSizes(frameRect.size, _frame.size) == NO)
    {
      /* Windows need to be constrained when displayed or resized - but only
	 titled windows are constrained */
      if (_styleMask & NSTitledWindowMask)
	{
	  frameRect = [self constrainFrameRect: frameRect 
			              toScreen: [self screen]];
	}

      if ([_delegate respondsToSelector: @selector(windowWillResize:toSize:)])
	{
	  frameRect.size = [_delegate windowWillResize: self
						toSize: frameRect.size];
	}
    }

  // If nothing changes, don't send it to the backend and don't redisplay 
  if (NSEqualRects(_frame, frameRect))
    return;

  if (NSEqualPoints(_frame.origin, frameRect.origin) == NO)
    [nc postNotificationName: NSWindowWillMoveNotification object: self];

  /*
   * Now we can tell the graphics context to do the actual resizing.
   * We will recieve an event to tell us when the resize is done.
   */
  if (_windowNum)
    [GSServerForWindow(self) placewindow: frameRect : _windowNum];
  else
    {
      _frame = frameRect;
      frameRect.origin = NSZeroPoint;
      [_wv setFrame: frameRect];
    }

  if (flag)
    [self display];
}

- (void) setFrameOrigin: (NSPoint)aPoint
{
  NSRect	r = _frame;

  r.origin = aPoint;
  [self setFrame: r display: NO];
}

- (void) setFrameTopLeftPoint: (NSPoint)aPoint
{
  NSRect	r = _frame;

  r.origin = aPoint;
  r.origin.y -= _frame.size.height;
  [self setFrame: r display: NO];
}

- (void) setMinSize: (NSSize)aSize
{
  if (aSize.width < 1)
    aSize.width = 1;
  if (aSize.height < 1)
    aSize.height = 1;
  _minimumSize = aSize;
  if (_windowNum > 0)
    [GSServerForWindow(self) setminsize: aSize : _windowNum];
}

- (void) setMaxSize: (NSSize)aSize
{
  /*
   * Documented maximum size for macOS-X - do we need this restriction?
   */
  if (aSize.width > 10000)
    aSize.width = 10000;
  if (aSize.height > 10000)
    aSize.height = 10000;
  _maximumSize = aSize;
  if (_windowNum > 0)
    [GSServerForWindow(self) setmaxsize: aSize : _windowNum];
}

- (NSSize) resizeIncrements
{
  return _increments;
}

- (void) setResizeIncrements: (NSSize)aSize
{
  _increments = aSize;
  if (_windowNum > 0)
    [GSServerForWindow(self) setresizeincrements: aSize : _windowNum];
}

- (NSSize) aspectRatio
{
  // FIXME: This method is missing
  return NSMakeSize(1, 1); 
}

- (void) setAspectRatio: (NSSize)ratio
{
  // FIXME: This method is missing
}

/**
 * Convert from a point in the base coordinate system for the window
 * to a point in the screen coordinate system.
 */
- (NSPoint) convertBaseToScreen: (NSPoint)aPoint
{
  NSPoint screenPoint;
  screenPoint.x = _frame.origin.x + aPoint.x;
  screenPoint.y = _frame.origin.y + aPoint.y;
  return screenPoint;
}

/**
 * Convert from a point in the screen coordinate system to a point in the
 * screen coordinate system of the receiver.
 */
- (NSPoint) convertScreenToBase: (NSPoint)aPoint
{
  NSPoint basePoint;
  basePoint.x = aPoint.x - _frame.origin.x;
  basePoint.y = aPoint.y - _frame.origin.y;
  return basePoint;
}

/*
 * Managing the display
 */
- (void) disableFlushWindow
{
  _disableFlushWindow++;
}

- (void) display
{
  if (_gstate == 0 || _f.visible == NO)
    return;

  _rFlags.needs_display = NO;
  
  [_wv display];
  [self discardCachedImage];
}

- (void) displayIfNeeded
{
  if (_rFlags.needs_display)
    {
      [_wv displayIfNeeded];
      _rFlags.needs_display = NO;
    }
}

- (void) update
{
  [nc postNotificationName: NSWindowDidUpdateNotification object: self];
}

- (void) flushWindowIfNeeded
{
  if (_disableFlushWindow == 0 && _f.needs_flush == YES)
    {
      [self flushWindow];
    }
}

/**
 * Flush all drawing in the windows buffer to the screen unless the window
 * is not buffered or flushing is not enabled.
 */
- (void) flushWindow
{
  int			i;

  /*
   * If flushWindow is called while flush is disabled
   * mark self as needing a flush, then return
   */
  if (_disableFlushWindow)
    {
      _f.needs_flush = YES;
      return;
    }

  /*
   * Just flush graphics if backing is not buffered.
   * The documentation actually says that this is wrong ... the method
   * should do nothing when the backingType is NSBackingStoreNonretained
   */
  if (_backingType == NSBackingStoreNonretained)
    {
      NSGraphicsContext	*context = GSCurrentContext();

      [context flushGraphics];
      return;
    }

  /* Check for special case of flushing while we are lock focused.
     For instance, when we are highlighting a button. */
  if (NSIsEmptyRect(_rectNeedingFlush))
    {
      if ([_rectsBeingDrawn count] == 0)
	{
	  _f.needs_flush = NO;
	  return;
	}
    }

  /*
   * Accumulate the rectangles from all nested focus locks.
   */
  i = [_rectsBeingDrawn count];
  while (i-- > 0)
    {
      _rectNeedingFlush = NSUnionRect(_rectNeedingFlush,
        [[_rectsBeingDrawn objectAtIndex: i] rectValue]);
    }

  if (_windowNum > 0)
    {
      [GSServerForWindow(self) flushwindowrect: _rectNeedingFlush
					      : _windowNum];
    }
  _f.needs_flush = NO;
  _rectNeedingFlush = NSZeroRect;
}

- (void) enableFlushWindow
{
  if (_disableFlushWindow > 0)
    {
      _disableFlushWindow--;
    }
}

- (BOOL) isAutodisplay
{
  return _f.is_autodisplay;
}

- (BOOL) isFlushWindowDisabled
{
  return _disableFlushWindow == 0 ? NO : YES;
}

- (void) setAutodisplay: (BOOL)flag
{
  _f.is_autodisplay = flag;
}

- (void) setViewsNeedDisplay: (BOOL)flag
{
  if (_rFlags.needs_display != flag)
    {
      _rFlags.needs_display = flag;
      if (flag)
	{
	  /* TODO: this call most likely shouldn't be here */
	  [NSApp setWindowsNeedUpdate: YES];
	}
    }
}

- (BOOL) viewsNeedDisplay
{
  return _rFlags.needs_display;
}

- (void) cacheImageInRect: (NSRect)aRect
{
  NSView *cacheView;
  NSRect cacheRect;
  
  aRect = NSIntegralRect (NSIntersectionRect (aRect, [_wv frame]));
  _cachedImageOrigin = aRect.origin;
  DESTROY(_cachedImage);
  
  if (NSIsEmptyRect (aRect))
    {
      return;
    }
  
  cacheRect.origin = NSZeroPoint;
  cacheRect.size = aRect.size;
  _cachedImage = [[NSCachedImageRep alloc] initWithWindow: nil 
					   rect: cacheRect];
  cacheView = [[_cachedImage window] contentView];
  [cacheView lockFocus];
  NSCopyBits (_gstate, aRect, NSZeroPoint);
  [cacheView unlockFocus];
}

- (void) discardCachedImage
{
  DESTROY(_cachedImage);
}

- (void) restoreCachedImage
{
  if (_cachedImage == nil)
    {
      return;
    }
  [_wv lockFocus];
  NSCopyBits ([[_cachedImage window] gState], 
	      [_cachedImage rect],
	      _cachedImageOrigin);
  [_wv unlockFocus];
}

- (void) useOptimizedDrawing: (BOOL)flag
{
  _f.optimize_drawing = flag;
}

- (BOOL) canStoreColor
{
  if (NSNumberOfColorComponents(NSColorSpaceFromDepth(_depthLimit)) > 1)
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

/** Returns the screen the window is on. Unlike (apparently) OpenStep
    and MacOSX, GNUstep does not support windows being split across
    multiple screens */
- (NSScreen *) deepestScreen
{
  return [self screen];
}

- (NSWindowDepth) depthLimit
{
  return _depthLimit;
}

- (BOOL) hasDynamicDepthLimit
{
  return _f.dynamic_depth_limit;
}

/** Returns the screen the window is on. */
- (NSScreen *) screen
{
  return _screen;
}

- (void) setDepthLimit: (NSWindowDepth)limit
{
  if (limit == 0)
    {
      limit = [isa defaultDepthLimit];
    }

  _depthLimit = limit;
}

- (void) setDynamicDepthLimit: (BOOL)flag
{
  _f.dynamic_depth_limit = flag;
}

/*
 * Cursor management
 */
- (BOOL) areCursorRectsEnabled
{
  return _f.cursor_rects_enabled;
}

- (void) disableCursorRects
{
  _f.cursor_rects_enabled = NO;
}

static void
discardCursorRectsForView(NSView *theView)
{
  if (theView != nil)
    {
      if (((NSViewPtr)theView)->_rFlags.has_currects)
	{
	  [theView discardCursorRects];
	}

      if (((NSViewPtr)theView)->_rFlags.has_subviews)
	{
	  NSArray	*s = ((NSViewPtr)theView)->_sub_views;
	  unsigned	count = [s count];

	  if (count)
	    {
	      NSView	*subs[count];
	      unsigned	i;

	      [s getObjects: subs];
	      for (i = 0; i < count; i++)
		{
		  discardCursorRectsForView(subs[i]);
		}
	    }
	}
    }
}

- (void) discardCursorRects
{
  discardCursorRectsForView(_wv);
}

- (void) enableCursorRects
{
  _f.cursor_rects_enabled = YES;
}

- (void) invalidateCursorRectsForView: (NSView*)aView
{
  if (((NSViewPtr)aView)->_rFlags.valid_rects)
    {
      [((NSViewPtr)aView)->_cursor_rects
	makeObjectsPerformSelector: @selector(invalidate)];
      ((NSViewPtr)aView)->_rFlags.valid_rects = 0;
      _f.cursor_rects_valid = NO;
    }
}

static void
resetCursorRectsForView(NSView *theView)
{
  if (theView != nil)
    {
      [theView resetCursorRects];

      if (((NSViewPtr)theView)->_rFlags.has_subviews)
	{
	  NSArray	*s = ((NSViewPtr)theView)->_sub_views;
	  unsigned	count = [s count];

	  if (count)
	    {
	      NSView	*subs[count];
	      unsigned	i;

	      [s getObjects: subs];
	      for (i = 0; i < count; i++)
		{
		  resetCursorRectsForView(subs[i]);
		}
	    }
	}
    }
}

- (void) resetCursorRects
{
  [self discardCursorRects];
  resetCursorRectsForView(_wv);
  _f.cursor_rects_valid = YES;
}

/*
 * Handling user actions and events
 */
- (void) close
{
  if (_f.has_closed == NO)
    {
      CREATE_AUTORELEASE_POOL(pool);

      /* The NSWindowCloseNotification might result in us being
         deallocated. To make sure self stays valid as long as is
         necessary, we retain ourselves here and balance it with a
         release later (unless we're supposed to release ourselves when
         we close).
      */
      if (!_f.is_released_when_closed)
	{
	  RETAIN(self);
	}

      [nc postNotificationName: NSWindowWillCloseNotification object: self];
      _f.has_opened = NO;
      [NSApp removeWindowsItem: self];
      [self orderOut: self];

      RELEASE(pool);
      
      _f.has_closed = YES;
      RELEASE(self);
    }
}

/* Private Method. Many X Window managers will just deminiaturize us without
   telling us to do it ourselves. Deal with it.
*/
- (void) _didDeminiaturize: sender
{
  _f.is_miniaturized = NO;
  [nc postNotificationName: NSWindowDidDeminiaturizeNotification object: self];
}

/**
  Causes the window to deminiaturize. Normally you would not call this
  method directly. A window is automatically deminiaturized by the
  user via a mouse click event. Does nothing it the window isn't
  miniaturized.  */
- (void) deminiaturize: sender
{
  if (!_f.is_miniaturized)
    return;

#if 0
  /* At least with X-Windows, the counterpart is tied to us, so it will
     automatically be ordered out when we are deminiaturized */
  if (_counterpart != 0)
    {
      NSWindow		*mini = GSWindowWithNumber(_counterpart);

      [mini orderOut: self];
    }
#endif
  _f.is_miniaturized = NO;
  [self makeKeyAndOrderFront: self];
  [self _didDeminiaturize: sender];
}

- (BOOL) isDocumentEdited
{
  return _f.is_edited;
}

- (BOOL) isReleasedWhenClosed
{
  return _f.is_released_when_closed;
}

/**
  Causes the window to miniaturize, that is the window is removed from
  the screen and it's counterpart (mini)window is displayed. Does
  nothing if the window can't be miniaturized (eg. because it's already
  miniaturized).  */
- (void) miniaturize: (id)sender
{
  GSDisplayServer *srv = GSServerForWindow(self);

  if (_f.is_miniaturized
      || (!(_styleMask & NSMiniaturizableWindowMask))
      || (_styleMask & (NSIconWindowMask | NSMiniWindowMask))
      || (![self isVisible]))
    return;

  [nc postNotificationName: NSWindowWillMiniaturizeNotification
		    object: self];
  
  _f.is_miniaturized = YES;
  /* Make sure we're not defered */
  if (_windowNum == 0)
    {
      [self _initBackendWindow];
    }
  /*
   * Ensure that we have a miniwindow counterpart.
   */
  if (_counterpart == 0 && [srv appOwnsMiniwindow])
    {
      NSWindow		*mini;
      NSMiniWindowView	*v;
      
      mini = [[NSMiniWindow alloc] initWithContentRect: NSMakeRect(0,0,64,64)
					     styleMask: NSMiniWindowMask
					       backing: NSBackingStoreBuffered
						 defer: NO];
      mini->_counterpart = [self windowNumber];
      _counterpart = [mini windowNumber];
      v = [[NSMiniWindowView alloc] initWithFrame: NSMakeRect(0,0,64,64)];
      [v setImage: [self miniwindowImage]];
      [v setTitle: [self miniwindowTitle]];
      [mini setContentView: v];
      RELEASE(v);
    }
  [self _lossOfKeyOrMainWindow];
  [srv miniwindow: _windowNum];
  _f.visible = NO;
  
  /*
   * We must order the miniwindow in so that we will start sending
   * it messages to tell it to display itsself when neccessary.
   */
  if (_counterpart != 0)
    {
      NSWindow	*mini = GSWindowWithNumber(_counterpart);

      [mini orderFront: self];
    }
  [nc postNotificationName: NSWindowDidMiniaturizeNotification
		    object: self];
}

- (void) performClose: (id)sender
{
  /* Don't close if a modal session is running and we are not the
     modal window */
  if ([NSApp modalWindow] && self != [NSApp modalWindow])
    return;

  /* self must have a close button in order to be closed */
  if (!(_styleMask & NSClosableWindowMask))
    {
      NSBeep();
      return;
    }

  if (_windowController)
    {
      NSDocument *document = [_windowController document];

      if (document && ![document shouldCloseWindowController: _windowController])
        {
          NSBeep();
          return;
        }
    }
  if ([_delegate respondsToSelector: @selector(windowShouldClose:)])
    {
      /*
       *	if delegate responds to windowShouldClose query it to see if
       *	it's ok to close the window
       */
      if (![_delegate windowShouldClose: self])
	{
	  NSBeep();
	  return;
	}
    }
  else
    {
      /*
       *	else if self responds to windowShouldClose query
       *	self to see if it's ok to close self
       */
      if ([self respondsToSelector: @selector(windowShouldClose:)])
	{
	  if (![self windowShouldClose: self])
	    {
	      NSBeep();
	      return;
	    }
	}
    }

  // FIXME: The button should be highlighted
  [self close];
}

- (BOOL) performKeyEquivalent: (NSEvent*)theEvent
{
  if (_contentView)
    return [_contentView performKeyEquivalent: theEvent];
  return NO;
}

/**
 * Miniaturize the receiver ... as long as its style mask includes
 * NSMiniaturizableWindowMask (and as long as the receiver is not an
 * icon or mini window itsself). Calls -miniaturize: to do this.<br />
 * Beeps if the window can't be miniaturised.<br />
 * Should ideally provide visual feedback (highlighting the miniaturize
 * button as if it had been clicked) first ... but that's not yet implemented.
 */
- (void) performMiniaturize: (id)sender
{
  if ((!(_styleMask & NSMiniaturizableWindowMask))
    || (_styleMask & (NSIconWindowMask | NSMiniWindowMask)))
    {
      NSBeep();
      return;
    }

  // FIXME: The button should be highlighted
  [self miniaturize: sender];
}

- (int) resizeFlags
{
  // FIXME: The implementation is missing
  return 0;
}

- (void) setDocumentEdited: (BOOL)flag
{
  if (_f.is_edited != flag)
    {
      _f.is_edited = flag;
      if (_f.menu_exclude == NO && _f.has_opened == YES)
	{
	  [NSApp updateWindowsItem: self];
	}
      [_wv setDocumentEdited: flag];
    }
}

- (void) setReleasedWhenClosed: (BOOL)flag
{
  _f.is_released_when_closed = flag;
}

/*
 * Aiding event handling
 */
- (BOOL) acceptsMouseMovedEvents
{
  return _f.accepts_mouse_moved;
}

- (NSEvent*) currentEvent
{
  return [NSApp currentEvent];
}

- (void) discardEventsMatchingMask: (unsigned int)mask
		       beforeEvent: (NSEvent*)lastEvent
{
  [NSApp discardEventsMatchingMask: mask beforeEvent: lastEvent];
}

- (NSResponder*) firstResponder
{
  return _firstResponder;
}

- (BOOL) acceptsFirstResponder
{
  return YES;
}

- (BOOL) makeFirstResponder: (NSResponder*)aResponder
{
  if (_firstResponder == aResponder)
    return YES;

  if (![aResponder isKindOfClass: responderClass])
    return NO;

  if (![aResponder acceptsFirstResponder])
    return NO;

  /* So that the implementation of -resignFirstResponder in
     _firstResponder might ask for what will be the new first
     responder by calling our method _futureFirstResponder */
  _futureFirstResponder = aResponder;

  /*
   * If there is a first responder tell it to resign.
   * Change only if it replies YES.
   */
  if ((_firstResponder) && (![_firstResponder resignFirstResponder]))
    return NO;

  _firstResponder = aResponder;
  if (![_firstResponder becomeFirstResponder])
    {
      _firstResponder = self;
      [_firstResponder becomeFirstResponder];
      return NO;
    }

  return YES;
}

- (void) setInitialFirstResponder: (NSView*)aView
{
  if ([aView isKindOfClass: viewClass])
    {
      ASSIGN(_initialFirstResponder, aView);
    }
}

- (NSView*) initialFirstResponder
{
  return _initialFirstResponder;
}

- (void) keyDown: (NSEvent*)theEvent
{
  NSString	*characters = [theEvent characters];
  unichar	character = 0;

  if ([characters length] > 0)
    {
      character = [characters characterAtIndex: 0];
    }

  // If this is a TAB or TAB+SHIFT event, move to the next key view
  if (character == NSTabCharacter)
    {
      if ([theEvent modifierFlags] & NSShiftKeyMask)
	[self selectPreviousKeyView: self];
      else
	[self selectNextKeyView: self];
      return;
    }

  // If this is an ESC event, abort modal loop
  if (character == 0x001b)
    {
      if ([NSApp modalWindow] == self)
	{
	  // NB: The following *never* returns.
	  [NSApp abortModal];
	}
      return;
    }

  if (character == NSEnterCharacter
    || character == NSFormFeedCharacter
    || character == NSCarriageReturnCharacter)
    {
      if (_defaultButtonCell && _f.default_button_cell_key_disabled == NO)
	{
	  [_defaultButtonCell performClick: self];
	  return;
	}
    }

  // Discard null character events such as a Shift event after a tab key
  if ([characters length] == 0)
    return;

  // Try to process the event as a key equivalent
  // without Command having being pressed
  {
    NSEvent *new_event
      =  [NSEvent keyEventWithType: [theEvent type]
		  location: NSZeroPoint
		  modifierFlags: ([theEvent modifierFlags] | NSCommandKeyMask)
		  timestamp: [theEvent timestamp]
		  windowNumber: [theEvent windowNumber]
		  context: [theEvent context]
		  characters: characters
		  charactersIgnoringModifiers: [theEvent
						 charactersIgnoringModifiers]
		  isARepeat: [theEvent isARepeat]
		  keyCode: [theEvent keyCode]];
    if ([self performKeyEquivalent: new_event])
      return;
  }

  // Otherwise, pass the event up
  [super keyDown: theEvent];
}

/* Return mouse location in reciever's base coord system, ignores event
 * loop status */
- (NSPoint) mouseLocationOutsideOfEventStream
{
  int screen;
  NSPoint	p;

  screen = [_screen screenNumber];
  p = [GSServerForWindow(self) mouseLocationOnScreen: screen window: NULL];
  if (p.x != -1)
    p = [self convertScreenToBase: p];
  return p;
}

- (NSEvent*) nextEventMatchingMask: (unsigned int)mask
{
  return [NSApp nextEventMatchingMask: mask
			    untilDate: nil
			       inMode: NSEventTrackingRunLoopMode
			      dequeue: YES];
}

- (NSEvent*) nextEventMatchingMask: (unsigned int)mask
			 untilDate: (NSDate*)expiration
			    inMode: (NSString*)mode
			   dequeue: (BOOL)deqFlag
{
  return [NSApp nextEventMatchingMask: mask
			    untilDate: expiration
			       inMode: mode
			      dequeue: deqFlag];
}

- (void) postEvent: (NSEvent*)event atStart: (BOOL)flag
{
  [NSApp postEvent: event atStart: flag];
}

- (void) setAcceptsMouseMovedEvents: (BOOL)flag
{
  _f.accepts_mouse_moved = flag;
}

- (void) _checkTrackingRectangles: (NSView*)theView
			 forEvent: (NSEvent*)theEvent
{
  if (((NSViewPtr)theView)->_rFlags.has_trkrects)
    {
      NSArray	*tr = ((NSViewPtr)theView)->_tracking_rects;
      unsigned	count = [tr count];

      /*
       * Loop through the tracking rectangles
       */
      if (count > 0)
	{
	  GSTrackingRect	*rects[count];
	  NSPoint		loc = [theEvent locationInWindow];
	  unsigned		i;

	  [tr getObjects: rects];

	  for (i = 0; i < count; ++i)
	    {
	      BOOL		last;
	      BOOL		now;
	      GSTrackingRect	*r = rects[i];

	      /* Check mouse at last point */
	      last = NSMouseInRect(_lastPoint, r->rectangle, NO);
	      /* Check mouse at current point */
	      now = NSMouseInRect(loc, r->rectangle, NO);

	      if ((!last) && (now))		// Mouse entered event
		{
		  if (r->flags.checked == NO)
		    {
		      if ([r->owner respondsToSelector:
			@selector(mouseEntered:)])
			r->flags.ownerRespondsToMouseEntered = YES;
		      if ([r->owner respondsToSelector:
			@selector(mouseExited:)])
			r->flags.ownerRespondsToMouseExited = YES;
		      r->flags.checked = YES;
		    }
		  if (r->flags.ownerRespondsToMouseEntered)
		    {
		      NSEvent	*e;

		      e = [NSEvent enterExitEventWithType: NSMouseEntered
			location: loc
			modifierFlags: [theEvent modifierFlags]
			timestamp: 0
			windowNumber: [theEvent windowNumber]
			context: NULL
			eventNumber: 0
			trackingNumber: r->tag
			userData: r->user_data];
		      [r->owner mouseEntered: e];
		    }
		}
		
	      if ((last) && (!now))		// Mouse exited event
		{
		  if (r->flags.checked == NO)
		    {    
		      if ([r->owner respondsToSelector:
			@selector(mouseEntered:)])
			r->flags.ownerRespondsToMouseEntered = YES;
		      if ([r->owner respondsToSelector:
			@selector(mouseExited:)])
			r->flags.ownerRespondsToMouseExited = YES;
		      r->flags.checked = YES;
		    }
		  if (r->flags.ownerRespondsToMouseExited)
		    {
		      NSEvent	*e;

		      e = [NSEvent enterExitEventWithType: NSMouseExited
			location: loc
			modifierFlags: [theEvent modifierFlags]
			timestamp: 0
			windowNumber: [theEvent windowNumber]
			context: NULL
			eventNumber: 0
			trackingNumber: r->tag
			userData: r->user_data];
		      [r->owner mouseExited: e];
		    }
		}
	    }
	}
    }

  /*
   * Check tracking rectangles for the subviews
   */
  if (((NSViewPtr)theView)->_rFlags.has_subviews)
    {
      NSArray	*sb = ((NSViewPtr)theView)->_sub_views;
      unsigned	count = [sb count];

      if (count > 0)
	{
	  NSView	*subs[count];
	  unsigned	i;

	  [sb getObjects: subs];
	  for (i = 0; i < count; ++i)
	    (*ctImp)(self, ctSel, subs[i], theEvent);
	}
    }
}

- (void) _checkCursorRectangles: (NSView*)theView forEvent: (NSEvent*)theEvent
{
  if (((NSViewPtr)theView)->_rFlags.valid_rects)
    {
      NSArray	*tr = ((NSViewPtr)theView)->_cursor_rects;
      unsigned	count = [tr count];

      // Loop through cursor rectangles
      if (count > 0)
	{
	  GSTrackingRect	*rects[count];
	  NSPoint		loc = [theEvent locationInWindow];
	  unsigned		i;

	  [tr getObjects: rects];

	  for (i = 0; i < count; ++i)
	    {
	      GSTrackingRect	*r = rects[i];
	      BOOL		last;
	      BOOL		now;

	      if ([r isValid] == NO)
		continue;

	      /*
	       * Check for presence of point in rectangle.
	       */
	      last = NSMouseInRect(_lastPoint, r->rectangle, NO);
	      now = NSMouseInRect(loc, r->rectangle, NO);

	      // Mouse entered
	      if ((!last) && (now))
		{
		  NSEvent	*e;

		  e = [NSEvent enterExitEventWithType: NSCursorUpdate
		    location: loc
		    modifierFlags: [theEvent modifierFlags]
		    timestamp: 0
		    windowNumber: [theEvent windowNumber]
		    context: [theEvent context]
		    eventNumber: 0
		    trackingNumber: (int)YES
		    userData: (void*)r];
		  [self postEvent: e atStart: YES];
		}
	      // Mouse exited
	      if ((last) && (!now))
		{
		  NSEvent	*e;

		  e = [NSEvent enterExitEventWithType: NSCursorUpdate
		    location: loc
		    modifierFlags: [theEvent modifierFlags]
		    timestamp: 0
		    windowNumber: [theEvent windowNumber]
		    context: [theEvent context]
		    eventNumber: 0
		    trackingNumber: (int)NO
		    userData: (void*)r];
		  [self postEvent: e atStart: YES];
		}
	    }
	}
    }

  /*
   * Check cursor rectangles for the subviews
   */
  if (((NSViewPtr)theView)->_rFlags.has_subviews)
    {
      NSArray	*sb = ((NSViewPtr)theView)->_sub_views;
      unsigned	count = [sb count];

      if (count > 0)
	{
	  NSView	*subs[count];
	  unsigned	i;

	  [sb getObjects: subs];
	  for (i = 0; i < count; ++i)
	    (*ccImp)(self, ccSel, subs[i], theEvent);
	}
    }
}

- (void) _processResizeEvent
{
  if (_windowNum && _gstate)
    {
      NSGraphicsContext	*context = GSCurrentContext();
      DPSgsave(context);
      DPSsetgstate(context, _gstate);
      [GSServerForWindow(self) windowdevice: _windowNum];
      GSReplaceGState(context, _gstate);
      DPSgrestore(context);
    }

  [self update];
}

- (void) mouseDown: (NSEvent*)theEvent
{
  // Quietly discard an unused mouse down.
}

/** Handles mouse and other events sent to the receiver by NSApplication.
    Do not invoke this method directly.
*/
- (void) _sendEvent: (NSEvent*)theEvent
	becomesKeyOnlyIfNeeded: (BOOL)becomesKeyOnlyIfNeeded
{
  NSView	*v;
  NSEventType	type;

  /*
  If the backend reacts slowly, events (eg. mouse down) might arrive for a
  window that has been ordered out (and thus is logically invisible). We
  need to ignore those events. Otherwise, eg. clicking twice on a button
  that ends a modal session and closes the window with the button might
  cause the button to be pressed twice, which causes Bad Things to happen
  when it tries to stop a modal session twice.

  We let NSAppKitDefined events through since they deal with window ordering.
  */
  if (!_f.visible && [theEvent type] != NSAppKitDefined)
    return;

  if (!_f.cursor_rects_valid)
    {
      [self resetCursorRects];
    }

  type = [theEvent type];
  switch (type)
    {
      case NSLeftMouseDown:
	{
	  BOOL	wasKey = _f.is_key;

	  if (_f.has_closed == NO)
	    {
	      v = [_wv hitTest: [theEvent locationInWindow]];
	      if (_f.is_key == NO && _windowLevel != NSDesktopWindowLevel)
		{
		  /* NSPanel modification: check becomesKeyOnlyIfNeeded. */
		  if (!becomesKeyOnlyIfNeeded || [v needsPanelToBecomeKey])
		    [self makeKeyAndOrderFront: self];
		}
	      /* Activate the app *after* making the receiver key, as app
		 activation tries to make the previous key window key. */
	      if ([NSApp isActive] == NO && self != [NSApp iconWindow])
		{
		  [NSApp activateIgnoringOtherApps: YES];
		}
	      if (_firstResponder != v)
		{
		  [self makeFirstResponder: v];
		}
	      if (_lastView)
 		{
		  DESTROY(_lastView);
		}
	      if (wasKey == YES || [v acceptsFirstMouse: theEvent] == YES)
		{
		  if ([NSHelpManager isContextHelpModeActive])
		    {
		      [v helpRequested: theEvent];
		    }
		  else
		    {
		      ASSIGN(_lastView, v);
		      [v mouseDown: theEvent];
		    }
		}
	      else
		{
		  [self mouseDown: theEvent];
		}
	    }
	  _lastPoint = [theEvent locationInWindow];
	  break;
	}

      case NSLeftMouseUp:
	v = AUTORELEASE(RETAIN(_lastView));
	DESTROY(_lastView);
	if (v == nil)
	  break;
	[v mouseUp: theEvent];
	_lastPoint = [theEvent locationInWindow];
	break;

      case NSOtherMouseDown:
	v = [_wv hitTest: [theEvent locationInWindow]];
	[v otherMouseDown: theEvent];
	_lastPoint = [theEvent locationInWindow];
	break;

      case NSOtherMouseUp:
	v = [_wv hitTest: [theEvent locationInWindow]];
	[v otherMouseUp: theEvent];
	_lastPoint = [theEvent locationInWindow];
	break;

      case NSRightMouseDown:
	{
	  v = [_wv hitTest: [theEvent locationInWindow]];
	  [v rightMouseDown: theEvent];
	  _lastPoint = [theEvent locationInWindow];
	}
	break;

      case NSRightMouseUp:
	v = [_wv hitTest: [theEvent locationInWindow]];
	[v rightMouseUp: theEvent];
	_lastPoint = [theEvent locationInWindow];
	break;

      case NSLeftMouseDragged:
      case NSOtherMouseDragged:
      case NSRightMouseDragged:
      case NSMouseMoved:
	switch (type)
	  {
	    case NSLeftMouseDragged:
	      v = [_wv hitTest: [theEvent locationInWindow]];
	      [v mouseDragged: theEvent];
	      break;
	    case NSOtherMouseDragged:
	      v = [_wv hitTest: [theEvent locationInWindow]];
	      [v otherMouseDragged: theEvent];
	      break;
	    case NSRightMouseDragged:
	      v = [_wv hitTest: [theEvent locationInWindow]];
	      [v rightMouseDragged: theEvent];
	      break;
	    default:
	      if (_f.accepts_mouse_moved)
		{
		  /*
		   * If the window is set to accept mouse movements, we need to
		   * forward the mouse movement to the correct view.
		   */
		  v = [_wv hitTest: [theEvent locationInWindow]];
		  [v mouseMoved: theEvent];
		}
	      break;
	  }

	/*
	 * We need to go through all of the views, and if there is any with
	 * a tracking rectangle then we need to determine if we should send
	 * a NSMouseEntered or NSMouseExited event.
	 */
	(*ctImp)(self, ctSel, _wv, theEvent);

	if (_f.is_key)
	  {
	    /*
	     * We need to go through all of the views, and if there is any with
	     * a cursor rectangle then we need to determine if we should send a
	     * cursor update event.
	     */
	    if (_f.cursor_rects_enabled)
	      (*ccImp)(self, ccSel, _wv, theEvent);
	  }

	_lastPoint = [theEvent locationInWindow];
	break;

      case NSMouseEntered:
      case NSMouseExited:
	break;

      case NSKeyDown:
	[_firstResponder keyDown: theEvent];
	break;

      case NSKeyUp:
	[_firstResponder keyUp: theEvent];
	break;

      case NSFlagsChanged:
	[_firstResponder flagsChanged: theEvent];
	break;

      case NSCursorUpdate:
	{
	  GSTrackingRect	*r =(GSTrackingRect*)[theEvent userData];
	  NSCursor		*c = (NSCursor*)[r owner];

	  if ([theEvent trackingNumber])	  // It's a mouse entered
	    {
	      [c mouseEntered: theEvent];
	    }
	  else					  // it is a mouse exited
	    {
	      [c mouseExited: theEvent];
	    }
	}
	break;

      case NSScrollWheel:
  	v = [_wv hitTest: [theEvent locationInWindow]];
	[v scrollWheel: theEvent];
	break;

      case NSAppKitDefined:
	{
	  id                    dragInfo;
	  int                   action;
	  NSEvent               *e;
	  GSAppKitSubtype	sub = [theEvent subtype];

	  switch (sub)
	    {
	    case GSAppKitWindowMoved:
	      _frame.origin.x = (float)[theEvent data1];
	      _frame.origin.y = (float)[theEvent data2];
	      NSDebugLLog(@"Moving", @"Move event: %d %@",
			  _windowNum, NSStringFromPoint(_frame.origin));
	      if (_autosaveName != nil)
		{
		  [self saveFrameUsingName: _autosaveName];
		}
	      [nc postNotificationName: NSWindowDidMoveNotification
		  object: self];
	      break;
	      
	    case GSAppKitWindowResized:
	      _frame.size.width = (float)[theEvent data1];
	      _frame.size.height = (float)[theEvent data2];
	      /* Resize events always move the frame origin. The new origin
		 is stored in the event location field */
	      _frame.origin = [theEvent locationInWindow];
	      if (_autosaveName != nil)
		{
		  [self saveFrameUsingName: _autosaveName];
		}
	      {
		NSRect	rect = _frame;
		
		rect.origin = NSZeroPoint;
		[_wv setFrame: rect];
		[_wv setNeedsDisplay: YES];
	      }
	      [self _processResizeEvent];
	      [nc postNotificationName: NSWindowDidResizeNotification
		                object: self];
	      break;

	    case GSAppKitWindowClose:
	      [self performClose: NSApp];
	      break;
		
	    case GSAppKitWindowMiniaturize:
	      [self performMiniaturize: NSApp];
	      break;

	    case GSAppKitWindowFocusIn:
	      if (_f.is_miniaturized)
		{
		  /* Window Manager just deminiaturized us */
		  [self deminiaturize: self];
		}
	      if ([NSApp modalWindow]
		  && self != [NSApp modalWindow])
		{
		  /* Ignore this request. We're in a modal loop and the
		     user pressed on the title bar of another window. */
		  break;
		}
	      if ([self canBecomeKeyWindow] == YES)
		{
		  NSDebugLLog(@"Focus", @"Making %d key", _windowNum);
		  [self makeKeyWindow];
		  [self makeMainWindow];
		  [NSApp activateIgnoringOtherApps: YES];
		}
	      if (self == [[NSApp mainMenu] window])
		{
		  /* We should really find another window that can become
		     key (if possible)
		  */
		  [self _lossOfKeyOrMainWindow];
		}
	      break;

	    case GSAppKitWindowFocusOut:
	      break;

	    case GSAppKitWindowLeave:
	      /*
	       * We need to go through all of the views, and if there
	       * is any with a tracking rectangle then we need to
	       * determine if we should send a NSMouseExited event.  */
	      (*ctImp)(self, ctSel, _wv, theEvent);

	      if (_f.is_key)
		{
		  /*
		   * We need to go through all of the views, and if
		   * there is any with a cursor rectangle then we need
		   * to determine if we should send a cursor update
		   * event.  */
		  if (_f.cursor_rects_enabled)
		    (*ccImp)(self, ccSel, _wv, theEvent);
		}
	      
	      _lastPoint = NSMakePoint(-1, -1);
	      break;

	    case GSAppKitWindowEnter:
	      break;


#define     GSPerformDragSelector(view, sel, info, action) \
	      if ([view window] == self) \
		{ \
		  id target = view; \
		  \
		  if (target == _wv) \
		    { \
		      if (_delegate != nil \
			&& [_delegate respondsToSelector: sel] == YES) \
			{ \
			  target = _delegate; \
			} \
		      else \
			{ \
			  target = self; \
			} \
		    } \
		  \
		  if ([target respondsToSelector: sel]) \
		    { \
		      action = (int)[target performSelector: sel \
						 withObject: info];   \
		    } \
                }

#define     GSPerformVoidDragSelector(view, sel, info) \
	      if ([view window] == self) \
                {  \
		  id target = view; \
		  \
		  if (target == _wv) \
		    { \
		      if (_delegate != nil \
			&& [_delegate respondsToSelector: sel] == YES) \
			{ \
			  target = _delegate; \
			} \
		      else \
			{ \
			  target = self; \
			} \
		    } \
		  \
		  if ([target respondsToSelector: sel]) \
		    { \
		      [target performSelector: sel withObject: info];   \
		    } \
                }

	    case GSAppKitDraggingEnter:
	    case GSAppKitDraggingUpdate:
	    {
	      BOOL	isEntry;

	      v = [_wv hitTest: [theEvent locationInWindow]];
	      while (v != nil && ((NSViewPtr)v)->_rFlags.has_draginfo == 0)
		{
		  v = [v superview];
		}
	      if (v == nil)
		{
		  v = _wv;
		}
	      dragInfo = [GSServerForWindow(self) dragInfo];
	      if (_lastDragView == v)
		{
		  isEntry = NO;
		}
	      else
		{
		  isEntry = YES;
		  if (_lastDragView != nil && _f.accepts_drag)
		    {
		      NSDebugLLog(@"NSDragging", @"Dragging exit");
		      GSPerformVoidDragSelector(_lastDragView,
			@selector(draggingExited:), dragInfo);
		    }
		  ASSIGN(_lastDragView, v);
		  _f.accepts_drag = GSViewAcceptsDrag(v, dragInfo);
		  action = NSDragOperationNone;
		}
              if (_f.accepts_drag)
                {
                  if (isEntry == YES)
                    {
                      action = NSDragOperationNone;
		      NSDebugLLog(@"NSDragging", @"Dragging entered");
                      GSPerformDragSelector(v, @selector(draggingEntered:),
			dragInfo, action);
                    }
                  else  
                    {
                      action = _lastDragOperationMask;
		      NSDebugLLog(@"NSDragging", @"Dragging updated");
                      GSPerformDragSelector(v, @selector(draggingUpdated:),
                                            dragInfo, action);
                    }
                }
              else
                {
                  action = NSDragOperationNone;
                }

              e = [NSEvent otherEventWithType: NSAppKitDefined
                           location: [theEvent locationInWindow]
                           modifierFlags: 0
                           timestamp: 0
                           windowNumber: _windowNum
                           context: GSCurrentContext()
                           subtype: GSAppKitDraggingStatus
                           data1: [theEvent data1]
                           data2: action];

              _lastDragOperationMask = action;
              [dragInfo postDragEvent: e];
	      break;
	    }

	    case GSAppKitDraggingStatus:
	      NSDebugLLog(@"NSDragging",
		@"Internal: dropped GSAppKitDraggingStatus event");
	      break;

	    case GSAppKitDraggingExit:
	      NSDebugLLog(@"NSDragging", @"GSAppKitDraggingExit");
	      dragInfo = [GSServerForWindow(self) dragInfo];
	      if (_lastDragView && _f.accepts_drag)
		{
		  NSDebugLLog(@"NSDragging", @"Dragging exit");
		  GSPerformVoidDragSelector(_lastDragView,
		    @selector(draggingExited:), dragInfo);
		}
              _lastDragOperationMask = NSDragOperationNone;
	      DESTROY(_lastDragView);
	      break;

	    case GSAppKitDraggingDrop:
	      NSDebugLLog(@"NSDragging", @"GSAppKitDraggingDrop");
	      dragInfo = [GSServerForWindow(self) dragInfo];
	      if (_lastDragView && _f.accepts_drag)
		{
                  action = NO;
                  GSPerformDragSelector(_lastDragView,
		    @selector(prepareForDragOperation:), dragInfo, action);
		  if (action)
		    {
                      action = NO;
		      GSPerformDragSelector(_lastDragView,
			@selector(performDragOperation:), dragInfo, action);
		    }
		  if (action)
		    {
		      GSPerformVoidDragSelector(_lastDragView,
			@selector(concludeDragOperation:), dragInfo);
		    }
		}
              _lastDragOperationMask = NSDragOperationNone;
	      DESTROY(_lastDragView);
	      e = [NSEvent otherEventWithType: NSAppKitDefined
			   location: [theEvent locationInWindow]
			   modifierFlags: 0
			   timestamp: 0
			   windowNumber: _windowNum
			   context: GSCurrentContext()
			   subtype: GSAppKitDraggingFinished
			   data1: [theEvent data1]
			   data2: 0];
	      [dragInfo postDragEvent: e];
	      break;

	    case GSAppKitDraggingFinished:
              _lastDragOperationMask = NSDragOperationNone;
	      DESTROY(_lastDragView);
	      NSDebugLLog(@"NSDragging",
		@"Internal: dropped GSAppKitDraggingFinished event");
	      break;

	    default:
	      break;
	    }
	}
	break;

      case NSPeriodic:
      case NSSystemDefined:
      case NSApplicationDefined:
	break;
    }
}

/** Handles mouse and other events sent to the receiver by NSApplication.
    Do not invoke this method directly.
*/
- (void) sendEvent: (NSEvent*)theEvent
{
  [self _sendEvent: theEvent
    becomesKeyOnlyIfNeeded: NO];
}


- (BOOL) tryToPerform: (SEL)anAction with: (id)anObject
{
  if ([super tryToPerform: anAction with: anObject])
    return YES;
  else if (_delegate && [_delegate respondsToSelector: anAction])
    {
      [_delegate performSelector: anAction withObject: anObject];
      return YES;
    }
  else
    return NO;
}

- (BOOL) worksWhenModal
{
  return NO;
}

- (void) selectKeyViewFollowingView: (NSView*)aView
{
  NSView *theView = nil;

  if ([aView isKindOfClass: viewClass])
    theView = [aView nextValidKeyView];
  if (theView)
    {
      [self makeFirstResponder: theView];
      if ([theView respondsToSelector:@selector(selectText:)])
	{
	  _selectionDirection =  NSSelectingNext;
	  [(id)theView selectText: self];
	  _selectionDirection =  NSDirectSelection;
      	}
    }
}

- (void) selectKeyViewPrecedingView: (NSView*)aView
{
  NSView *theView = nil;

  if ([aView isKindOfClass: viewClass])
    theView = [aView previousValidKeyView];
  if (theView)
    {
      [self makeFirstResponder: theView];
      if ([theView respondsToSelector:@selector(selectText:)])
	{
	  _selectionDirection =  NSSelectingPrevious;
	  [(id)theView selectText: self];
	  _selectionDirection =  NSDirectSelection;
	}
    }
}

- (void) selectNextKeyView: (id)sender
{
  NSView *theView = nil;

  if ([_firstResponder isKindOfClass: viewClass])
    theView = [_firstResponder nextValidKeyView];

  if ((theView == nil) && (_initialFirstResponder))
    {
      if ([_initialFirstResponder acceptsFirstResponder])
	theView = _initialFirstResponder;
      else
	theView = [_initialFirstResponder nextValidKeyView];
    }

  if (theView)
    {
      [self makeFirstResponder: theView];
      if ([theView respondsToSelector:@selector(selectText:)])
	{
	  _selectionDirection =  NSSelectingNext;
	  [(id)theView selectText: self];
	  _selectionDirection =  NSDirectSelection;
	}
    }
}

- (void) selectPreviousKeyView: (id)sender
{
  NSView *theView = nil;

  if ([_firstResponder isKindOfClass: viewClass])
    theView = [_firstResponder previousValidKeyView];

  if ((theView == nil) && (_initialFirstResponder))
    {
      if ([_initialFirstResponder acceptsFirstResponder])
	theView = _initialFirstResponder;
      else
	theView = [_initialFirstResponder previousValidKeyView];
    }

  if (theView)
    {
      [self makeFirstResponder: theView];
      if ([theView respondsToSelector:@selector(selectText:)])
	{
	  _selectionDirection =  NSSelectingPrevious;
	  [(id)theView selectText: self];
	  _selectionDirection =  NSDirectSelection;
	}
    }
}

// This is invoked by selectText: of some views (eg matrixes),
// to know whether they have received it from the window, and
// if so, in which direction is the selection moving (so that they know
// if they should select the last or the first editable cell).
- (NSSelectionDirection) keyViewSelectionDirection
{
  return _selectionDirection;
}

/*
 * Dragging
 */
- (void) dragImage: (NSImage*)anImage
	        at: (NSPoint)baseLocation
	    offset: (NSSize)initialOffset
	     event: (NSEvent*)event
        pasteboard: (NSPasteboard*)pboard
	    source: (id)sourceObject
	 slideBack: (BOOL)slideFlag
{
  id dragView = [GSServerForWindow(self) dragInfo];

  [NSApp preventWindowOrdering];
  [dragView dragImage: anImage
		   at: [self convertBaseToScreen: baseLocation]
	       offset: initialOffset
		event: event
	   pasteboard: pboard
	       source: sourceObject
	    slideBack: slideFlag];
}

- (void) registerForDraggedTypes: (NSArray*)newTypes
{
  [_wv registerForDraggedTypes: newTypes];
}

- (void) unregisterDraggedTypes
{
  [_wv unregisterDraggedTypes];
}

/*
 * Services and windows menu support
 */
- (BOOL) isExcludedFromWindowsMenu
{
  return _f.menu_exclude;
}

- (void) setExcludedFromWindowsMenu: (BOOL)flag
{
  if (_f.menu_exclude != flag)
    {
      _f.menu_exclude = flag;
      if (_f.has_opened == YES)
	{
	  if (_f.menu_exclude == NO)
	    {
	      BOOL	isFileName;

	      isFileName = [_windowTitle isEqual: _representedFilename];

	      [NSApp addWindowsItem: self
			      title: _windowTitle
			   filename: isFileName];
	    }
	  else
	    {
	      [NSApp removeWindowsItem: self];
	    }
	}
    }
}

- (id) validRequestorForSendType: (NSString*)sendType
		      returnType: (NSString*)returnType
{
  id result = nil;

  // FIXME: We should not forward this method if the delegate is a NSResponder
  if (_delegate && [_delegate respondsToSelector: _cmd])
    result = [_delegate validRequestorForSendType: sendType
				      returnType: returnType];

  if (result == nil)
    result = [NSApp validRequestorForSendType: sendType
				   returnType: returnType];
  return result;
}

/*
 * Saving and restoring the frame
 */
- (NSString*) frameAutosaveName
{
  return _autosaveName;
}

- (void) saveFrameUsingName: (NSString*)name
{
  NSUserDefaults	*defs;
  NSString		*key;
  id			obj;

  defs = [NSUserDefaults standardUserDefaults];
  obj = [self stringWithSavedFrame];
  key = [NSString stringWithFormat: @"NSWindow Frame %@", name];
  [defs setObject: obj forKey: key];
}

- (BOOL) setFrameAutosaveName: (NSString*)name
{
  if ([name isEqual: _autosaveName])
    {
      return YES;		/* That's our name already.	*/
    }

  if ([autosaveNames member: name] != nil)
    {
      return NO;		/* Name in use elsewhere.	*/
    }
  if (_autosaveName != nil)
    {
      [[self class] removeFrameUsingName: _autosaveName];
      [autosaveNames removeObject: _autosaveName];
      _autosaveName = nil;
    }
  if (name != nil && [name isEqual: @""] == NO)
    {
      name = [name copy];
      [autosaveNames addObject: name];
      _autosaveName = name;
      RELEASE(name);
      if (![self setFrameUsingName: _autosaveName])
        {
          [self saveFrameUsingName: _autosaveName];
        }
    }
  return YES;
}

- (void) setFrameFromString: (NSString*)string
{
  NSScanner	*scanner = [NSScanner scannerWithString: string];
  NSRect	nRect;
  NSRect	sRect;
  NSRect	fRect;
  int		value;

  /*
   * Scan in the window frame (flipped coordinate system).
   */
  if ([scanner scanInt: &value] == NO)
    {
      NSLog(@"Bad window frame format - x-coord missing");
      return;
    }
  fRect.origin.x = value;

  if ([scanner scanInt: &value] == NO)
    {
      NSLog(@"Bad window frame format - y-coord missing");
      return;
    }
  fRect.origin.y = value;

  if ([scanner scanInt: &value] == NO)
    {
      NSLog(@"Bad window frame format - width missing");
      return;
    }
  fRect.size.width = value;

  if ([scanner scanInt: &value] == NO)
    {
      NSLog(@"Bad window frame format - height missing");
      return;
    }
  fRect.size.height = value;

  /*
   * Scan in the frame for the area the window was placed in in screen.
   */
  if ([scanner scanInt: &value] == NO)
    {
      NSLog(@"Bad screen frame format - x-coord missing");
      return;
    }
  sRect.origin.x = value;

  if ([scanner scanInt: &value] == NO)
    {
      NSLog(@"Bad screen frame format - y-coord missing");
      return;
    }
  sRect.origin.y = value;

  if ([scanner scanInt: &value] == NO)
    {
      NSLog(@"Bad screen frame format - width missing");
      return;
    }
  sRect.size.width = value;

  if ([scanner scanInt: &value] == NO)
    {
      NSLog(@"Bad screen frame format - height missing");
      return;
    }
  sRect.size.height = value;

  /*
   * The screen rectangle gives the area of the screen in which
   * the window could be placed (ie a rectangle excluding the dock).
   */
  nRect = [[self screen] visibleFrame];

  /*
   * If the new screen drawable area has moved relative to the one in
   * which the window was saved, adjust the window position accordingly.
   */
  if (NSEqualPoints(nRect.origin, sRect.origin) == NO)
    {
      fRect.origin.x += nRect.origin.x - sRect.origin.x;
      fRect.origin.y += nRect.origin.y - sRect.origin.y;
    }

  /*
   * If the stored screen area is not the same as that currently
   * available, we adjust the window frame (position) to try to
   * make layout sensible.
   */
  if (nRect.size.width != sRect.size.width)
    {
      fRect.origin.x = nRect.origin.x + (fRect.origin.x - nRect.origin.x)
	* (nRect.size.width / sRect.size.width);
    }
  if (nRect.size.height != sRect.size.height)
    {
      fRect.origin.y = nRect.origin.y + (fRect.origin.y - nRect.origin.y)
	* (nRect.size.height / sRect.size.height);
    }

  /*
   * Set frame.
   */
  [self setFrame: fRect display: (_f.visible) ? YES : NO];
}

- (BOOL) setFrameUsingName: (NSString*)name
{
  NSUserDefaults	*defs;
  id			obj;
  NSString		*key;

  defs = [NSUserDefaults standardUserDefaults];
  key = [NSString stringWithFormat: @"NSWindow Frame %@", name];
  obj = [defs objectForKey: key];
  if (obj == nil)
    return NO;
  [self setFrameFromString: obj];
  return YES;
}

- (BOOL) setFrameUsingName: (NSString *)name
		    force: (BOOL)force
{
  // FIXME
  return [self setFrameUsingName: name];
}

- (NSString *) stringWithSavedFrame
{
  NSRect	fRect;
  NSRect	sRect;

  fRect = _frame;

  /*
   * The screen rectangle should gives the area of the screen in which
   * the window could be placed (ie a rectangle excluding the dock).
   */
  sRect = [[self screen] visibleFrame];

  return [NSString stringWithFormat: @"%d %d %d %d %d %d % d %d ",
    (int)fRect.origin.x, (int)fRect.origin.y,
    (int)fRect.size.width, (int)fRect.size.height,
    (int)sRect.origin.x, (int)sRect.origin.y,
    (int)sRect.size.width, (int)sRect.size.height];
}

/*
 * Printing and postscript
 */
- (NSData *) dataWithEPSInsideRect: (NSRect)rect
{
  return [_wv dataWithEPSInsideRect:
			   [_wv convertRect: rect fromView: nil]];
}

- (NSData *)dataWithPDFInsideRect:(NSRect)aRect
{
  return [_wv dataWithPDFInsideRect:
			   [_wv convertRect: aRect fromView: nil]];
}

- (void) fax: (id)sender
{
  [_wv fax: sender];
}

- (void) print: (id)sender
{
  [_wv print: sender];
}

/*
 * Zooming
 */

- (BOOL) isZoomed
{
  // FIXME: Method is missing  
  return NO;
}

- (void) performZoom: (id)sender
{
  // FIXME: We should check for the style and highlight the button
  [self zoom: sender];
}

#define DIST 3

- (void) zoom: (id)sender
{
  NSRect maxRect = [[self screen] visibleFrame];

  if ([_delegate respondsToSelector: @selector(windowWillUseStandardFrame:defaultFrame:)])
    {
      maxRect = [_delegate windowWillUseStandardFrame: self defaultFrame: maxRect];
    }
  else if ([self respondsToSelector: @selector(windowWillUseStandardFrame:defaultFrame:)])
    {
      maxRect = [self windowWillUseStandardFrame: self defaultFrame: maxRect];
    }

  maxRect = [self constrainFrameRect: maxRect toScreen: [self screen]];

  // Compare the new frame with the current one
  if ((abs(NSMaxX(maxRect) - NSMaxX(_frame)) < DIST) &&
      (abs(NSMaxY(maxRect) - NSMaxY(_frame)) < DIST) &&
      (abs(NSMinX(maxRect) - NSMinX(_frame)) < DIST) &&
      (abs(NSMinY(maxRect) - NSMinY(_frame)) < DIST))
    {
      // Already in zoomed mode, reset user frame, if stored
      if (_autosaveName != nil)
        {
	  [self setFrameUsingName: _autosaveName];
	}
      return;
    }

  if ([_delegate respondsToSelector: @selector(windowShouldZoom:toFrame:)])
    {
      if (![_delegate windowShouldZoom: self toFrame: maxRect])
	return;
    }
  else if ([self respondsToSelector: @selector(windowShouldZoom:toFrame:)])
    {
      if (![self windowShouldZoom: self toFrame: maxRect])
	return;
    }

  if (_autosaveName != nil)
    {
      [self saveFrameUsingName: _autosaveName];
    }
  
  [self setFrame: maxRect display: YES];
}


/*
 * Default botton
 */

- (NSButtonCell *) defaultButtonCell
{
  return _defaultButtonCell;
}

- (void) setDefaultButtonCell: (NSButtonCell *)aCell
{
  ASSIGN(_defaultButtonCell, aCell);
  _f.default_button_cell_key_disabled = NO;

  [aCell setKeyEquivalent: @"\r"];
  [aCell setKeyEquivalentModifierMask: 0];
}

- (void) disableKeyEquivalentForDefaultButtonCell
{
  _f.default_button_cell_key_disabled = YES;
}

- (void) enableKeyEquivalentForDefaultButtonCell
{
  _f.default_button_cell_key_disabled = NO;
}

/*
 * Assigning a delegate
 */
- (id) delegate
{
  return _delegate;
}

- (void) setDelegate: (id)anObject
{
  if (_delegate)
    {
      [nc removeObserver: _delegate name: nil object: self];
    }
  _delegate = anObject;

#define SET_DELEGATE_NOTIFICATION(notif_name) \
  if ([_delegate respondsToSelector: @selector(window##notif_name:)]) \
    [nc addObserver: _delegate \
      selector: @selector(window##notif_name:) \
      name: NSWindow##notif_name##Notification object: self]

  SET_DELEGATE_NOTIFICATION(DidBecomeKey);
  SET_DELEGATE_NOTIFICATION(DidBecomeMain);
  SET_DELEGATE_NOTIFICATION(DidChangeScreen);
  SET_DELEGATE_NOTIFICATION(DidDeminiaturize);
  SET_DELEGATE_NOTIFICATION(DidExpose);
  SET_DELEGATE_NOTIFICATION(DidMiniaturize);
  SET_DELEGATE_NOTIFICATION(DidMove);
  SET_DELEGATE_NOTIFICATION(DidResignKey);
  SET_DELEGATE_NOTIFICATION(DidResignMain);
  SET_DELEGATE_NOTIFICATION(DidResize);
  SET_DELEGATE_NOTIFICATION(DidUpdate);
  SET_DELEGATE_NOTIFICATION(WillClose);
  SET_DELEGATE_NOTIFICATION(WillMiniaturize);
  SET_DELEGATE_NOTIFICATION(WillMove);
}

/*
 * NSCoding protocol
 */
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  BOOL		flag;

  [super encodeWithCoder: aCoder];

  [aCoder encodeRect: [[self contentView] frame]];
  [aCoder encodeValueOfObjCType: @encode(unsigned) at: &_styleMask];
  [aCoder encodeValueOfObjCType: @encode(NSBackingStoreType) at: &_backingType];

  [aCoder encodePoint: NSMakePoint(NSMinX([self frame]), NSMaxY([self frame]))];
  [aCoder encodeObject: _contentView];
  [aCoder encodeObject: _backgroundColor];
  [aCoder encodeObject: _representedFilename];
  [aCoder encodeObject: _miniaturizedTitle];
  [aCoder encodeObject: _windowTitle];

  [aCoder encodeSize: _minimumSize];
  [aCoder encodeSize: _maximumSize];

  [aCoder encodeValueOfObjCType: @encode(int) at: &_windowLevel];

  flag = _f.menu_exclude;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _f.is_one_shot;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _f.is_autodisplay;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _f.optimize_drawing;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _f.dynamic_depth_limit;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _f.cursor_rects_enabled;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _f.is_released_when_closed;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _f.hides_on_deactivate;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _f.accepts_mouse_moved;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];

  [aCoder encodeObject: _miniaturizedImage];
  [aCoder encodeConditionalObject: _initialFirstResponder];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  id	oldself = self;
  BOOL	flag;

  if ((self = [super initWithCoder: aDecoder]) == oldself)
    {
      NSSize			aSize;
      NSRect			aRect;
      NSPoint			p;
      unsigned			aStyle;
      NSBackingStoreType	aBacking;
      int			anInt;
      id			obj;

      aRect = [aDecoder decodeRect];
      [aDecoder decodeValueOfObjCType: @encode(unsigned)
				   at: &aStyle];
      [aDecoder decodeValueOfObjCType: @encode(NSBackingStoreType)
				   at: &aBacking];

      self = [self initWithContentRect: aRect
			     styleMask: aStyle
			       backing: aBacking
				 defer: NO
				screen: nil];

      p = [aDecoder decodePoint];
      obj = [aDecoder decodeObject];
      [self setContentView: obj];
      obj = [aDecoder decodeObject];
      [self setBackgroundColor: obj];
      obj = [aDecoder decodeObject];
      [self setRepresentedFilename: obj];
      obj = [aDecoder decodeObject];
      [self setMiniwindowTitle: obj];
      obj = [aDecoder decodeObject];
      [self setTitle: obj];

      aSize = [aDecoder decodeSize];
      [self setMinSize: aSize];
      aSize = [aDecoder decodeSize];
      [self setMaxSize: aSize];

      [aDecoder decodeValueOfObjCType: @encode(int)
				   at: &anInt];
      [self setLevel: anInt];

      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      [self setExcludedFromWindowsMenu: flag];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      [self setOneShot: flag];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      [self setAutodisplay: flag];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      [self useOptimizedDrawing: flag];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      [self setDynamicDepthLimit: flag];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      if (flag)
	[self enableCursorRects];
      else
	[self disableCursorRects];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      [self setReleasedWhenClosed: flag];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      [self setHidesOnDeactivate: flag];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      [self setAcceptsMouseMovedEvents: flag];

      [aDecoder decodeValueOfObjCType: @encode(id)
				   at: &_miniaturizedImage];
      [aDecoder decodeValueOfObjCType: @encode(id)
				   at: &_initialFirstResponder];

      [self setFrameTopLeftPoint: p];
    }

  return self;
}

- (NSArray *) drawers
{
  // TODO
  NSLog(@"Method %s is not implemented for class %s",
	"drawers", "NSWindow");
  return nil;
}

- (id) initWithWindowRef: (void *)windowRef
{
  // TODO
  NSLog(@"Method %s is not implemented for class %s",
	"initWithWindowRef:", "NSWindow");
  return nil;
}

- (void *)windowRef
{
  // TODO
  NSLog(@"Method %s is not implemented for class %s",
	"windowRef", "NSWindow");
  return (void *) 0;
}

- (void *) windowHandle
{
  // Should only be defined on MS Windows
  return (void *)_windowNum;
}

@end

/*
 * GNUstep backend methods
 */
@implementation NSWindow (GNUstepBackend)

/*
 * Mouse capture/release
 */
- (void) _captureMouse: sender
{
  [GSCurrentServer() capturemouse: _windowNum];
}

- (void) _releaseMouse: sender
{
  [GSCurrentServer() releasemouse];
}

- (void) _setVisible: (BOOL)flag
{
  _f.visible = flag;
}

- (void) performDeminiaturize: sender
{
  [self deminiaturize: sender];
}

/*
 * Allow subclasses to init without the backend
 * class attempting to create an actual window
 */
- (void) _initDefaults
{
  _firstResponder = self;
  _initialFirstResponder = nil;
  _selectionDirection = NSDirectSelection;
  _delegate = nil;
  _windowNum = 0;
  _gstate = 0;
  _backgroundColor = RETAIN([NSColor windowBackgroundColor]);
  _representedFilename = @"Window";
  _miniaturizedTitle = @"Window";
  _miniaturizedImage = RETAIN([NSApp applicationIconImage]);
  _windowTitle = @"Window";
  _lastPoint = NSZeroPoint;
  _windowLevel = NSNormalWindowLevel;

  _depthLimit = NSDefaultDepth;
  _disableFlushWindow = 0;
  _alphaValue = 0.0;

  _f.is_one_shot = NO;
  _f.is_autodisplay = YES;
  _f.optimize_drawing = NO;
  _f.dynamic_depth_limit = YES;
  _f.cursor_rects_enabled = NO;
  _f.visible = NO;
  _f.is_key = NO;
  _f.is_main = NO;
  _f.is_edited = NO;
  _f.is_released_when_closed = YES;
  _f.is_miniaturized = NO;
  _f.menu_exclude = NO;
  _f.hides_on_deactivate = NO;
  _f.accepts_mouse_moved = NO;
  _f.has_opened = NO;
  _f.has_closed = NO;
  _f.can_hide = YES;
  _f.has_shadow = NO;
  _f.is_opaque = YES;

  _rFlags.needs_display = YES;
}

@end

@implementation NSWindow (GNUstepTextView)
- (id) _futureFirstResponder
{
  return _futureFirstResponder;
}
@end

BOOL GSViewAcceptsDrag(NSView *v, id<NSDraggingInfo> dragInfo)
{
  NSPasteboard *pb = [dragInfo draggingPasteboard];
  if ([pb availableTypeFromArray: GSGetDragTypes(v)])
    return YES;
  return NO;
}

void NSCountWindows(int *count)
{
  *count = (int)NSCountMapTable(windowmaps);
}

void NSWindowList(int size, int list[])
{
  NSMapEnumerator	me = NSEnumerateMapTable(windowmaps);
  int			num;
  id			win;
  int			i = 0;

  while (i < size && NSNextMapEnumeratorPair(&me, (void*)&num, (void*)&win))
    {
      list[i++] = num;
    }
/* FIXME - the list produced should be in window stacking order */
}

NSArray* GSAllWindows(void)
{
  if (windowmaps)
    return NSAllMapTableValues(windowmaps);
  return nil;
}

NSWindow* GSWindowWithNumber(int num)
{
  return (NSWindow*)NSMapGet(windowmaps, (void*)num);
}
