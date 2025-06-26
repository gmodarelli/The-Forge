#include "Defines.hlsli"

struct SpriteConstantBuffer
{
    float2 viewport_size;
    float2 _padding;
    uint vertex_buffer_index;
    uint instance_buffer_index;
    uint linear_clamp_sampler_index;
    uint linear_repeat_sampler_index;
};

struct SpriteInstance
{
    float4x4 transform;
    float4 color;
    float4 source_rect;
    float2 sprite_resolution;
    uint sprite_atlas_index;
    uint _padding;
};

cbuffer g_CB : register(b0, SPACE_PerFrame)
{
    SpriteConstantBuffer g_cb;
};

// NOTE: We are using a single vertex representation at the moment
struct Vertex
{
    float3 position;
    float2 uv;
    float3 normal;
};

struct Varyings
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD;
    float4 color : COLOR;
    uint instance_index : SV_INSTANCEID;
};

struct VertexShaderInput
{
    uint vertex_id : SV_VertexID;
    uint instance_id : SV_InstanceID;
    uint start_vertex_location : SV_StartVertexLocation;
    uint start_instance_location : SV_StartInstanceLocation;
};

SpriteInstance getSpriteInstance(uint instance_index)
{
    ByteAddressBuffer instance_buffer = ResourceDescriptorHeap[g_cb.instance_buffer_index];
    SpriteInstance instance = instance_buffer.Load<SpriteInstance>(instance_index * sizeof(SpriteInstance));
    return instance;
}

[RootSignature(DefaultRootSignature)]
Varyings SpriteVS(VertexShaderInput input)
{
    uint instance_index = input.instance_id + input.start_instance_location;
    SpriteInstance instance = getSpriteInstance(instance_index);

    uint vertex_index = input.vertex_id + input.start_vertex_location;
    ByteAddressBuffer vertex_buffer = ResourceDescriptorHeap[g_cb.vertex_buffer_index];
    Vertex vertex = vertex_buffer.Load<Vertex>(vertex_index * sizeof(Vertex));

    // Scale the quad so that it is texture-sized
    float4 position_ss = float4(vertex.position.xy * instance.source_rect.zw, 0.0f, 1.0f);

    // Apply transform in screen space
    position_ss = mul(position_ss, instance.transform);

    // Scale by the viewport size, flip Y, then rescale to device coordinates
    float4 position_ds = position_ss;
    position_ds.xy /= g_cb.viewport_size;
    position_ds = position_ds * 2.0f - 1.0f;
    position_ds.y *= -1.0f;

    // Figure out the texture coordinates
    float2 uv = 1.0 - vertex.uv;
    uv *= instance.source_rect.zw / instance.sprite_resolution;
    uv += instance.source_rect.xy / instance.sprite_resolution;

    Varyings output = (Varyings) 0;
    output.position = position_ds;
    output.uv = uv;
    output.color = instance.color;
    output.instance_index = instance_index;
    return output;
}

float median(float r, float g, float b)
{
    return max(min(r, g), min(max(r, g), b));
}

float screenPixelRange(float2 uv, float2 atlas_resolution)
{
    // TODO: Move this to the consta
    float pixel_range = 4.0;

    float2 unit_range = float2(pixel_range.xx) / atlas_resolution;
    float2 screen_tex_size = float2(1.0, 1.0) / fwidth(uv);
    return max(0.5 * dot(unit_range, screen_tex_size), 1.0);
}

[RootSignature(DefaultRootSignature)]
float4 SpritePS(Varyings varyings) : SV_Target
{
    SpriteInstance instance = getSpriteInstance(varyings.instance_index);

    Texture2D sprite = ResourceDescriptorHeap[NonUniformResourceIndex(instance.sprite_atlas_index)];
    SamplerState sampler = SamplerDescriptorHeap[g_cb.linear_clamp_sampler_index];

    // https://github.com/Chlumsky/msdfgen?tab=readme-ov-file#using-a-multi-channel-distance-field
    float3 msd = sprite.Sample(sampler, varyings.uv).rgb;
    float sd = median(msd.r, msd.g, msd.b);

    float screen_px_range = screenPixelRange(varyings.uv, instance.sprite_resolution);
    float screen_px_distance = screen_px_range * (sd - 0.5);
    float opacity = clamp(screen_px_distance + 0.5, 0.0, 1.0);
    float3 color = lerp(0, varyings.color.rgb, opacity);

    return float4(color, opacity * varyings.color.a);
}