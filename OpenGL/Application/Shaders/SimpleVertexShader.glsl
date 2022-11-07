#if __VERSION__ >= 140

out vec2 texCoords;

#else

varying vec2 texCoords;

#endif

void main(void) {

    // The position of a square made of 2 triangle strips.
    const vec4 verts[4] = vec4[4](vec4(-1.0, -1.0, 0.0, 1.0),
                                  vec4( 1.0, -1.0, 0.0, 1.0),
                                  vec4(-1.0,  1.0, 0.0, 1.0),
                                  vec4( 1.0,  1.0, 0.0, 1.0));
    // The tex coords of the vertices of 2 triangle strips.
    const vec2 uvCoords[4] = vec2[4](vec2(0.0, 0.0),
                                     vec2(1.0, 0.0),
                                     vec2(0.0, 1.0),
                                     vec2(1.0, 1.0));
    texCoords = uvCoords[gl_VertexID];
    gl_Position = verts[gl_VertexID];
}
