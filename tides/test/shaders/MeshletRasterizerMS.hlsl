#include "Globals.hlsli"

struct PrimitiveAttribute
{
    uint primitive_id : SV_PrimitiveID;
    uint candidate_index : CANDIDATE_INDEX;
};

struct VertexAttribute
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

struct RasterizerParams
{
    uint bin_index;
    uint visible_meshlets_buffer_index;
    uint binned_meshlets_buffer_index;
    uint meshlet_bin_data_buffer_index;
};

cbuffer g_RasterizerParams : register(b1, SPACE_PerFrame)
{
    RasterizerParams g_rasterizer_params;
};

VertexAttribute FetchVertexAttribute(Mesh mesh, float4x4 world, uint vertex_id)
{
    VertexAttribute attribute = (VertexAttribute)0;
    ByteAddressBuffer data_buffer = ResourceDescriptorHeap[NonUniformResourceIndex(mesh.data_buffer_index)];
    float3 position = data_buffer.Load<float3>(vertex_id * sizeof(float3) + mesh.positions_offset);
    float3 position_ws = mul(float4(position, 1.0f), world).xyz;
    attribute.position = mul(float4(position_ws, 1.0f), g_frame.view_proj);
    float2 uv = data_buffer.Load<float2>(vertex_id * sizeof(float2) + mesh.texcoords_offset);
    attribute.uv = uv;
    return attribute;
}

#if MESH_SHADER

[RootSignature(DefaultRootSignature)]
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
    ByteAddressBuffer meshlet_bin_data_buffer = ResourceDescriptorHeap[g_rasterizer_params.meshlet_bin_data_buffer_index];
    ByteAddressBuffer binned_meshlets_buffer = ResourceDescriptorHeap[g_rasterizer_params.binned_meshlets_buffer_index];
    ByteAddressBuffer visible_meshlet_buffer = ResourceDescriptorHeap[g_rasterizer_params.visible_meshlets_buffer_index];
    ByteAddressBuffer mesh_buffer = ResourceDescriptorHeap[g_frame.meshes_buffer_index];

    uint meshlet_index = group_id;
    meshlet_index += meshlet_bin_data_buffer.Load<uint4>(g_rasterizer_params.bin_index * sizeof(uint4)).w; // Offset
    meshlet_index = binned_meshlets_buffer.Load<uint>(meshlet_index * sizeof(uint));

    MeshletCandidate candidate = visible_meshlet_buffer.Load<MeshletCandidate>(meshlet_index * sizeof(MeshletCandidate));
    Instance instance = getInstance(candidate.instance_id);
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

[RootSignature(DefaultRootSignature)]
uint pixel
(
    VertexAttribute vertex,
    PrimitiveAttribute primitive
) : SV_Target0
{
#if ALPHA_TEST
    ByteAddressBuffer visible_meshlet_buffer = ResourceDescriptorHeap[g_rasterizer_params.visible_meshlets_buffer_index];
    MeshletCandidate candidate = visible_meshlet_buffer.Load<MeshletCandidate>(primitive.candidate_index * sizeof(MeshletCandidate));
    Instance instance = getInstance(candidate.instance_id);
    MaterialData material = getMaterial(instance.material_index);
    if (material.albedo_texture_index != 0xFFFFFFFF) {
        Texture2D<float4> albedo = ResourceDescriptorHeap[NonUniformResourceIndex(material.albedo_texture_index)];
        SamplerState sampler = SamplerDescriptorHeap[g_frame.linear_repeat_sampler_index];
        float4 albedo_sample = albedo.Sample(sampler, vertex.uv);
        if (albedo_sample.a < 0.5) {
            discard;
        }
    }
#endif // ALPHA_TEST

    return PackVisBuffer(primitive.candidate_index, primitive.primitive_id);
}
#endif // PIXEL_SHADER