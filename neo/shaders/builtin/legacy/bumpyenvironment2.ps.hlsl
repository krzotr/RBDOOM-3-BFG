/*
===========================================================================

Doom 3 BFG Edition GPL Source Code
Copyright (C) 1993-2012 id Software LLC, a ZeniMax Media company.
Copyright (C) 2024 Robert Beckebans

This file is part of the Doom 3 BFG Edition GPL Source Code ("Doom 3 BFG Edition Source Code").

Doom 3 BFG Edition Source Code is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Doom 3 BFG Edition Source Code is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Doom 3 BFG Edition Source Code.  If not, see <http://www.gnu.org/licenses/>.

In addition, the Doom 3 BFG Edition Source Code is also subject to certain additional terms. You should have received a copy of these additional terms immediately following the terms and conditions of the GNU General Public License which accompanied the Doom 3 BFG Edition Source Code.  If not, please request a copy in writing from id Software at the address below.

If you have questions concerning this license or the applicable additional terms, you may contact in writing id Software LLC, c/o ZeniMax Media Inc., Suite 120, Rockville, Maryland 20850 USA.

===========================================================================
*/

#include "global_inc.hlsl"


// *INDENT-OFF*
Texture2D t_NormalMap			: register( t0 VK_DESCRIPTOR_SET( 1 ) );
Texture2D t_RadianceCubeMap1	: register( t1 VK_DESCRIPTOR_SET( 1 ) );
Texture2D t_RadianceCubeMap2	: register( t2 VK_DESCRIPTOR_SET( 1 ) );
Texture2D t_RadianceCubeMap3	: register( t3 VK_DESCRIPTOR_SET( 1 ) );
Texture2D t_Depth				: register( t4 VK_DESCRIPTOR_SET( 1 ) );

SamplerState s_Material			: register( s0 VK_DESCRIPTOR_SET( 2 ) );
SamplerState s_LinearClamp		: register( s1 VK_DESCRIPTOR_SET( 2 ) );

struct PS_IN 
{
	float4 position		: SV_Position;
	float2 texcoord0	: TEXCOORD0_centroid;
	float3 texcoord1	: TEXCOORD1_centroid;
	float3 texcoord2	: TEXCOORD2_centroid;
	float3 texcoord3	: TEXCOORD3_centroid;
	float3 texcoord4	: TEXCOORD4_centroid;
	float4 texcoord5	: TEXCOORD5_centroid;
	float4 color		: COLOR0;
};

struct PS_OUT
{
	float4 color : SV_Target0;
};
// *INDENT-ON*


#if 0
float linearDepthTexelFetch( int2 hitPixel )
{
	// Load returns 0 for any value accessed out of bounds
	return linearizeDepth( t_Depth.Load( int3( hitPixel, 0 ) ).r );
}

// can be either view space or world space depending on rpModelMatrix
float3 ReconstructPosition( float2 S, float depth )
{
	// derive clip space from the depth buffer and screen position
	float2 uv = S * rpWindowCoord.xy;
	float3 ndc = float3( uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, depth );
	float clipW = -rpProjectionMatrixZ.w / ( -rpProjectionMatrixZ.z - ndc.z );

	float4 clip = float4( ndc * clipW, clipW );

	// camera space position
	float4 csP;
	csP.x = dot4( rpModelMatrixX, clip );
	csP.y = dot4( rpModelMatrixY, clip );
	csP.z = dot4( rpModelMatrixZ, clip );
	csP.w = dot4( rpModelMatrixW, clip );

	csP.xyz /= csP.w;

	return csP.xyz;
}

/*
float3 GetPosition( int2 ssP )
{
	float depth = texelFetch( t_Depth, ssP, 0 ).r;

	// offset to pixel center
	float3 P = ReconstructPosition( float2( ssP ) + _float2( 0.5 ), depth );

	return P;
}
*/

float distanceSquared( float2 a, float2 b )
{
	a -= b;
	return dot( a, a );
}

void swap( inout float a, inout float b )
{
	float t = a;
	a = b;
	b = t;
}

#if 0
bool intersectsDepthBuffer( float z, float minZ, float maxZ )
{
	/*
	 * Based on how far away from the camera the depth is,
	 * adding a bit of extra thickness can help improve some
	 * artifacts. Driving this value up too high can cause
	 * artifacts of its own.
	 */
	float depthScale = min( 1.0f, z * cb_strideZCutoff );
	z += cb_zThickness + lerp( 0.0f, 2.0f, depthScale );
	return ( maxZ >= z ) && ( minZ - cb_zThickness <= z );
}
#endif

// By Morgan McGuire and Michael Mara at Williams College 2014
// Released as open source under the BSD 2-Clause License
// http://opensource.org/licenses/BSD-2-Clause

// Returns true if the ray hit something
bool TraceScreenSpaceRay(
	// Camera-space ray origin, which must be within the view volume
	float3 csOrig,

	// Unit length camera-space ray direction
	float3 csDir,

	// Camera space thickness to ascribe to each pixel in the depth buffer
	float zThickness,

	// Stride samples trades quality for performance
	float stride,

	// Number between 0 and 1 for how far to bump the ray in stride units
	// to conceal banding artifacts. Not needed if stride == 1.
	float jitter,

	// Maximum number of iterations. Higher gives better images but may be slow
	const float maxSteps,

	// Pixel coordinates of the first intersection with the scene
	out float2 hitPixel,

	// Camera space location of the ray hit
	out float3 hitPoint )
{
	// Clip to the near plane
	//float rayLength = ( ( csOrig.z + csDir.z * cb_maxDistance ) < cb_nearPlaneZ ) ?
	//				  ( cb_nearPlaneZ - csOrig.z ) / csDir.z : cb_maxDistance;

	float rayLength = 10000;
	float3 csEndPoint = csOrig + csDir * rayLength;

	// Project into homogeneous clip space
	//float4 H0 = mul( float4( csOrig, 1.0f ), viewToTextureSpaceMatrix );

	float4 csPos = float4( csOrig, 1.0 );
	float4 H0;
	H0.x = dot4( csPos, rpProjectionMatrixX );
	H0.y = dot4( csPos, rpProjectionMatrixY );
	H0.z = dot4( csPos, rpProjectionMatrixZ );
	H0.w = dot4( csPos, rpProjectionMatrixW );
	H0.xy *= rpWindowCoord.zw;

	//float4 H1 = mul( float4( csEndPoint, 1.0f ), viewToTextureSpaceMatrix );
	float4 H1;
	H1.x = dot4( csPos, rpProjectionMatrixX );
	H1.y = dot4( csPos, rpProjectionMatrixY );
	H1.z = dot4( csPos, rpProjectionMatrixZ );
	H1.w = dot4( csPos, rpProjectionMatrixW );
	H1.xy *= rpWindowCoord.zw;

	float k0 = 1.0f / H0.w;
	float k1 = 1.0f / H1.w;

	// The interpolated homogeneous version of the camera-space points
	float3 Q0 = csOrig * k0;
	float3 Q1 = csEndPoint * k1;

	// Screen-space endpoints
	float2 P0 = H0.xy * k0;
	float2 P1 = H1.xy * k1;

	// If the line is degenerate, make it cover at least one pixel
	// to avoid handling zero-pixel extent as a special case later
	P1 += ( distanceSquared( P0, P1 ) < 0.0001f ) ? float2( 0.01f, 0.01f ) : 0.0f;
	float2 delta = P1 - P0;

	// Permute so that the primary iteration is in x to collapse
	// all quadrant-specific DDA cases later
	bool permute = false;
	if( abs( delta.x ) < abs( delta.y ) )
	{
		// This is a more-vertical line
		permute = true;
		delta = delta.yx;
		P0 = P0.yx;
		P1 = P1.yx;
	}

	float stepDir = sign( delta.x );
	float invdx = stepDir / delta.x;

	// Track the derivatives of Q and k
	float3 dQ = ( Q1 - Q0 ) * invdx;
	float dk = ( k1 - k0 ) * invdx;
	float2 dP = float2( stepDir, delta.y * invdx );

	// Scale derivatives by the desired pixel stride and then
	// offset the starting values by the jitter fraction
	//float strideScale = 1.0f - min( 1.0f, csOrig.z * cb_strideZCutoff );
	//float stride = 1.0f + strideScale * cb_stride;
	dP *= stride;
	dQ *= stride;
	dk *= stride;

	P0 += dP * jitter;
	Q0 += dQ * jitter;
	k0 += dk * jitter;

	// Slide P from P0 to P1, (now-homogeneous) Q from Q0 to Q1, k from k0 to k1
	float4 PQk = float4( P0, Q0.z, k0 );
	float4 dPQk = float4( dP, dQ.z, dk );
	float3 Q = Q0;

	// Adjust end condition for iteration direction
	float end = P1.x * stepDir;

	float stepCount = 0.0f;
	float prevZMaxEstimate = csOrig.z;
	float rayZMin = prevZMaxEstimate;
	float rayZMax = prevZMaxEstimate;
	float sceneZMax = rayZMax + 100.0f;
	for( ;
			( ( PQk.x * stepDir ) <= end ) && ( stepCount < maxSteps ) &&
			//!intersectsDepthBuffer( sceneZMax, rayZMin, rayZMax ) &&
			( ( rayZMax < sceneZMax - zThickness ) || ( rayZMin > sceneZMax ) ) &&
			( sceneZMax != 0.0f );
			++stepCount )
	{
		rayZMin = prevZMaxEstimate;
		rayZMax = ( dPQk.z * 0.5f + PQk.z ) / ( dPQk.w * 0.5f + PQk.w );
		prevZMaxEstimate = rayZMax;
		if( rayZMin > rayZMax )
		{
			swap( rayZMin, rayZMax );
		}

		hitPixel = permute ? PQk.yx : PQk.xy;
		// You may need hitPixel.y = depthBufferSize.y - hitPixel.y; here if your vertical axis
		// is different than ours in screen space
		sceneZMax = linearDepthTexelFetch( int2( hitPixel ) );

		PQk += dPQk;
	}

	// Advance Q based on the number of steps
	Q.xy += dQ.xy * stepCount;
	hitPoint = Q * ( 1.0f / PQk.w );
	return intersectsDepthBuffer( sceneZMax, rayZMin, rayZMax );
}
#endif


float2 GetSampleVector( float3 reflectionVector )
{
	float2 normalizedOctCoord = octEncode( reflectionVector );
	float2 normalizedOctCoordZeroOne = ( normalizedOctCoord + _float2( 1.0 ) ) * 0.5;

	return normalizedOctCoordZeroOne;
}

void main( PS_IN fragment, out PS_OUT result )
{
	float4 bump = t_NormalMap.Sample( s_Material, fragment.texcoord0 ) * 2.0f - 1.0f;

	// RB begin
	float3 localNormal;
#if defined(USE_NORMAL_FMT_RGB8)
	localNormal = float3( bump.rg, 0.0f );
#else
	localNormal = float3( bump.wy, 0.0f );
#endif
	// RB end
	localNormal.z = sqrt( 1.0f - dot3( localNormal, localNormal ) );

	float3 globalNormal;
	globalNormal.x = dot3( localNormal, fragment.texcoord2 );
	globalNormal.y = dot3( localNormal, fragment.texcoord3 );
	globalNormal.z = dot3( localNormal, fragment.texcoord4 );

	float3 globalPosition = fragment.texcoord5.xyz;

	float3 globalView = normalize( globalPosition - rpGlobalEyePos.xyz );

	float3 reflectionVector = reflect( globalView, globalNormal );

	float2 octCoord0 = GetSampleVector( reflectionVector );
	float2 octCoord1 = octCoord0;
	float2 octCoord2 = octCoord0;

#if 1
	// parallax box correction using portal area bounds
	float hitScale = 0.0;
	float3 bounds[2];
	bounds[0].x = rpWobbleSkyX.x;
	bounds[0].y = rpWobbleSkyX.y;
	bounds[0].z = rpWobbleSkyX.z;

	bounds[1].x = rpWobbleSkyY.x;
	bounds[1].y = rpWobbleSkyY.y;
	bounds[1].z = rpWobbleSkyY.z;

	// global fragment position
	float3 rayStart = globalPosition;

	// we can't start inside the box so move this outside and use the reverse path
	rayStart += reflectionVector * 10000.0;

	// only do a box <-> ray intersection test if we use a local cubemap
	if( ( rpWobbleSkyX.w > 0.0 ) && AABBRayIntersection( bounds, rayStart, -reflectionVector, hitScale ) )
	{
		float3 hitPoint = rayStart - reflectionVector * hitScale;

		// rpWobbleSkyZ is cubemap center
#if 1
		reflectionVector = hitPoint - rpWobbleSkyZ.xyz;
		octCoord0 = octCoord1 = octCoord2 = GetSampleVector( reflectionVector );
#else
		// this should look better but only works in the case all 3 probes are in this area bbox
		octCoord0 = GetSampleVector( hitPoint - rpTexGen0S.xyz );
		octCoord1 = GetSampleVector( hitPoint - rpTexGen0T.xyz );
		octCoord2 = GetSampleVector( hitPoint - rpTexGen0Q.xyz );
#endif
	}
#endif

	const float mip = 0;
	float3 radiance = t_RadianceCubeMap1.SampleLevel( s_LinearClamp, octCoord0, mip ).rgb * rpLocalLightOrigin.x;
	radiance += t_RadianceCubeMap2.SampleLevel( s_LinearClamp, octCoord1, mip ).rgb * rpLocalLightOrigin.y;
	radiance += t_RadianceCubeMap3.SampleLevel( s_LinearClamp, octCoord2, mip ).rgb * rpLocalLightOrigin.z;

	// give it a red blood tint
	//radiance *= float3( 0.5, 0.25, 0.25 );

	// make this really dark although it is already in linear RGB
	radiance = sRGBToLinearRGB( radiance.xyz );

	result.color = float4( radiance, 1.0f ) * fragment.color;
}
