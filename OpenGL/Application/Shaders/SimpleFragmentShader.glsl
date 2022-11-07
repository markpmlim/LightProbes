#ifdef GL_ES
precision highp float;
#endif

#if __VERSION__ >= 140

in vec2 texCoords;

out vec4 FragColor;

#else

varying vec2 texCoords;

#endif


uniform sampler2D image;

void main(void) {

#if __VERSION__ >= 140
    FragColor = texture(image, texCoords);
#else
    gl_FragColor = texture2D(image, texCoords);
#endif
}
