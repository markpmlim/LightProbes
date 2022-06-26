// https://stackoverflow.com/questions/56986420/convert-a-fisheye-image-to-an-equirectangular-image-with-opencv4
// Fisheye to spherical conversion
// Assumes the fisheye image is square, centered, and the circle fills the image.
// Output image should have 1:1 aspect

#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ >= 140
in vec2 texCoords;

out vec4 FragColor;

#else

varying vec2 texCoords;

#endif

uniform samplerCube cubemapTexture;
uniform vec2 u_resolution;  // Input Image size (width, height) (unused)
uniform vec2 u_mouse;       // mouse position in screen pixels (unused)
uniform float u_time;       // Time in seconds since load (unused)


const float PI = 3.14159265359;


/*
 We map OpenGL's 2D Texture Coordinate System with a range of [0.0, 1.0] for
  both the u-axis and v-axis to a virtual 2D coordinate system having a range
  of [0.0, 3.0] and [0.0, 4.0] for the horizontal and vertical axes respectively.
  This simplifies the arithemetic.
 */
void main(void) {
    vec4 fragColor = vec4(0.0, 0.0, 0.2, 1.0);
    vec2 inUV = texCoords;
    // Vertical cross
    // Range of inUV.x: [0.0, 1.0] ---> [0.0, 3.0]
    // Range of inUV.y: [0.0, 1.0] ---> [0.0, 4.0]
    inUV *= vec2(3.0, 4.0);
    
    vec3 samplePos = vec3(0.0);
    
    int x = int(floor(inUV.x));     // 0, 1, 2
    int y = int(floor(inUV.y));     // 0, 1, 2, 3
    
    if (x == 1) {
        // Middle vertical column of 4 squares (-Z, -Y, +Z, +Y)
        // inUV.x: [1.0, 2.0] ---> uv.x: [0.0, 1.0]
        // inUV.y: [0.0, 4.0] ---> uv.y: [0.0, 1.0]
        vec2 uv = vec2((inUV.x - 1.0),
                       (inUV.y - float(y)));
        // uv.x: [0.0, 1.0] ---> [-1.0, 1.0]
        // uv.y: [0.0, 1.0] ---> [-1.0, 1.0]
        uv = 2.0 * uv - 1.0;
        // Now convert the uv coords into a 3D vector which will be
        //  used to access the correct face of the cube map.
        switch (y) {
            case 0: // NEGATIVE_Z
                // Need to flip horizontally and vertically.
                //samplePos = vec3(-uv.x, uv.y, -1.0);
                samplePos = vec3(+uv.x, -uv.y, -1.0);
                break;
            case 1: // NEGATIVE_Y
                samplePos = vec3(uv.x, -1.0,  uv.y);
                break;
            case 2: // POSITIVE_Z
                samplePos = vec3( uv.x, uv.y, 1.0);
                break;
            case 3: // POSITIVE_Y
                samplePos = vec3(uv.x,  1.0, -uv.y);
                break;
        }
    }
    else {
        // x = 0 or x = 2
        // 3rd horizontal row of 2 squares (-X, +X)
        if (y == 2) {
            // x = 0 (-X)
            // inUV.x: [0.0, 1.0] ---> uv.x: [0.0, 1.0]
            // inUV.y: [2.0, 3.0] ---> uv.y: [0.0, 1.0]
            // x = 2 (+X)
            // inUV.x: [2.0, 3.0] ---> uv.x: [0.0, 1.0]
            // inUV.y: [2.0, 3.0] ---> uv.y: [0.0, 1.0]
            vec2 uv = vec2((inUV.x - float(x)),
                           (inUV.y - 2.0));
            // Convert [0.0, 1.0] ---> [-1.0, 1.0]
            uv = 2.0 * uv - 1.0;
            switch (x) {
                case 0: // NEGATIVE_X
                    samplePos = vec3(-1.0, uv.y, uv.x);
                    break;
                case 2: // POSITIVE_X
                    samplePos = vec3( 1.0, uv.y,  -uv.x);
                    break;
            }
        }
    }
    if ((samplePos.x != 0.0) && (samplePos.y != 0.0)) {
    #if __VERSION__ >= 140
        FragColor = texture(cubemapTexture, samplePos);
    #else
        gl_FragColor = textureCube(cubemapTexture, samplePos);
    #endif
    }
}
