// To generate a cubemap texture from the light probe image

#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ >= 140
in vec3 worldPos;

out vec4 FragColor;

#else

varying vec3 worldPos;

#endif

uniform sampler2D angularMapImage;

#define M_PI 3.1415926535897932384626433832795

void main(void) {
    // If P is world position, then normalize(worldPos) is
    //  P * 1/sqrt(Py*Py + Px*Px + Pz*Pz)
    vec3 dir = normalize(worldPos);

    // The range of acos(dir.z): [-π, π]
    // On multiplying its value by 1/2π --> [-0.5, 0.5]
    // Since the vector vec2(dir.x, dir.y) is NOT a unit vector, we
    //  have to scale it so that vec2(r*dir.x, r*dir.y) lies
    //  in the range [-0.5, 0.5]
    float r = (0.5/M_PI) * acos(dir.z)/sqrt(dir.x*dir.x + dir.y*dir.y);

    // Range of vec2(r*dir.x, r*dir.y): [-0.5, 0.5]
    // Range of uv: [0, 1]
    vec2 uv = vec2(0.5 + r*dir.x, 0.5 + r*dir.y);

#if __VERSION__ >= 140
    FragColor = texture(angularMapImage, uv);
#else
    gl_FragColor = texture2D(angularMapImage, uv);
#endif
}
