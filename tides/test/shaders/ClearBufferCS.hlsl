#include "Defines.hlsli"

struct ClearBufferInput
{
    uint element_count;
    uint buffer_index;
};

cbuffer g_CBO : register(b0, SPACE_PerFrame)
{
    ClearBufferInput g_clear_buffer_input;
};

[RootSignature(ComputeRootSignature)]
[numthreads(64, 1, 1)]
void main(uint3 DTid : SV_DispatchThreadID)
{
    RWByteAddressBuffer buffer = ResourceDescriptorHeap[g_clear_buffer_input.buffer_index];

    if (DTid.x < g_clear_buffer_input.element_count)
    {
        buffer.Store<uint>(DTid.x * sizeof(uint), 0);
    }
}