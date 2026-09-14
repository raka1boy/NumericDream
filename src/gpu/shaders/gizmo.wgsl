struct GizmoUniforms {
    camera_pos: vec3f,
    aspect: f32,
    camera_right: vec3f,
    _pad0: f32,
    camera_up: vec3f,
    _pad1: f32,
    camera_forward: vec3f,
    slice_zoom: f32,
}

@group(0) @binding(0) var<uniform> gu: GizmoUniforms;

struct VertexIn {
    @location(0) position: vec3f,
    @location(1) color: vec3f,
}

struct VertexOut {
    @builtin(position) clip_pos: vec4f,
    @location(0) color: vec3f,
}

@vertex
fn vs_main(in: VertexIn) -> VertexOut {
    let rel = in.position - gu.camera_pos;
    let right_amt = dot(rel, gu.camera_right);
    let up_amt = dot(rel, gu.camera_up);
    let forward_amt = dot(rel, gu.camera_forward);

    var out: VertexOut;

    if (gu.slice_zoom > 0.0) {
        out.clip_pos = vec4f(right_amt / (gu.aspect * gu.slice_zoom), -up_amt / gu.slice_zoom, 0.5, 1.0);
        out.color = in.color;
        return out;
    }

    out.clip_pos = vec4f(right_amt / gu.aspect, -up_amt, 0.5 * forward_amt, forward_amt);
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4f {
    return vec4f(in.color, 1.0);
}
