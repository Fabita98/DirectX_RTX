/***************************************************************************
# Copyright (c) 2018, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
***************************************************************************/
RaytracingAccelerationStructure gRtScene : register(t0);
RWTexture2D<float4> gOutput : register(u0);

cbuffer PerFrame : register(b0)
{
    float3 A;
    float3 B;
    float3 C;
}

float3 linearToSrgb(float3 c)
{
    // Based on http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
    float3 sq1 = sqrt(c);
    float3 sq2 = sqrt(sq1);
    float3 sq3 = sqrt(sq2);
    float3 srgb = 0.662002687 * sq1 + 0.684122060 * sq2 - 0.323583601 * sq3 - 0.0225411470 * c;
    return srgb;
}

struct RayPayload
{
    bool hasTransparency;
    float3 color;
};

[shader("raygeneration")]
void rayGen()
{
    uint3 launchIndex = DispatchRaysIndex();
    uint3 launchDim = DispatchRaysDimensions();

    float2 crd = float2(launchIndex.xy);
    float2 dims = float2(launchDim.xy);

    float2 d = ((crd/dims) * 2.f - 1.f);
    float aspectRatio = dims.x / dims.y;

    RayDesc ray;
    ray.Origin = float3(0, 0, -2.5f);
    ray.Direction = normalize(float3(d.x * aspectRatio, -d.y, 1));

    ray.TMin = 0;
    ray.TMax = 100000;

    RayPayload NoTransPayload;
    NoTransPayload.hasTransparency = false;

    RayPayload transparencyPayload;
    transparencyPayload.hasTransparency = true;
    /* 
    void TraceRay(TLAS SRV,
        uint RayFlags for traversal behavior,
        uint InstanceInclusionMask -> 0xFF = no culling,
        uint RayContributionToHitGroupIndex = rayIndex -> 0 for primary ray and 1 for the shadow one,
        uint MultiplierForGeometryContributionToHitGroupIndex -> GeomIndex is 0 for triangles and 1 for the plane; is the distance in records between geometries, which is 2 (as the ray count)
        uint MissShaderIndex = rayIndex,
        RayDesc Ray,
        inout Payload); 
    */
    TraceRay(gRtScene, 0, 0x80, 0, 2, 0, ray, NoTransPayload);  // 0x80 CULL_NON_OPAQUE -> ray for OPAQUE instances (some triangles + plane); MultiplierForGeometryContributionToHitGroupIndex: affecting only instances with multiple geometries (instance 0)
    float3 col = linearToSrgb(NoTransPayload.color);
    gOutput[launchIndex.xy] = float4(col, 1);
    TraceRay(gRtScene, 0, 0x40, 0, 0, 0, ray, transparencyPayload); // 0x40 CULL_OPAQUE -> ray for NON_OPAQUE instances (only some triangles -> MultiplierForGeometryContributionToHitGroupIndex = 0)
    float3 col1 = linearToSrgb(transparencyPayload.color);
    gOutput[launchIndex.xy] = float4(col1, 1);
}

[shader("miss")]
void miss(inout RayPayload payload)
{
    if (!payload.hasTransparency)
    {
        payload.color = float3(0.4, 0.6, 0.2);
    }
}

[shader("closesthit")]
void triangleChs(inout RayPayload payload, in BuiltInTriangleIntersectionAttributes attribs)
{
    float3 barycentrics = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);
    if(payload.hasTransparency) 
    {
        payload.color = A * (barycentrics.x + 0.65f) + B * (barycentrics.y + 0.65f) + C * (barycentrics.z + 0.65f);
    }
    else 
    {
        payload.color = A * barycentrics.x + B * barycentrics.y + C * barycentrics.z;
    }
}

struct ShadowPayload
{
    bool hit;
};

[shader("closesthit")]
void planeChs(inout RayPayload payload, in BuiltInTriangleIntersectionAttributes attribs)
{
    float  hitT = RayTCurrent(); // parametric distance between ray_origin and intersection_point along ray_dir
    float3 rayDirW = WorldRayDirection(); // world-space dir of incoming ray
    float3 rayOriginW = WorldRayOrigin(); // world-space origin of incoming ray
    // Find the world-space hit position
    float3 posW = rayOriginW + hitT * rayDirW;

    // Fire a shadow ray. The direction is hard-coded here, but can be fetched from a constant-buffer
    RayDesc ray;
    ray.Origin = posW;
    ray.Direction = normalize(float3(0.5, 0.5, -0.5));
    ray.TMin = 0.01;
    ray.TMax = 100000;
    ShadowPayload shadowPayload;
    // this time RayContributionToHitGroupIndex and MissShaderIndex set to 1 because of shadow ray type
    TraceRay(gRtScene, 0, 0xFF, 1, 0, 1, ray, shadowPayload);
    float factor = shadowPayload.hit ? 0.1 : 1.0;
    payload.color = float4(0.7f, 0.7f, 0.7f, 1.0f) * factor;
}

[shader("closesthit")]
void shadowChs(inout ShadowPayload payload, in BuiltInTriangleIntersectionAttributes attribs)
{
    payload.hit = true;
}

[shader("miss")]
void shadowMiss(inout ShadowPayload payload)
{
    payload.hit = false;
}
