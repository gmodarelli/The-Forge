#include "Globals.hlsli"

struct ShadowFrame
{
    float4x4 shadow_matrix;
    float4 cascade_offsets[CASCADES_MAX_COUNT];
    float4 cascade_scales[CASCADES_MAX_COUNT];
    float4 cascade_splits;
};

cbuffer g_ShadowCB : register(b1, SPACE_PerFrame)
{
    ShadowFrame g_shadow_frame;
};

Texture2D<float4> g_gbuffer0 : register(t0, SPACE_Persistent);
Texture2D<float4> g_gbuffer1 : register(t1, SPACE_Persistent);
Texture2D<float> g_depth_buffer : register(t2, SPACE_Persistent);
Texture2DArray<float4> g_shadow_map : register(t3, SPACE_Persistent);
RWTexture2D<float4> g_output : register(u2, SPACE_PerFrame);

float2 ComputeReceiverPlaneDepthBias(float3 tex_coord_dx, float3 tex_coord_dy)
{
    float2 bias_uv;
    bias_uv.x = tex_coord_dy.y * tex_coord_dx.z - tex_coord_dx.y * tex_coord_dy.z;
    bias_uv.y = tex_coord_dx.x * tex_coord_dy.z - tex_coord_dy.x * tex_coord_dx.z;
    bias_uv *= 1.0f / ((tex_coord_dx.x * tex_coord_dy.y) - (tex_coord_dx.y * tex_coord_dy.x));
    return bias_uv;
}

float SampleShadowMapFixedSizePCF(float3 shadow_pos, float3 shadow_pos_dx, float3 shadow_pos_dy, uint cascade_index)
{
    float2 shadow_map_size;
    float num_slices;
    g_shadow_map.GetDimensions(shadow_map_size.x, shadow_map_size.y, num_slices);

    float light_depth = shadow_pos.z;
    // TODO: Move this to the Frame cbuffer
    const float bias = 0.005;

    float2 texel_size = 1.0f / shadow_map_size;
    float2 receiver_plane_depth_bias = ComputeReceiverPlaneDepthBias(shadow_pos_dx, shadow_pos_dy);

    // Static depth biasing to make up for incorrect fractional sampling on the shadow map grid
    float fractional_sampling_error = dot(float2(1.0f, 1.0f) * texel_size, abs(receiver_plane_depth_bias));
    light_depth -= min(fractional_sampling_error, 0.01f);

    // NOTE: This only works for a filter size of 2
    // TODO: Add support for filter sizes > 2
    SamplerComparisonState shadow_pcf_sample = SamplerDescriptorHeap[g_frame.shadow_pcf_sampler_index];
    return g_shadow_map.SampleCmpLevelZero(shadow_pcf_sample, float3(shadow_pos.xy, cascade_index), light_depth);
}

// TODO: Add debug cascade visibility here?
float SampleShadowCascade(float3 shadow_position, float3 shadow_pos_dx, float3 shadow_pos_dy, uint cascade_index)
{
    shadow_position += g_shadow_frame.cascade_offsets[cascade_index].xyz;
    shadow_position *= g_shadow_frame.cascade_scales[cascade_index].xyz;

    shadow_pos_dx *= g_shadow_frame.cascade_scales[cascade_index].xyz;
    shadow_pos_dy *= g_shadow_frame.cascade_scales[cascade_index].xyz;

    return SampleShadowMapFixedSizePCF(shadow_position, shadow_pos_dx, shadow_pos_dy, cascade_index);
}

float3 GetShadowPosOffset(in float n_dot_l, in float3 normal)
{
    float2 shadow_map_size;
    float num_slices;
    g_shadow_map.GetDimensions(shadow_map_size.x, shadow_map_size.y, num_slices);
    float texel_size = 2.0f / shadow_map_size.x;
    float nml_offset_scale = saturate(1.0f - n_dot_l);
    // TODO: Move this to shadow_frame
    float offset_scale = 0.0f;
    return texel_size * offset_scale * nml_offset_scale * normal;
}

float ShadowVisibility(float3 position_ws, float depth_vs, float n_dot_l, float3 normal)
{
    float shadow_visibility = 1.0f;
    uint cascade_index = CASCADES_MAX_COUNT - 1;

    // Figure out which cascade to sampler from
    [unroll]
    for (int i = CASCADES_MAX_COUNT - 1; i >= 0; --i)
    {
        // Select based on whether or not our view-space depth falls within
        // the depth range of a cascade split
        if (depth_vs <= g_shadow_frame.cascade_splits[i])
        {
            cascade_index = i;
        }
    }

    // Apply offset
    float3 offset = GetShadowPosOffset(n_dot_l, normal) / abs(g_shadow_frame.cascade_scales[cascade_index].z);

    // Project into shadow space
    float3 sample_pos = position_ws + offset;
    float3 shadow_position = mul(float4(sample_pos, 1.0f), g_shadow_frame.shadow_matrix).xyz;
    float3 shadow_pos_dx = ddx_fine(shadow_position);
    float3 shadow_pos_dy = ddy_fine(shadow_position);

    shadow_visibility = SampleShadowCascade(shadow_position, shadow_pos_dx, shadow_pos_dy, cascade_index);

    // TODO: Implement filtering across cascades here

    return shadow_visibility;
}

float LinearDepth(float depth)
{
    depth = g_frame.projection._34 / (depth - g_frame.projection._33);
    depth = saturate((depth - g_frame.camera_near_plane) / (g_frame.camera_far_plane - g_frame.camera_near_plane));
    return depth;
}

float4 GetClipPositionFromDepth(float depth, float2 uv)
{
    float x = uv.x * 2.0f - 1.0f;
    float y = (1.0f - uv.y) * 2.0f - 1.0f;
    float4 position_cs = float4(x, y, depth, 1.0f);
    return mul(position_cs, g_frame.inv_view_proj);
}

float3 GetWorldPositionFromDepth(float depth, float2 uv)
{
    float4 position_cs = GetClipPositionFromDepth(depth, uv);
    return position_cs.xyz / position_cs.w;
}

[RootSignature(ComputeRootSignature)]
[numthreads(8, 8, 1)]
void main( uint3 DTid : SV_DispatchThreadID )
{
    uint2 output_resolution;
    g_output.GetDimensions(output_resolution.x, output_resolution.y);

    if (DTid.x > output_resolution.x || DTid.y > output_resolution.y)
    {
        return;
    }

    float3 albedo = g_gbuffer0[DTid.xy].rgb;
    float3 normal = g_gbuffer1[DTid.xy].xyz * 2.0 - 1.0;
    float depth_cs = g_depth_buffer[DTid.xz].x;

    float depth_vs = LinearDepth(depth_cs);

    float2 uv = DTid.xy / float2(output_resolution);
    float4 position_cs = GetClipPositionFromDepth(depth_cs, uv);
    float3 position_ws = position_cs.xyz / position_cs.w;

    float3 light_direction = normalize(float3(0.01, 1.0, 0.01));
    float n_dot_l = dot(normal, light_direction);
    float shadow_visibility = ShadowVisibility(position_ws, depth_vs, n_dot_l, normal);

    // Fake lighting
    float3 light_color = 1;
    float3 lo = light_color * saturate(n_dot_l);
    float3 color = (albedo + lo) * shadow_visibility;
    g_output[DTid.xy] = float4(color, 1.0);
}