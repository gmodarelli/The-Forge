#include "Globals.hlsli"

struct PrimitiveAttribute
{
    uint primitive_id : SV_PrimitiveID;
    uint candidate_index : CANDIDATE_INDEX;
};

struct VertexAttribute
{
    float4 position : SV_Position;
};

struct RasterizerParams
{
    uint visible_meshlets_buffer_index;
};

cbuffer g_RasterizerParams : register(b1, SPACE_PerFrame)
{
    RasterizerParams g_rasterizer_params;
};

#if MESH_SHADER

VertexAttribute FetchVertexAttribute(Mesh mesh, float4x4 world, uint vertex_id)
{
    VertexAttribute attribute = (VertexAttribute)0;
    ByteAddressBuffer data_buffer = ResourceDescriptorHeap[NonUniformResourceIndex(mesh.data_buffer_index)];
    float3 position = data_buffer.Load<float3>(vertex_id * sizeof(MeshletBounds) + mesh.positions_offset);
    float3 position_ws = mul(float4(position, 1.0f), world).xyz;
    attribute.position = mul(float4(position_ws, 1.0f), g_frame.view_proj);
    return attribute;
}

[RootSignature(ComputeRootSignature)]
[outputtopology("triangle")]
[numthreads(MESHLET_THREADS_COUNT, 1, 1)]
void main
(
    in uint group_thread_id : SV_GroupIndex,
    in uint group_id : SV_GroupID,
    out vertices VertexAttribute verts[MESHLET_MAX_VERTICES],
    out indices uint3 triangles[MESHLET_MAX_TRIANGLES],
    out primitives PrimitiveAttribute primitives[MESHLET_MAX_TRIANGLES]
)
{
    uint meshlet_index = group_id;
    StructuredBuffer<MeshletCandidate> visible_meshlet_buffer = ResourceDescriptorHeap[g_rasterizer_params.visible_meshlets_buffer_index];
    MeshletCandidate candidate = visible_meshlet_buffer[meshlet_index];
    ByteAddressBuffer instance_buffer = ResourceDescriptorHeap[g_frame.instance_buffer_index];
    Instance instance = instance_buffer.Load<Instance>(candidate.instance_id * sizeof(Instance));
    ByteAddressBuffer mesh_buffer = ResourceDescriptorHeap[g_frame.meshes_buffer_index];
    Mesh mesh = mesh_buffer.Load<Mesh>(instance.mesh_index * sizeof(Mesh));
    ByteAddressBuffer data_buffer = ResourceDescriptorHeap[NonUniformResourceIndex(mesh.data_buffer_index)];
    Meshlet meshlet = data_buffer.Load<Meshlet>(candidate.meshlet_index * sizeof(Meshlet) + mesh.meshlet_offset);

    SetMeshOutputCounts(meshlet.vertex_count, meshlet.triangle_count);

    for (uint i = group_thread_id; i < meshlet.vertex_count; i += MESHLET_THREADS_COUNT)
    {
        uint vertex_id = data_buffer.Load<uint>((i + meshlet.vertex_offset) * sizeof(uint) + mesh.meshlet_vertex_offset);
        VertexAttribute attribute = FetchVertexAttribute(mesh, instance.world, vertex_id);
        verts[i] = attribute;
    }

    for (uint i = group_thread_id; i < meshlet.triangle_count; i += MESHLET_THREADS_COUNT)
    {
        MeshletTriangle tri = data_buffer.Load<MeshletTriangle>((i + meshlet.triangle_offset) * sizeof(MeshletTriangle) + mesh.meshlet_triangle_offset);
        triangles[i] = uint3(tri.v0, tri.v1, tri.v2);

        PrimitiveAttribute attribute;
        attribute.primitive_id = i;
        attribute.candidate_index = meshlet_index;
        primitives[i] = attribute;
    }
}

#endif // MESH_SHADER

#if PIXEL_SHADER

// TODO: Change to Visibility Buffer
struct GBufferOutput
{
    float4 gbuffer0 : SV_TARGET0;
    float4 gbuffer1 : SV_TARGET1;
};

[RootSignature(DefaultRootSignature)]
GBufferOutput pixel(VertexAttribute vertex, PrimitiveAttribute primitive)
{
    StructuredBuffer<MeshletCandidate> visible_meshlet_buffer = ResourceDescriptorHeap[g_rasterizer_params.visible_meshlets_buffer_index];
    MeshletCandidate candidate = visible_meshlet_buffer[primitive.candidate_index];
    ByteAddressBuffer instance_buffer = ResourceDescriptorHeap[g_frame.instance_buffer_index];
    Instance instance = instance_buffer.Load<Instance>(candidate.instance_id * sizeof(Instance));
    ByteAddressBuffer material_buffer = ResourceDescriptorHeap[g_frame.material_buffer_index];
    MaterialData material = material_buffer.Load<MaterialData>(instance.material_index * sizeof(MaterialData));

    GBufferOutput gbuffer_output = (GBufferOutput)0;
    gbuffer_output.gbuffer0 = material.base_color;
    gbuffer_output.gbuffer1 = float4(0.0f, 1.0f, 0.0f, 1.0f);
    return gbuffer_output;
}
#endif // PIXEL_SHADER