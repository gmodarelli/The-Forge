#ifndef _PBR_H
#define _PBR_H

float3 ReconstructNormal(float4 sampleNormal, float intensity) {
	float3 tangentNormal;
	tangentNormal.xy = (sampleNormal.rg * 2 - 1) * intensity;
	tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
	return tangentNormal;
}

INLINE float3 UnpackNormals(float2 uv, float3 viewDirection, Tex2D(float4) normalMap, SamplerState samplerState, float3 normal, float intensity) {
	float3 tangentNormal = ReconstructNormal(SampleTex2D(normalMap, samplerState, uv), intensity);

	float3 dPdx = ddx(viewDirection);
	float3 dPdy = ddy(viewDirection);
	float2 dUVdx = ddx(uv);
	float2 dUVdy = ddy(uv);

	float3 N = normalize(normal);
	float3 crossPdyN = cross(dPdy, N);
	float3 crossNPdx = cross(N, dPdx); 

	float3 T = crossPdyN * dUVdx.x + crossNPdx * dUVdy.x;
	float3 B = crossPdyN * dUVdx.y + crossNPdx * dUVdy.y;

	float invScale = rsqrt(max(dot(T, T), dot(B, B)));

	float3x3 TBN = make_f3x3_rows(T * invScale, B * invScale, N);
	return normalize(mul(tangentNormal, TBN));
}

struct PointLight
{
	float4 positionAndRadius;
	float4 colorAndIntensity;
};

struct DirectionalLight
{
	float4 directionAndShadowMap;
	float4 colorAndIntensity;
	float shadowRange;
	float _pad0;
	float _pad1;
	int shadowMapDimensions;
	float4x4 viewProj;
};

// Crash course in BRDF Implementation
// ===================================

// PIs
#ifndef PI
#define PI 3.141592653589f
#endif

#ifndef TWO_PI
#define TWO_PI (2.0f * PI)
#endif

#ifndef ONE_OVER_PI
#define ONE_OVER_PI (1.0f / PI)
#endif

#ifndef ONE_OVER_TWO_PI
#define ONE_OVER_TWO_PI (1.0f / TWO_PI)
#endif

#define MIN_DIELECTRICS_F0 0.04f

struct MaterialProperties
{
    float3 baseColor;
    float metalness;

    float roughness;
};

struct BrdfData
{
    // Material properties
    float3 specularF0;
    float3 diffuseReflectance;

    // Roughnesses
    float roughness;        // perceptively linear roughness (artist's input)
    float alpha;            // linear roughness - often 'alpha' in specular BRDF equations
    float alphaSquared;     // alpha squared - pre-calculated value commonly used in BRDF equations

    // Commonly used terms for BRDF evaluation
    float3 F;               // Fresnel term

    // Vectors
    float3 V;               // Direction to viewer (or opposite direction of incident ray)
    float3 N;               // Shading normal
    float3 H;               // Half vector (microfacet normal)
    float3 L;               // Direction to light (or direction of reflected ray)

    float NdotL;
    float NdotV;

    float LdotH;
    float NdotH;
    float VdotH;

    // True when V/L is backfacing wrt. shading normal N
    bool Vbackfacing;
    bool Lbackfacing;
};


// ----------------------------------------
//      Utilities
// ----------------------------------------

float3 baseColorToSpecularF0(const float3 baseColor, const float metalness) {
    const float minDielectricsF0 = MIN_DIELECTRICS_F0;
    return lerp(float3(minDielectricsF0, minDielectricsF0, minDielectricsF0), baseColor, metalness);
}

float3 baseColorToDiffuseReflectance(float3 baseColor, float metalness) {
    return baseColor * (1.0f - metalness);
}

float luminance(float3 rgb) {
	return dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
}

// ----------------------------------------
//      Lambert
// ----------------------------------------

float3 evalLambertian(const BrdfData data) {
    return data.diffuseReflectance * (ONE_OVER_PI * data.NdotL);
};

// ----------------------------------------
//      Normal Distribution Functions
// ----------------------------------------

float GGX_D(float alphaSquared, float NdotH) {
	float b = ((alphaSquared - 1.0f) * NdotH * NdotH + 1.0f);
	return alphaSquared / (PI * b * b);
}

// ----------------------------------------
//      Smith G Term
// ----------------------------------------

// Smith G2 term (masking-shadowing function) for GGX distribution
// Height correlated version - optimized by substituing G_Lambda for G_Lambda_GGX and dividing by (4 * NdotL * NdotV) to cancel out 
// the terms in specular BRDF denominator
// Source: "Moving Frostbite to Physically Based Rendering" by Lagarde & de Rousiers
// Note that returned value is G2 / (4 * NdotL * NdotV) and therefore includes division by specular BRDF denominator
float Smith_G2_Height_Correlated_GGX_Lagarde(float alphaSquared, float NdotL, float NdotV) {
	float a = NdotV * sqrt(alphaSquared + NdotL * (NdotL - alphaSquared * NdotL));
	float b = NdotL * sqrt(alphaSquared + NdotV * (NdotV - alphaSquared * NdotV));
	return 0.5f / (a + b);
}

// ----------------------------------------
//      Fresnel
// ----------------------------------------

// Schlick's approximation to Fresnel term
// f90 should be 1.0, except for the trick used by Schuler (see 'shadowedF90' function)
float3 evalFresnelSchlick(float3 f0, float f90, float NdotS) {
	return f0 + (f90 - f0) * pow(1.0f - NdotS, 5.0f);
}

// Attenuates F90 for very low F0 values
// Source: "An efficient and Physically Plausible Real-Time Shading Model" in ShaderX7 by Schuler
// Also see section "Overbright highlights" in Hoffman's 2010 "Crafting Physically Motivated Shading Models for Game Development" for discussion
// IMPORTANT: Note that when F0 is calculated using metalness, it's value is never less than MIN_DIELECTRICS_F0, and therefore,
// this adjustment has no effect. To be effective, F0 must be authored separately, or calculated in different way. See main text for discussion.
float shadowedF90(float3 F0) {
	// This scaler value is somewhat arbitrary, Schuler used 60 in his article. In here, we derive it from MIN_DIELECTRICS_F0 so
	// that it takes effect for any reflectance lower than least reflective dielectrics
	//const float t = 60.0f;
	const float t = (1.0f / MIN_DIELECTRICS_F0);
	return min(1.0f, t * luminance(F0));
}

float3 evalMicrofacet(const BrdfData data) {
    float D = GGX_D(max(0.00001f, data.alphaSquared), data.NdotH);
    float G2 = Smith_G2_Height_Correlated_GGX_Lagarde(data.alphaSquared, data.NdotL, data.NdotV);

    return data.F * (G2 * D * data.NdotL);
}

BrdfData prepareBRDFData(float3 N, float3 L, float3 V, MaterialProperties material) {
    BrdfData data;

    // Evaluate VNHL vectors
    data.V = V;
    data.N = N;
    data.H = normalize(L + V);
    data.L = L;

    float NdotL = dot(N, L);
    float NdotV = dot(N, V);
    data.Vbackfacing = (NdotV <= 0.0f);
    data.Lbackfacing = (NdotL <= 0.0f);

    // Clamp Ndot'S to prevent numerical instability. Assume vectors below the hemisphere will be filtered using 'Vbackfacing' and 'Lbackfacing' flags
    data.NdotL = min(max(0.00001f, NdotL), 1.0f);
    data.NdotV = min(max(0.00001f, NdotV), 1.0f);

    data.LdotH = saturate(dot(L, data.H));
    data.NdotH = saturate(dot(N, data.H));
    data.VdotH = saturate(dot(V, data.H));

    // Unpack material properties
    data.specularF0 = baseColorToSpecularF0(material.baseColor, material.metalness);
    data.diffuseReflectance = baseColorToDiffuseReflectance(material.baseColor, material.metalness);

    // Unpack 'perceptively linear' -> 'linear' -> 'squared' roughness
    data.roughness = material.roughness;
    data.alpha = material.roughness * material.roughness;
    data.alphaSquared = data.alpha * data.alpha;

    // Pre-calculate some more BRDF terms
    data.F = evalFresnelSchlick(data.specularF0, shadowedF90(data.specularF0), data.LdotH);

    return data;
};

#endif // _PBR_H