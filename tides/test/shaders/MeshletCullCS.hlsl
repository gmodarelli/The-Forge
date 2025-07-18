bool FrustumCull(float3 aabb_center, float3 aabb_extents, float4x4 world, float4x4 view_proj);

#ifdef CLEAR_COUNTERS

#include "Defines.hlsli"

struct ClearUAVParams
{
    uint counters_buffer_index;
    uint visible_counters_buffer_index;
};

cbuffer g_ClearUAVParams : register(b0, SPACE_PerFrame)
{
    ClearUAVParams g_clear_uav_params;
};

[RootSignature(ComputeRootSignature)]
[numthreads(1, 1, 1)]
void ClearCountersCS()
{
    RWStructuredBuffer<uint> counters_buffer = ResourceDescriptorHeap[g_clear_uav_params.counters_buffer_index];
    counters_buffer[0] = 0;
    counters_buffer[1] = 0;

    RWStructuredBuffer<uint> visible_counters_buffer = ResourceDescriptorHeap[g_clear_uav_params.visible_counters_buffer_index];
    visible_counters_buffer[0] = 0;
    visible_counters_buffer[1] = 0;
}

#endif // CLEAR_COUNTERS

#ifdef CULL_INSTANCES

#include "Globals.hlsli"

struct CullInstancesParams
{
    uint counters_buffer_index;
    uint candidate_meshlets_buffer_index;
};

cbuffer g_CullInstancesParams : register(b1, SPACE_PerFrame)
{
    CullInstancesParams g_cull_instances_params;
};

[RootSignature(ComputeRootSignature)]
[numthreads(CULL_INSTANCES_THREADS_COUNT, 1, 1)]
void CullInstancesCS(uint thread_id : SV_DispatchThreadID)
{
    RWByteAddressBuffer counters_buffer = ResourceDescriptorHeap[g_cull_instances_params.counters_buffer_index];
    RWByteAddressBuffer meshlet_candidates_buffer = ResourceDescriptorHeap[g_cull_instances_params.candidate_meshlets_buffer_index];
    uint instances_count = g_frame.instances_count;

    if (thread_id >= instances_count)
    {
        return;
    }

    uint instance_index = thread_id;
    Instance instance = getInstance(instance_index);

    ByteAddressBuffer mesh_buffer = ResourceDescriptorHeap[g_frame.meshes_buffer_index];
    Mesh mesh = mesh_buffer.Load<Mesh>(instance.mesh_index * sizeof(Mesh));

    bool is_visible = FrustumCull(instance.local_bounds_origin, instance.local_bounds_extents, instance.world, g_frame.view_proj);

    if (is_visible)
    {
        // Limit meshlet count to the buffer size
        // TODO: Set an out-of-memory flag to let the CPU know to grow the meshlet buffer
        uint global_mesh_index;
        InterlockedAdd_Varying_WaveOps_ByteAddressBuffer(counters_buffer, 0 * sizeof(uint), mesh.meshlet_count, global_mesh_index);
        int clamped_meshlet_count = min(global_mesh_index + mesh.meshlet_count, MESHLET_COUNT_MAX);
        int meshlets_to_add_count = max(clamped_meshlet_count - (int)global_mesh_index, 0);

        // Add all meshlets of the current instance to the candidate meshlets buffer
        uint element_offset;
        InterlockedAdd_Varying_WaveOps_ByteAddressBuffer(counters_buffer, 1 * sizeof(uint), meshlets_to_add_count, element_offset);

        for (uint i = 0; i < meshlets_to_add_count; i++)
        {
            MeshletCandidate meshlet;
            meshlet.instance_id = instance.id;
            meshlet.meshlet_index = i;
            meshlet_candidates_buffer.Store<MeshletCandidate>((element_offset + i) * sizeof(MeshletCandidate), meshlet);
        }
    }
}

#endif // CULL_INSTANCES

#ifdef MESHLET_CULL_ARGUMENTS

#include "Defines.hlsli"

struct MeshletCullArgsParams
{
    uint counters_buffer_index;
    uint dispatch_args_buffer_index;
};

cbuffer g_MeshletCullArgsParams : register(b0, SPACE_PerFrame)
{
    MeshletCullArgsParams g_meshlet_cull_args_params;
};

[RootSignature(ComputeRootSignature)]
[numthreads(1, 1, 1)]
void BuildMeshletCullIndirectArgsCS()
{
    RWStructuredBuffer<uint> counters_buffer = ResourceDescriptorHeap[g_meshlet_cull_args_params.counters_buffer_index];
    RWStructuredBuffer<uint3> args_buffer = ResourceDescriptorHeap[g_meshlet_cull_args_params.dispatch_args_buffer_index];
    uint meshlets_count = counters_buffer[1];
    uint3 args = uint3(1, 1, 1);
    args.x = (meshlets_count + CULL_MESHLETS_THREADS_COUNT - 1) / CULL_MESHLETS_THREADS_COUNT;
    args_buffer[0] = args;
}

#endif // MESHLET_CULL_ARGUMENTS

#ifdef CULL_MESHLETS

#include "Globals.hlsli"

struct CullMeshletsParams
{
    uint counters_buffer_index;
    uint candidate_meshlets_buffer_index;
    uint visible_counters_buffer_index;
    uint visible_meshlets_buffer_index;
};

cbuffer g_CullMeshletsParams : register(b1, SPACE_PerFrame)
{
    CullMeshletsParams g_cull_meshlets_params;
};

[RootSignature(ComputeRootSignature)]
[numthreads(CULL_MESHLETS_THREADS_COUNT, 1, 1)]
void CullMeshletsCS(uint thread_id : SV_DispatchThreadID)
{
    RWStructuredBuffer<uint> counters_buffer = ResourceDescriptorHeap[g_cull_meshlets_params.counters_buffer_index];
    RWStructuredBuffer<uint> visible_counters_buffer = ResourceDescriptorHeap[g_cull_meshlets_params.visible_counters_buffer_index];
    uint instances_count = g_frame.instances_count;

    if (thread_id < counters_buffer[1])
    {
        RWStructuredBuffer<MeshletCandidate> meshlet_candidates_buffer = ResourceDescriptorHeap[g_cull_meshlets_params.candidate_meshlets_buffer_index];
        uint candidate_index = thread_id;
        MeshletCandidate candidate = meshlet_candidates_buffer[candidate_index];

        Instance instance = getInstance(candidate.instance_id);

        ByteAddressBuffer mesh_buffer = ResourceDescriptorHeap[g_frame.meshes_buffer_index];
        Mesh mesh = mesh_buffer.Load<Mesh>(instance.mesh_index * sizeof(Mesh));

        ByteAddressBuffer data_buffer = ResourceDescriptorHeap[NonUniformResourceIndex(mesh.data_buffer_index)];
        MeshletBounds bounds = data_buffer.Load<MeshletBounds>(candidate.meshlet_index * sizeof(MeshletBounds) + mesh.meshlet_bounds_offset);
        bool is_visible = FrustumCull(bounds.local_center, bounds.local_extents, instance.world, g_frame.view_proj);

        if (is_visible)
        {
            uint element_offset;
            InterlockedAdd_WaveOps(visible_counters_buffer, 0, 1, element_offset);
            RWStructuredBuffer<MeshletCandidate> visible_meshlet_buffer = ResourceDescriptorHeap[g_cull_meshlets_params.visible_meshlets_buffer_index];
            visible_meshlet_buffer[element_offset] = candidate;
        }
    }
}

#endif // CULL_MESHLETS

bool FrustumCull(float3 aabb_center, float3 aabb_extents, float4x4 world, float4x4 view_proj)
{
    bool is_visible = true;

    float3 ext = aabb_extents * 2.0f;
    float4x4 extents_basis = float4x4(
        ext.x, 0.0, 0.0, 0.0,
        0.0, ext.y, 0.0, 0.0,
        0.0, 0.0, ext.z, 0.0,
        0.0, 0.0, 0.0, 0.0
    );
    float4x4 axis = mul(mul(extents_basis, world), view_proj);

    float4 corner_000 = mul(mul(float4(aabb_center - aabb_extents, 1), world), view_proj);
    float4 corner_100 = corner_000 + axis[0];
    float4 corner_010 = corner_000 + axis[1];
    float4 corner_110 = corner_010 + axis[0];
    float4 corner_001 = corner_000 + axis[2];
    float4 corner_101 = corner_100 + axis[2];
    float4 corner_011 = corner_010 + axis[2];
    float4 corner_111 = corner_110 + axis[2];

    float min_w = min(corner_000.w, corner_001.w);
    min_w = min(min_w, corner_010.w);
    min_w = min(min_w, corner_011.w);
    min_w = min(min_w, corner_100.w);
    min_w = min(min_w, corner_101.w);
    min_w = min(min_w, corner_110.w);
    min_w = min(min_w, corner_111.w);

    float max_w = max(corner_000.w, corner_001.w);
    max_w = max(max_w, corner_010.w);
    max_w = max(max_w, corner_011.w);
    max_w = max(max_w, corner_100.w);
    max_w = max(max_w, corner_101.w);
    max_w = max(max_w, corner_110.w);
    max_w = max(max_w, corner_111.w);

    // Plane inequalities
    float4 plane_mins = min(float4(corner_000.xy, -corner_000.xy) - corner_000.w, float4(corner_001.xy, -corner_001.xy) - corner_001.w);
    plane_mins = min(plane_mins, float4(corner_010.xy, -corner_010.xy) - corner_010.w);
    plane_mins = min(plane_mins, float4(corner_100.xy, -corner_100.xy) - corner_100.w);
    plane_mins = min(plane_mins, float4(corner_110.xy, -corner_110.xy) - corner_110.w);
    plane_mins = min(plane_mins, float4(corner_011.xy, -corner_011.xy) - corner_011.w);
    plane_mins = min(plane_mins, float4(corner_101.xy, -corner_101.xy) - corner_101.w);
    plane_mins = min(plane_mins, float4(corner_111.xy, -corner_111.xy) - corner_111.w);
    plane_mins = min(plane_mins, float4(1, 1, 1, 1));

    // Clip-space AABB
    float3 corner_000_cs = corner_000.xyz / corner_000.w;
    float3 corner_100_cs = corner_100.xyz / corner_100.w;
    float3 corner_010_cs = corner_010.xyz / corner_010.w;
    float3 corner_110_cs = corner_110.xyz / corner_110.w;
    float3 corner_001_cs = corner_001.xyz / corner_001.w;
    float3 corner_101_cs = corner_101.xyz / corner_101.w;
    float3 corner_011_cs = corner_011.xyz / corner_011.w;
    float3 corner_111_cs = corner_111.xyz / corner_111.w;

    float3 rect_min = min(corner_000_cs, corner_100_cs);
    rect_min = min(rect_min, corner_010_cs);
    rect_min = min(rect_min, corner_110_cs);
    rect_min = min(rect_min, corner_001_cs);
    rect_min = min(rect_min, corner_101_cs);
    rect_min = min(rect_min, corner_011_cs);
    rect_min = min(rect_min, corner_111_cs);
    rect_min = min(rect_min, float3(1, 1, 1));

    float3 rect_max = max(corner_000_cs, corner_100_cs);
    rect_max = max(rect_max, corner_010_cs);
    rect_max = max(rect_max, corner_110_cs);
    rect_max = max(rect_max, corner_001_cs);
    rect_max = max(rect_max, corner_101_cs);
    rect_max = max(rect_max, corner_011_cs);
    rect_max = max(rect_max, corner_111_cs);
    rect_max = max(rect_max, float3(1, 1, 1));

    is_visible &= rect_max.z > 0;

    if (min_w <= 0 && max_w > 0)
    {
        rect_min = -1;
        rect_max = 1;
        is_visible = true;
    }
    else
    {
        is_visible &= max_w > 0.0f;
    }

    is_visible &= !any(plane_mins > 0.0f);

    return is_visible;
}