
struct BinningParams
{
    uint bins_count;
    uint rw_meshlet_counts_buffer_index;
    uint rw_meshlet_offset_and_counts_buffer_index;
    uint rw_global_meshlet_counter_buffer_index;
    uint rw_binned_meshlets_buffer_index;
    uint rw_dispatch_args_buffer_index;

    uint visible_meshlets_buffer_index;
    uint visible_meshlets_counter_buffer_index;
    uint meshlet_counts_buffer_index;
};

#if PREPARE_ARGS

#include "Defines.hlsli"

cbuffer g_BinningParams : register(b0, SPACE_PerFrame)
{
    BinningParams g_binning_params;
};

uint GetMeshletsCount()
{
	ByteAddressBuffer visible_counters_buffer = ResourceDescriptorHeap[g_binning_params.visible_meshlets_counter_buffer_index];
    return visible_counters_buffer.Load<uint>(0);
}

[RootSignature(ComputeRootSignature)]
[numthreads(1, 1, 1)]
void PrepareArgsCS()
{
	RWByteAddressBuffer meshlet_counts_buffer = ResourceDescriptorHeap[g_binning_params.rw_meshlet_counts_buffer_index];
    for (uint i = 0; i < g_binning_params.bins_count; i++)
    {
        meshlet_counts_buffer.Store<uint>(i * sizeof(uint), 0);
    }

    RWByteAddressBuffer global_meshlet_counts_buffer = ResourceDescriptorHeap[g_binning_params.rw_global_meshlet_counter_buffer_index];
    global_meshlet_counts_buffer.Store<uint>(0, 0);

    uint meshlets_count = GetMeshletsCount();
    uint3 args = uint3((meshlets_count + 64 - 1) / 64, 1, 1);
    RWByteAddressBuffer dispatch_args_buffer = ResourceDescriptorHeap[g_binning_params.rw_dispatch_args_buffer_index];
    dispatch_args_buffer.Store<uint3>(0, args);
}

#endif // PREPARE_ARGS

#if CLASSIFY_MESHLETS

#include "Globals.hlsli"

cbuffer g_BinningParams : register(b1, SPACE_PerFrame)
{
    BinningParams g_binning_params;
};

uint GetMeshletsCount()
{
	ByteAddressBuffer visible_counters_buffer = ResourceDescriptorHeap[g_binning_params.visible_meshlets_counter_buffer_index];
    return visible_counters_buffer.Load<uint>(0);
}

uint GetBin(uint meshlet_index)
{
	ByteAddressBuffer visible_meshlet_buffer = ResourceDescriptorHeap[g_binning_params.visible_meshlets_buffer_index];
    MeshletCandidate candidate = visible_meshlet_buffer.Load<MeshletCandidate>(meshlet_index * sizeof(MeshletCandidate));

    Instance instance = getInstance(candidate.instance_id);
	MaterialData material = getMaterial(instance.material_index);
	return material.rasterizer_bin;
}

[RootSignature(ComputeRootSignature)]
[numthreads(64, 1, 1)]
void ClassifyMeshletsCS(uint thread_id : SV_DispatchThreadID)
{
	uint meshlet_index = thread_id;
    RWByteAddressBuffer meshlet_counts_buffer = ResourceDescriptorHeap[g_binning_params.rw_meshlet_counts_buffer_index];

	if(meshlet_index >= GetMeshletsCount())
		return;

	uint bin = GetBin(meshlet_index);

	// WaveOps optimzed loop to write meshlet indices to its associated bins.
	bool finished = false;
	while(WaveActiveAnyTrue(!finished))
	{
		// Mask out all threads which are already finished
		if(!finished)
		{
			const uint first_bin = WaveReadLaneFirst(bin);
			if(first_bin == bin)
			{
				// Accumulate the meshlet count for all active threads
				uint original_value;
				InterlockedAdd_WaveOps_ByteAddressBuffer(meshlet_counts_buffer, first_bin * sizeof(uint), 1, original_value);
				finished = true;
			}
		}
	}
}

#endif // CLASSIFY_MESHLETS

#if ALLOCATE_BIN_RANGES

#include "Defines.hlsli"

cbuffer g_BinningParams : register(b0, SPACE_PerFrame)
{
    BinningParams g_binning_params;
};

[RootSignature(ComputeRootSignature)]
[numthreads(64, 1, 1)]
void AllocateBinRangesCS(uint thread_id : SV_DispatchThreadID)
{
    ByteAddressBuffer meshlet_counts_buffer = ResourceDescriptorHeap[g_binning_params.meshlet_counts_buffer_index];
    RWByteAddressBuffer global_meshlet_counts_buffer = ResourceDescriptorHeap[g_binning_params.rw_global_meshlet_counter_buffer_index];
    RWByteAddressBuffer meshlet_offset_and_counts_buffer = ResourceDescriptorHeap[g_binning_params.rw_meshlet_offset_and_counts_buffer_index];

    uint bin = thread_id;
	if(bin >= g_binning_params.bins_count)
		return;

	// Compute the amount of meshlets for each bin and prefix sum to get the global index offset
	uint meshlets_count = meshlet_counts_buffer.Load<uint>(bin * sizeof(uint));
	uint offset = WavePrefixSum(meshlets_count);
	uint global_offset;
	if(WaveIsFirstLane())
		global_meshlet_counts_buffer.InterlockedAdd(0, meshlets_count, global_offset);
	offset += WaveReadLaneFirst(global_offset);
	meshlet_offset_and_counts_buffer.Store<uint4>(bin * sizeof(uint4), uint4(0, 1, 1, offset));
}

#endif // ALLOCATE_BIN_RANGES

#if WRITE_BINS

#include "Globals.hlsli"

cbuffer g_BinningParams : register(b1, SPACE_PerFrame)
{
    BinningParams g_binning_params;
};

uint GetMeshletsCount()
{
	ByteAddressBuffer visible_counters_buffer = ResourceDescriptorHeap[g_binning_params.visible_meshlets_counter_buffer_index];
    return visible_counters_buffer.Load<uint>(0);
}

uint GetBin(uint meshlet_index)
{
	ByteAddressBuffer visible_meshlet_buffer = ResourceDescriptorHeap[g_binning_params.visible_meshlets_buffer_index];
    MeshletCandidate candidate = visible_meshlet_buffer.Load<MeshletCandidate>(meshlet_index * sizeof(MeshletCandidate));

    Instance instance = getInstance(candidate.instance_id);
	MaterialData material = getMaterial(instance.material_index);
	return material.rasterizer_bin;
}

[RootSignature(ComputeRootSignature)]
[numthreads(64, 1, 1)]
void WriteBinsCS(uint thread_id : SV_DispatchThreadID)
{
    RWByteAddressBuffer global_meshlet_counts_buffer = ResourceDescriptorHeap[g_binning_params.rw_global_meshlet_counter_buffer_index];
    RWByteAddressBuffer global_meshlet_offset_and_counts_buffer = ResourceDescriptorHeap[g_binning_params.rw_meshlet_offset_and_counts_buffer_index];
    RWByteAddressBuffer binned_meshlets_buffer = ResourceDescriptorHeap[g_binning_params.rw_binned_meshlets_buffer_index];

    uint meshlet_index = thread_id;
	if(meshlet_index >= GetMeshletsCount())
		return;

	uint bin = GetBin(meshlet_index);

	uint offset = global_meshlet_offset_and_counts_buffer.Load<uint4>(bin * sizeof(uint4)).w;
	uint meshlet_offset;

	// WaveOps optimzed loop to write meshlet indices to its associated bins.

	// Loop until all meshlets have their indices written
	bool finished = false;
	while(WaveActiveAnyTrue(!finished))
	{
		// Mask out all threads which are already finished
		if(!finished)
		{
			// Get the bin of the first thread
			const uint first_bin = WaveReadLaneFirst(bin);
			if(first_bin == bin)
			{
				// All threads which have the same bin as the first active lane writes its index
				uint original_value;
				uint count = WaveActiveCountBits(true);
				if(WaveIsFirstLane())
					global_meshlet_offset_and_counts_buffer.InterlockedAdd(first_bin * sizeof(uint4), count, original_value);
				meshlet_offset = WaveReadLaneFirst(original_value) + WavePrefixCountBits(true);
				finished = true;
			}
		}
	}

	binned_meshlets_buffer.Store<uint>((offset + meshlet_offset) * sizeof(uint), meshlet_index);
}

#endif // WRITE_BINS