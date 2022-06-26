/*
 
 OpenGLRenderer.h
 LightProbe2VerticalCross
 
 Created by Mark Lim Pak Mun on 26/06/2022.
 Copyright © 2022 Mark Lim Pak Mun. All rights reserved.
 The code is based on Apple's MigratingOpenGLCodeToMetal.
 
 */


#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#import <GLKit/GLKTextureLoader.h>
#import "OpenGLHeaders.h"


@interface OpenGLRenderer : NSObject {
}

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName;

- (void)draw;

- (void)resize:(CGSize)size;

@property CGPoint mouseCoords;

@end
