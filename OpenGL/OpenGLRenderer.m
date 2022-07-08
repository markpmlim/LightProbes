/*
 OpenGLRenderer.m
 LightProbe
 
 Created by Mark Lim Pak Mun on 01/07/2022.
 Copyright © 2022 Mark Lim Pak Mun. All rights reserved.

 */

#import "OpenGLRenderer.h"
#import "AAPLMathUtilities.h"
#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <ModelIO/ModelIO.h>
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#import "stb_image_write.h"


@implementation OpenGLRenderer {
    GLuint _defaultFBOName;
    CGSize _viewSize;

    // GLSL programs.
    GLuint _vertCrossProgram;
    GLuint _angularMap2CubemapProgram;

    GLint _angularMapLoc;
    GLint _cubemapTextureLoc;

    GLint _resolutionLoc;
    GLint _mouseLoc;
    GLint _timeLoc;
    GLint _projectionMatrixLoc;

    CGSize _tex0Resolution;
    GLsizei _faceSize;

    GLuint _lightProbeTextureID;
    GLuint _cubemapTextureID;

    GLuint _cubeVAO;
    GLuint _cubeVBO;
    GLuint _triangleVAO;

    GLfloat _currentTime;

    matrix_float4x4 _projectionMatrix;
}

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName
{
    self = [super init];
    if(self) {
        NSLog(@"%s %s", glGetString(GL_RENDERER), glGetString(GL_VERSION));

        // Build all of your objects and setup initial state here.
        _defaultFBOName = defaultFBOName;
        [self buildResources];
        // Must bind or buildProgramWithVertexSourceURL:withFragmentSourceURLwill crash on validation.
        glBindVertexArray(_cubeVAO);

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *vertexSourceURL = [mainBundle URLForResource:@"CubemapVertexShader"
                                              withExtension:@"glsl"];
        NSURL *fragmentSourceURL = [mainBundle URLForResource:@"CubemapFragmentShader"
                                              withExtension:@"glsl"];
        _angularMap2CubemapProgram = [OpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                                             withFragmentSourceURL:fragmentSourceURL];
        _angularMapLoc = glGetUniformLocation(_angularMap2CubemapProgram, "angularMapImage");
        printf("%d\n", _angularMapLoc);

        _lightProbeTextureID = [self textureWithContentsOfFile:@"StPetersProbe.hdr"
                                                    resolution:&_tex0Resolution];
        //printf("%f %f\n", _tex0Resolution.width, _tex0Resolution.height);

        vertexSourceURL = [mainBundle URLForResource:@"SimpleVertexShader"
                                              withExtension:@"glsl"];
        fragmentSourceURL = [mainBundle URLForResource:@"VertCrossFragmentShader"
                                                withExtension:@"glsl"];
        _vertCrossProgram = [OpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                                   withFragmentSourceURL:fragmentSourceURL];

        printf("%u\n", _vertCrossProgram);
        _resolutionLoc = glGetUniformLocation(_vertCrossProgram, "u_resolution");
        _mouseLoc = glGetUniformLocation(_vertCrossProgram, "u_mouse");
        _timeLoc = glGetUniformLocation(_vertCrossProgram, "u_time");
        _projectionMatrixLoc = glGetUniformLocation(_vertCrossProgram, "projectionMatrix");
        _cubemapTextureLoc = glGetUniformLocation(_vertCrossProgram, "cubemapTexture");
        printf("%d %d %d\n", _resolutionLoc, _mouseLoc, _timeLoc);
        printf("%d %d\n", _projectionMatrixLoc, _cubemapTextureLoc);
        glBindVertexArray(0);
        // Required.
        glGenVertexArrays(1, &_triangleVAO);

        // Set the common size of the 6 faces of the cubemap texture here.
        _faceSize = 512;
        _cubemapTextureID = [self createCubemapTexture:_lightProbeTextureID
                                              faceSize:_faceSize];
    }

    return self;
}

- (void) dealloc {
    glDeleteProgram(_angularMap2CubemapProgram);
    glDeleteProgram(_vertCrossProgram);
    glDeleteVertexArrays(1, &_cubeVAO);
    glDeleteBuffers(1, &_cubeVBO);
    glDeleteVertexArrays(1, &_triangleVAO);
    glDeleteTextures(1, &_cubemapTextureID);
    glDeleteTextures(1, &_lightProbeTextureID);
}

- (void)resize:(CGSize)size
{
    // Handle the resize of the draw rectangle. In particular, update the perspective projection matrix
    // with a new aspect ratio because the view orientation, layout, or size has changed.
    _viewSize = size;
    float aspect = (float)size.width / size.height;
    _projectionMatrix = matrix_perspective_right_hand_gl(65.0f * (M_PI / 180.0f),
                                                         aspect,
                                                         1.0f, 5000.0);
}

/*
 All light probe images are in HDR format.
 */
- (GLuint) textureWithContentsOfFile:(NSString *)name
                          resolution:(CGSize *)size {
    GLuint textureID = 0;

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSArray<NSString *> *subStrings = [name componentsSeparatedByString:@"."];
    NSString *path = [mainBundle pathForResource:subStrings[0]
                                          ofType:subStrings[1]];

    GLint width;
    GLint height;
    GLint nrComponents;

    stbi_set_flip_vertically_on_load(true);
    GLfloat *data = stbi_loadf([path UTF8String], &width, &height, &nrComponents, 0);
    if (data) {
        size_t dataSize = width * height * nrComponents * sizeof(GLfloat);

        // Create and allocate space for a new buffer object
        GLuint pbo;
        glGenBuffers(1, &pbo);
        // Bind the newly-created buffer object to initialise it.
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo);
        // NULL means allocate GPU memory to the PBO.
        // GL_STREAM_DRAW is a hint indicating the PBO will stream a texture upload
        glBufferData(GL_PIXEL_UNPACK_BUFFER,
                     dataSize,
                     NULL,
                     GL_STREAM_DRAW);

        // The following call will return a pointer to the buffer object.
        // We are going to write data to the PBO. The call will only return when
        //  the GPU finishes its work with the buffer object.
    #ifdef TARGET_MACOS
        void* ptr = glMapBuffer(GL_PIXEL_UNPACK_BUFFER,
                                GL_WRITE_ONLY);
    #else
        void* ptr = glMapBufferRange(GL_PIXEL_UNPACK_BUFFER,
                                     0,
                                     dataSize,
                                     GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    #endif
        // Write data into the mapped buffer, possibly on another thread.
        // This should upload image's raw data to GPU
        memcpy(ptr, data, dataSize);

        // After reading is complete, back on the current thread
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo);
        // Release pointer to mapping buffer
        glUnmapBuffer(GL_PIXEL_UNPACK_BUFFER);

        glGenTextures(1, &textureID);
        glBindTexture(GL_TEXTURE_2D, textureID);
        // Read the texel data from the buffer object
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_RGB16F,
                     width, height,
                     0,
                     GL_RGB,
                     GL_FLOAT,
                     NULL);     // byte offset into the buffer object's data store

        // Unbind and delete the buffer object
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
        glDeleteBuffers(1, &pbo);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        stbi_image_free(data);
    }
    else {
        printf("Error reading hdr file\n");
        exit(1);
    }

    return textureID;
}

- (void) buildResources {

    // From LearnOpenGL.com
    // initialize (if necessary)
    if (_cubeVAO == 0)
    {
        float vertices[] = {
            // back face
            //  positions               normals       texcoords
            -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f,   // A bottom-left
            1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f,    // C top-right
            1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 0.0f,    // B bottom-right
            1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f,    // C top-right
            -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f,   // A bottom-left
            -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 1.0f,   // D top-left
            // front face
            -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f,   // E bottom-left
            1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 0.0f,    // F bottom-right
            1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f,    // G top-right
            1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f,    // G top-right
            -1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 1.0f,   // H top-left
            -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f,   // E bottom-left
            // left face
            -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f,   // H top-right
            -1.0f,  1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 1.0f,   // D top-left
            -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f,   // A bottom-left
            -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f,   // A bottom-left
            -1.0f, -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 0.0f,   // E bottom-right
            -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f,   // H top-right
            // right face
            1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f,    // G top-left
            1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f,    // B bottom-right
            1.0f,  1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 1.0f,    // C top-right
            1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f,    // B bottom-right
            1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f,    // G top-left
            1.0f, -1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 0.0f,    // F bottom-left
            // bottom face
            -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f,   // F top-right
            1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 1.0f,    // E Atop-left
            1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f,    // A bottom-left
            1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f,    // A bottom-left
            -1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 0.0f,   // B bottom-right
            -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f,   // F top-right
            // top face
            -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f,   // D top-left
            1.0f,  1.0f , 1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f,    // G bottom-right
            1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 1.0f,    // C top-right
            1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f,    // G bottom-right
            -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f,   // D top-left
            -1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 0.0f    // H bottom-left
        };
        
        glGenVertexArrays(1, &_cubeVAO);
        glGenBuffers(1, &_cubeVBO);
        // fill buffer
        glBindBuffer(GL_ARRAY_BUFFER, _cubeVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
        // link vertex attributes
        glBindVertexArray(_cubeVAO);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }
}

// Returns the cubemap's texture ID if successful.
- (GLuint) createCubemapTexture:(GLuint)textureID
                       faceSize:(GLsizei)faceSize {

    GLuint cubeMapID;
    glGenTextures(1, &cubeMapID);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubeMapID);

    stbi_set_flip_vertically_on_load(false);
    for (int i=0; i<6; i++) {
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                     0,
                     GL_RGB16F,             // internal format
                     faceSize, faceSize,    // width, height
                     0,
                     GL_RGB,                // format
                     GL_FLOAT,              // type
                     nil);                  // allocate space for the pixels.
    }

    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
#if TARGET_MACOS
    glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
#endif
    GLuint captureFBO;
    GLuint captureRBO;
    glGenFramebuffers(1, &captureFBO);
    glGenRenderbuffers(1, &captureRBO);

    glBindFramebuffer(GL_FRAMEBUFFER, captureFBO);
    glBindRenderbuffer(GL_RENDERBUFFER, captureRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, faceSize, faceSize);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, captureRBO);
    GLenum framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (framebufferStatus != GL_FRAMEBUFFER_COMPLETE) {
        printf("FrameBuffer is incomplete\n");
        GetGLError();
        return 0;
    }

    // set up projection and view matrices for capturing data onto the 6 cubemap face directions
    matrix_float4x4 captureProjectionMatrix = matrix_perspective_right_hand_gl(radians_from_degrees(90),
                                                                               1.0,
                                                                               0.1, 10.0);
    matrix_float4x4 captureViewMatrices[6];
    captureViewMatrices[0] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0, 0},   // eye is at the centre of the cube.
                                                          (vector_float3){ 1,  0, 0},   // centre of +X face
                                                          (vector_float3){ 0, -1, 0});  // Up

    captureViewMatrices[1] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0, 0},   // eye is at the centre of the cube.
                                                          (vector_float3){-1,  0, 0},   // centre of +X face
                                                          (vector_float3){ 0, -1, 0});  // Up
    
    captureViewMatrices[2] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0, 0},   // eye is at the centre of the cube.
                                                          (vector_float3){ 0,  1, 0},   // centre of +X face
                                                          (vector_float3){ 0,  0, 1});  // Up
    
    captureViewMatrices[3] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0,  0},  // eye is at the centre of the cube.
                                                          (vector_float3){ 0, -1,  0},  // centre of +X face
                                                          (vector_float3){ 0,  0, -1}); // Up
    
    captureViewMatrices[4] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0, 0},   // eye is at the centre of the cube.
                                                          (vector_float3){ 0,  0, 1},   // centre of +X face
                                                          (vector_float3){ 0, -1, 0});  // Up
    
    captureViewMatrices[5] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0,  0},  // eye is at the centre of the cube.
                                                          (vector_float3){ 0,  0, -1},  // centre of +X face
                                                          (vector_float3){ 0, -1,  0}); // Up

    glUseProgram(_angularMap2CubemapProgram);
    GLint projectionMatrixLoc = glGetUniformLocation(_angularMap2CubemapProgram, "projectionMatrix");
    GLint viewMatrixLoc = glGetUniformLocation(_angularMap2CubemapProgram, "viewMatrix");
    printf("%d %d\n", projectionMatrixLoc, viewMatrixLoc);
    glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, (const GLfloat*)&captureProjectionMatrix);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glViewport(0, 0, faceSize, faceSize);

    void *pixelsBitmap[6];
    for (unsigned int i = 0; i < 6; ++i) {
        // # of channels=3, each channel consists of 1 GLfloat
        pixelsBitmap[i] = malloc(faceSize*faceSize*3*sizeof(GLfloat));
    }

    // The images of the 6 faces of the cubemap are saved
/*
    // We can use a Pixel Buffer Object to capture the bitmap
    // Setup a Pixel Buffer Object here.
    GLuint pbo;
    glGenBuffers(1, &pbo);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo);
    GLsizei pboBufferSize = 512*512*3*4;
    glBufferData(GL_PIXEL_PACK_BUFFER, pboBufferSize, NULL, GL_STREAM_READ);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);

    // The returned value for SRGB surfaces is GL_SRGB (0x8C40)
    // For other surfaces: GL_LINEAR (0x2601) should be returned.
    // glGetNamedFramebufferAttachmentParameteriv is not supported by macOS OpenGL
    GLint encoding = 0;
    glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER,
                                          GL_FRONT_AND_BACK,
                                          GL_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING,
                                          &encoding);
    // Encoding is 0x0000!
    printf("encoding: 0x%04x\n", encoding);
 */
    glBindFramebuffer(GL_FRAMEBUFFER, captureFBO);
    for (unsigned int i = 0; i < 6; ++i) {
        glUniformMatrix4fv(viewMatrixLoc, 1, GL_FALSE,
                           (const GLfloat*)&captureViewMatrices[i]);
        glFramebufferTexture2D(GL_FRAMEBUFFER,
                               GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                               cubeMapID,
                               0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        [self renderCube];
/*
        // Only GL_COLOR_ATTACHMENTi or GL_NONE is valid because
        //  we are reading from a offscreen framebuffer
        glReadBuffer(GL_COLOR_ATTACHMENT0);
 
        glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo);
        //glBindFramebuffer(GL_READ_FRAMEBUFFER, captureFBO); // not necessary
 
        // A better alternative: use glGetTexImage - ref OGL8 334
        glReadPixels(0, 0,
                     faceSize, faceSize,
                     GL_RGB,
                     GL_FLOAT,
                     NULL);         // offset

        void *pboPtr = glMapBuffer(GL_PIXEL_PACK_BUFFER, GL_READ_ONLY);
        if (pboPtr) {
            memcpy(pixelsBitmap[i], pboPtr, pboBufferSize);
            glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
 
            char cFile[32];
            sprintf(cFile, "image%02u.hdr", i);
            stbi_write_hdr((char const *)cFile,
                           faceSize, faceSize,
                           3,
                           (const float *)pixelsBitmap[i]);
        }
        glDeleteBuffers(pbo);
 */
    }

    for (unsigned int i = 0; i < 6; ++i) {
        free(pixelsBitmap[i]);
    }
    glDeleteFramebuffers(1, &captureFBO);
    glDeleteRenderbuffers(1, &captureRBO);

    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBOName);
    glUseProgram(0);
    return cubeMapID;
}


- (void) updateTime {
    _currentTime += 1/60;
}

- (void) renderCube {
    // render Cube
    glBindVertexArray(_cubeVAO);
    glDrawArrays(GL_TRIANGLES, 0, 36);
    glBindVertexArray(0);
}

- (void)draw {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  // Bind the quad vertex array object.
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glViewport(0, 0,
               _viewSize.width, _viewSize.height);
    vector_float3 eye = (vector_float3){-1,0,0};
    vector_float3 target = (vector_float3){0,0,0};
    vector_float3 up = (vector_float3){0,1,0};
    matrix_float4x4 viewMatrix = matrix_look_at_right_hand_gl(eye, target, up);
    glUseProgram(_vertCrossProgram);

    glUniformMatrix4fv(_projectionMatrixLoc, 1, GL_FALSE, (const GLfloat*)&_projectionMatrix);
    glUniform1f(_timeLoc, _currentTime);
    glUniform2f(_mouseLoc, _mouseCoords.x, _mouseCoords.y);
    glUniform2f(_resolutionLoc,
                _viewSize.width, _viewSize.height);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, _cubemapTextureID);
    glBindVertexArray(_triangleVAO);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glUseProgram(0);
    glBindVertexArray(0);
} // draw


+ (GLuint)buildProgramWithVertexSourceURL:(NSURL*)vertexSourceURL
                    withFragmentSourceURL:(NSURL*)fragmentSourceURL {

    NSError *error;

    NSString *vertSourceString = [[NSString alloc] initWithContentsOfURL:vertexSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(vertSourceString, @"Could not load vertex shader source, error: %@.", error);

    NSString *fragSourceString = [[NSString alloc] initWithContentsOfURL:fragmentSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(fragSourceString, @"Could not load fragment shader source, error: %@.", error);

    // Prepend the #version definition to the vertex and fragment shaders.
    float  glLanguageVersion;

#if TARGET_IOS
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "OpenGL ES GLSL ES %f", &glLanguageVersion);
#else
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "%f", &glLanguageVersion);
#endif

    // `GL_SHADING_LANGUAGE_VERSION` returns the standard version form with decimals, but the
    //  GLSL version preprocessor directive simply uses integers (e.g. 1.10 should be 110 and 1.40
    //  should be 140). You multiply the floating point number by 100 to get a proper version number
    //  for the GLSL preprocessor directive.
    GLuint version = 100 * glLanguageVersion;

    NSString *versionString = [[NSString alloc] initWithFormat:@"#version %d", version];
#if TARGET_IOS
    if ([[EAGLContext currentContext] API] == kEAGLRenderingAPIOpenGLES3)
        versionString = [versionString stringByAppendingString:@" es"];
#endif

    vertSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, vertSourceString];
    fragSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, fragSourceString];

    GLuint prgName;

    GLint logLength, status;

    // Create a GLSL program object.
    prgName = glCreateProgram();

    /*
     * Specify and compile a vertex shader.
     */

    GLchar *vertexSourceCString = (GLchar*)vertSourceString.UTF8String;
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, (const GLchar **)&(vertexSourceCString), NULL);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);

    if (logLength > 0) {
        GLchar *log = (GLchar*) malloc(logLength);
        glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
        NSLog(@"Vertex shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the vertex shader:\n%s.\n", vertexSourceCString);

    // Attach the vertex shader to the program.
    glAttachShader(prgName, vertexShader);

    // Delete the vertex shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(vertexShader);

    /*
     * Specify and compile a fragment shader.
     */

    GLchar *fragSourceCString =  (GLchar*)fragSourceString.UTF8String;
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragShader, 1, (const GLchar **)&(fragSourceCString), NULL);
    glCompileShader(fragShader);
    glGetShaderiv(fragShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetShaderInfoLog(fragShader, logLength, &logLength, log);
        NSLog(@"Fragment shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(fragShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the fragment shader:\n%s.", fragSourceCString);

    // Attach the fragment shader to the program.
    glAttachShader(prgName, fragShader);

    // Delete the fragment shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(fragShader);

    /*
     * Link the program.
     */

    glLinkProgram(prgName);
    glGetProgramiv(prgName, GL_LINK_STATUS, &status);
    NSAssert(status, @"Failed to link program.");
    if (status == 0) {
        glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0)
        {
            GLchar *log = (GLchar*)malloc(logLength);
            glGetProgramInfoLog(prgName, logLength, &logLength, log);
            NSLog(@"Program link log:\n%s.\n", log);
            free(log);
        }
    }

    // Added code
    // Call the 2 functions below if VAOs have been bound prior to creating the shader program
    // iOS will not complain if VAOs have NOT been bound.
    glValidateProgram(prgName);
    glGetProgramiv(prgName, GL_VALIDATE_STATUS, &status);
    NSAssert(status, @"Failed to validate program.");

    if (status == 0) {
        fprintf(stderr,"Program cannot run with current OpenGL State\n");
        glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar*)malloc(logLength);
            glGetProgramInfoLog(prgName, logLength, &logLength, log);
            NSLog(@"Program validate log:\n%s\n", log);
            free(log);
        }
    }

    //GLint samplerLoc = glGetUniformLocation(prgName, "baseColorMap");

    //NSAssert(samplerLoc >= 0, @"No uniform location found from `baseColorMap`.");

    //glUseProgram(prgName);

    // Indicate that the diffuse texture will be bound to texture unit 0.
   // glUniform1i(samplerLoc, AAPLTextureIndexBaseColor);

    GetGLError();

    return prgName;
}

@end
