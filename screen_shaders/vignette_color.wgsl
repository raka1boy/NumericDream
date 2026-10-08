// @param Exposure min=0.1 max=4.0 default=1.0
// @param Saturation min=0.0 max=2.5 default=1.0
// @param Vignette min=0.0 max=1.5 default=0.5
// @param Vignette radius min=0.2 max=1.2 default=0.75

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    var c = color.rgb * p[0];

    let grey = luminance(c);
    c = mix(vec3f(grey), c, p[1]);

    let centred = (uv - vec2f(0.5)) * vec2f(max(pp.aspect, 1.0), 1.0);
    let falloff = smoothstep(p[3], p[3] * 0.35, length(centred));
    c *= mix(1.0, falloff, p[2]);

    return vec4f(c, color.a);
}
