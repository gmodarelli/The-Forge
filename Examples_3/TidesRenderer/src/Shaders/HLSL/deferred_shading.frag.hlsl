#define DIRECT3D12
#define STAGE_FRAG

#include "../../../../../Common_3/Tools/ForgeShadingLanguage/includes/d3d.h"
#include "pbr.h"

RES(SamplerState, bilinearClampSampler, UPDATE_FREQ_NONE, s0, binding = 1);

RES(Tex2D(float4), gBuffer0, UPDATE_FREQ_NONE, t0, binding = 2);
RES(Tex2D(float4), gBuffer1, UPDATE_FREQ_NONE, t1, binding = 3);
RES(Tex2D(float4), gBuffer2, UPDATE_FREQ_NONE, t2, binding = 4);
RES(Tex2D(float), depthBuffer, UPDATE_FREQ_NONE, t3, binding = 5);

CBUFFER(cbFrame, UPDATE_FREQ_PER_FRAME, b1, binding = 0)
{
	DATA(float4x4, projView, None);
	DATA(float4x4, projViewInverted, None);
	DATA(float4,   camPos,   None);
	DATA(uint,     directionalLightsBufferIndex, None);
	DATA(uint,     pointLightsBufferIndex, None);
	DATA(uint,     directionalLightsCount, None);
	DATA(uint,     pointLightsCount, None);
};

STRUCT(VsOut)
{
	DATA(float4, Position,  SV_Position);
	DATA(float2, UV, TEXCOORD0);
};

STRUCT(PsOut)
{
	DATA(float4, Diffuse,  SV_TARGET0);
	DATA(float4, Specular, SV_TARGET1);
};

float3 getPositionFromDepth(float depth, float2 uv) {
    float x = uv.x * 2.0f - 1.0f;
    float y = (1.0f - uv.y) * 2.0f - 1.0f;
    float4 positionCS = float4(x, y, depth, 1.0f);
    float4 positionWS = mul(Get(projViewInverted), positionCS);
    return positionWS.xyz / positionWS.w;
}

PsOut PS_MAIN( VsOut Input) {
    INIT_MAIN;
    PsOut Out;

    Out.Diffuse = float4(0, 0, 0, 1);
    Out.Specular = float4(0, 0, 0, 1);

    float3 baseColor  = SampleLvlTex2D(Get(gBuffer0), Get(bilinearClampSampler), Input.UV, 0).rgb;
    float3 N = normalize(SampleLvlTex2D(Get(gBuffer1), Get(bilinearClampSampler), Input.UV, 0).rgb * 2.0f - 1.0f);
    float3 armSample = SampleLvlTex2D(Get(gBuffer2), Get(bilinearClampSampler), Input.UV, 0).rgb;
    float depth  = SampleLvlTex2D(Get(depthBuffer), Get(bilinearClampSampler), Input.UV, 0).r;

    const float3 P = getPositionFromDepth(depth, Input.UV);
    const float3 V = normalize(Get(camPos).xyz - P);

    MaterialProperties materialProperties;
    materialProperties.baseColor = baseColor;
    materialProperties.metalness = armSample.b;
    materialProperties.roughness = armSample.g;

	uint i;
	// Point Lights
    // ByteAddressBuffer pointLightsBuffer = ResourceDescriptorHeap[Get(pointLightsBufferIndex)];
	// for (i = 0; i < Get(pointLightsCount); ++i) {
    //     const PointLight pointLight = pointLightsBuffer.Load<PointLight>(i * sizeof(PointLight));
	// 	const float3 Pl = pointLight.positionAndRadius.xyz;
	// 	const float  radius = pointLight.positionAndRadius.w;
	// 	const float3 L = normalize(Pl - P);
	// 	const float  distance = length(Pl - P);
	// 	const float  distanceByRadius = 1.0f - pow((distance / radius), 4);
	// 	const float  clamped = pow(saturate(distanceByRadius), 2.0f);
	// 	const float  attenuation = clamped / (distance * distance + 1.0f);

	// 	const float3 color = pointLight.colorAndIntensity.rgb;
	// 	const float  intensity = pointLight.colorAndIntensity.a;
	// 	const float3 radiance = color * intensity * attenuation;

    //     const BrdfData data = prepareBRDFData(N, L, V, materialProperties);
    //     if (data.Vbackfacing || data.Lbackfacing) continue;

    //     float3 specular = evalMicrofacet(data);
    //     float3 diffuse = evalLambertian(data);

    //     float3 brdf = (float3(1.0f, 1.0f, 1.0f) - data.F) * diffuse + specular;
    //     Lo += brdf * radiance;
	// }

	// Directional Lights
    ByteAddressBuffer directionalLightsBuffer = ResourceDescriptorHeap[Get(directionalLightsBufferIndex)];
	for (i = 0; i < Get(directionalLightsCount); ++i) {
        const DirectionalLight directionalLight = directionalLightsBuffer.Load<DirectionalLight>(i * sizeof(DirectionalLight));
		const float3 L = directionalLight.directionAndShadowMap.xyz;

		const float3 color = directionalLight.colorAndIntensity.rgb;
		const float  intensity = directionalLight.colorAndIntensity.a;
		const float3 radiance = color * intensity;

        const BrdfData data = prepareBRDFData(N, L, V, materialProperties);
        if (data.Vbackfacing || data.Lbackfacing) continue;

        float3 specular = evalMicrofacet(data);
        float3 diffuse = evalLambertian(data);
        Out.Diffuse.rgb += (float3(1.0f, 1.0f, 1.0f) - data.F) * diffuse;
        Out.Specular.rgb += specular;

        // float3 brdf = (float3(1.0f, 1.0f, 1.0f) - data.F) * diffuse + specular;
        // Lo += brdf * radiance;
	}

    // Out.rgb = Lo;

    RETURN(Out);
}
