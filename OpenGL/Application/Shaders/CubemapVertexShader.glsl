
in vec3 aPos;

uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;

#if __VERSION__ >= 140

out vec3 worldPos;

#else

varying vec3 worldPos;

#endif


void main() {
    worldPos = aPos;
    gl_Position = projectionMatrix * viewMatrix * vec4(aPos, 1.0);
}
