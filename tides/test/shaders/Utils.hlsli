#ifndef _UTILS_HLSLI
#define _UTILS_HLSLI

float3 UnpackNormals(float2 uv, float3 view, float3 tangent_normal, float3 normal)
{
	float3 dPdx = ddx(view);
	float3 dPdy = ddy(view);
	float2 dUVdx = ddx(uv);
	float2 dUVdy = ddy(uv);

	float3 N = normalize(normal);
	float3 cross_PdyN = cross(dPdy, N);
	float3 cross_NPdx = cross(N, dPdx);

	float3 T = cross_PdyN * dUVdx.x + cross_NPdx * dUVdy.x;
	float3 B = cross_PdyN * dUVdx.y + cross_NPdx * dUVdy.y;

	float inv_scale = rsqrt(max(0.0001f, max(dot(T, T), dot(B, B))));

	float3x3 TBN = float3x3(T * inv_scale, B * inv_scale, N);
	return normalize(mul(tangent_normal, TBN));
}


#endif // _UTILS_HLSLI