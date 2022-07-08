/*
 OpenGLViewController.h
 LightProbe
 
 Created by Mark Lim Pak Mun on 01/07/2022.
 Copyright © 2022 Mark Lim Pak Mun. All rights reserved.
 
 Code based on Apple's MigratingOpenGLCodeToMetal
*/

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
@import UIKit;
#define PlatformViewBase UIView
#define PlatformViewController UIViewController
#else
@import AppKit;
#define PlatformViewBase NSOpenGLView
#define PlatformViewController NSViewController
#endif

@interface OpenGLView : PlatformViewBase

@end

@interface OpenGLViewController : PlatformViewController

@end
