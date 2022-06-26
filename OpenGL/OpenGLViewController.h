/*
 
 OpenGLViewController.h
 LightProbe2VerticalCross
 
 Created by Mark Lim Pak Mun on 26/06/2022.
 Copyright © 2022 Mark Lim Pak Mun. All rights reserved.
 The code is based on Apple's MigratingOpenGLCodeToMetal.
 
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
