/*
===========================================================================

Doom 3 BFG Edition GPL Source Code
Copyright (C) 1993-2012 id Software LLC, a ZeniMax Media company.
Copyright (C) 2013 Robert Beckebans

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

#if 0
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
	float3 rayStart = fragment.texcoord7.xyz;

	// we can't start inside the box so move this outside and use the reverse path
	rayStart += reflectionVector * 10000.0;

	// only do a box <-> ray intersection test if we use a local cubemap
	if( ( rpWobbleSkyX.w > 0.0 ) && AABBRayIntersection( bounds, rayStart, -reflectionVector, hitScale ) )
	{
		float3 hitPoint = rayStart - reflectionVector * hitScale;

		// rpWobbleSkyZ is cubemap center
		reflectionVector = hitPoint - rpWobbleSkyZ.xyz;
	}
#endif

	//float4 envMap = t_CubeMap.Sample( samp0, reflectionVector );

	float2 normalizedOctCoord = octEncode( reflectionVector );
	float2 normalizedOctCoordZeroOne = ( normalizedOctCoord + _float2( 1.0 ) ) * 0.5;

	const float mip = 0;
	float3 radiance = t_RadianceCubeMap1.SampleLevel( s_LinearClamp, normalizedOctCoordZeroOne, mip ).rgb * rpLocalLightOrigin.x;
	radiance += t_RadianceCubeMap2.SampleLevel( s_LinearClamp, normalizedOctCoordZeroOne, mip ).rgb * rpLocalLightOrigin.y;
	radiance += t_RadianceCubeMap3.SampleLevel( s_LinearClamp, normalizedOctCoordZeroOne, mip ).rgb * rpLocalLightOrigin.z;

	result.color = float4( sRGBToLinearRGB( radiance.xyz ), 1.0f ) * fragment.color;
}
