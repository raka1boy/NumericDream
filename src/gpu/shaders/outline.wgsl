struct OutlineUniforms {
    inv_screen: vec2f,
    selected_id: f32,
    thickness_px: f32,
}

@group(0) @binding(0) var<uniform> ou: OutlineUniforms;
@group(0) @binding(1) var mask_tex: texture_2d<f32>;
@group(0) @binding(2) var src_tex: texture_2d<f32>;
@group(0) @binding(3) var src_sampler: sampler;

struct VertexOut {
    @builtin(position) clip_pos: vec4f,
}

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VertexOut {
    var positions = array<vec2f, 3>(
        vec2f(-1.0, -1.0),
        vec2f(3.0, -1.0),
        vec2f(-1.0, 3.0),
    );
    var out: VertexOut;
    out.clip_pos = vec4f(positions[idx], 0.0, 1.0);
    return out;
}

const OUTLINE_TAPS = 12;
const OUTLINE_TAU = 6.28318530718;
const OUTLINE_INNER_RING = 0.5;
const OUTLINE_MID_BAND = 0.18;

fn mask_is_selected(texel: vec2f, dims: vec2f) -> bool {
    let c = vec2i(clamp(texel, vec2f(0.0), dims - vec2f(1.0)));
    return abs(textureLoad(mask_tex, c, 0).r * 255.0 - ou.selected_id) < 0.5;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4f {
    if (ou.selected_id < 0.5) {
        discard;
    }
    let dims = vec2f(textureDimensions(mask_tex));
    let uv = in.clip_pos.xy * ou.inv_screen;
    let here = uv * dims;
    if (mask_is_selected(here, dims)) {
        discard;
    }

    let radius = max(ou.thickness_px * dims * ou.inv_screen, vec2f(1.0));
    var found = false;
    for (var i = 0; i < OUTLINE_TAPS; i++) {
        let a = (f32(i) + 0.5) * OUTLINE_TAU / f32(OUTLINE_TAPS);
        let offset = vec2f(cos(a), sin(a)) * radius;
        found = found || mask_is_selected(here + offset, dims);
        found = found || mask_is_selected(here + offset * OUTLINE_INNER_RING, dims);
    }
    if (!found) {
        discard;
    }

    let hdr = textureSampleLevel(src_tex, src_sampler, uv, 0.0).rgb;
    let base = hdr / (hdr + vec3f(1.0));
    let luma = dot(base, vec3f(0.2126, 0.7152, 0.0722));
    let extreme = select(vec3f(1.0), vec3f(0.0), luma > 0.5);
    let blend = 1.0 - smoothstep(0.0, OUTLINE_MID_BAND, abs(luma - 0.5));
    return vec4f(mix(1.0 - base, extreme, blend), 1.0);
}
