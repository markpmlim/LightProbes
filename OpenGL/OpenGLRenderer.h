/*
 OpenGLRenderer.h
 LightProbe
 
 Created by Mark Lim Pak Mun on 01/07/2022.
 Copyright © 2022 Mark Lim Pak Mun. All rights reserved.

 */

#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#import <GLKit/GLKTextureLoader.h>
#import "OpenGLHeaders.h"


@interface OpenGLRenderer : NSObject {
}

- (instancetype) initWithDefaultFBOName:(GLuint)defaultFBOName;

- (void) draw;

- (void) resize:(CGSize)size;

// Give access to the view controller object so that an HDR image file can be saved
@property GLuint vertCrossmapTextureID;

@end
