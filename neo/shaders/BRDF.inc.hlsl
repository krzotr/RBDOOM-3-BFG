/*
===========================================================================

Doom 3 BFG Edition GPL Source Code
Copyright (C) 2014-2020 Robert Beckebans

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

// Normal Distribution Function ( NDF ) or D( h )
// GGX ( Trowbridge-Reitz )
half Distribution_GGX( half hdotN, half alpha )
{
	// alpha is assumed to be roughness^2
	float a2 = alpha * alpha;
	//float tmp = ( hdotN * hdotN ) * ( a2 - 1.0 ) + 1.0;
	float tmp = ( hdotN * a2 - hdotN ) * hdotN + 1.0;

	return ( a2 / ( PI * tmp * tmp ) );
}

half Distribution_GGX_Disney( half hdotN, half alphaG )
{
	float a2 = alphaG * alphaG;
	float tmp = ( hdotN * hdotN ) * ( a2 - 1.0 ) + 1.0;
	//tmp *= tmp;

	return ( a2 / ( PI * tmp ) );
}

half Distribution_GGX_1886( half hdotN, half alpha )
{
	// alpha is assumed to be roughness^2
	return ( alpha / ( PI * pow( hdotN * hdotN * ( alpha - 1.0 ) + 1.0, 2.0 ) ) );
}

// Fresnel term F( v, h )
// Fnone( v, h ) = F(0) = specularColor
half3 Fresnel_Schlick( half3 specularColor, half vDotN )
{
	return specularColor + ( 1.0 - specularColor ) * pow( 1.0 - vDotN, 5.0 );
}

// Fresnel term that takes roughness into account so rough non-metal surfaces aren't too shiny [Lagarde11]
half3 Fresnel_SchlickRoughness( half3 specularColor, half vDotN, half roughness )
{
	float oneMinusRoughness = 1.0 - roughness;
	return specularColor + ( max( half3( oneMinusRoughness, oneMinusRoughness, oneMinusRoughness ), specularColor ) - specularColor ) * pow( 1.0 - vDotN, 5.0 );
}

// Sebastien Lagarde proposes an empirical approach to derive the specular occlusion term from the diffuse occlusion term in [Lagarde14].
// The result does not have any physical basis but produces visually pleasant results.
// See Sebastien Lagarde and Charles de Rousiers. 2014. Moving Frostbite to PBR.
float ComputeSpecularAO( float vDotN, float ao, float roughness )
{
	return clamp( pow( vDotN + ao, exp2( -16.0 * roughness - 1.0 ) ) - 1.0 + ao, 0.0, 1.0 );
}

// Visibility term G( l, v, h )
// Very similar to Marmoset Toolbag 2 and gives almost the same results as Smith GGX
float Visibility_Schlick( half vdotN, half ldotN, float alpha )
{
	float k = alpha * 0.5;

	float schlickL = ( ldotN * ( 1.0 - k ) + k );
	float schlickV = ( vdotN * ( 1.0 - k ) + k );

	return ( 0.25 / ( schlickL * schlickV ) );
	//return ( ( schlickL * schlickV ) / ( 4.0 * vdotN * ldotN ) );
}

// see s2013_pbs_rad_notes.pdf
// Crafting a Next-Gen Material Pipeline for The Order: 1886
// this visibility function also provides some sort of back lighting
float Visibility_SmithGGX( half vdotN, half ldotN, float alpha )
{
	// alpha is already roughness^2

	float V1 = ldotN + sqrt( alpha + ( 1.0 - alpha ) * ldotN * ldotN );
	float V2 = vdotN + sqrt( alpha + ( 1.0 - alpha ) * vdotN * vdotN );

	// RB: avoid too bright spots
	return ( 1.0 / max( V1 * V2, 0.15 ) );
}

// RB: HACK calculate roughness from D3 gloss maps
float EstimateLegacyRoughness( float3 specMapSRGB )
{
	float Y = dot( LUMINANCE_SRGB.rgb, specMapSRGB );

	//float glossiness = clamp( 1.0 - specMapSRGB.r, 0.0, 0.98 );
	float glossiness = clamp( pow( Y, 1.0 / 2.0 ), 0.0, 0.98 );

	float roughness = 1.0 - glossiness;

	return roughness;
}

#define KENNY_PBR 1

// Kennedith98 begin
// takes a gamma-space specular texture
// outputs F0 color and roughness for PBR
void PBRFromSpecmap( float3 specMap, out float3 F0, out float roughness )
{
	// desaturate specular
	float specLum = max( specMap.r, max( specMap.g, specMap.b ) );

	// fresnel base
	F0 = _float3( 0.04 );

	// fresnel contrast (will tighten low spec and broaden high spec, stops specular looking too flat or shiny)
	float contrastMid = 0.214;
	float contrastAmount = 2.0;
	float contrast = saturate( ( specLum - contrastMid ) / ( 1 - contrastMid ) ); //high spec
	contrast += saturate( specLum / contrastMid ) - 1.0; //low spec
	contrast = exp2( contrastAmount * contrast );
	F0 *= contrast;

	// reverse blinn BRDF to perfectly match vanilla specular brightness
	// fresnel is affected when specPow is 0, experimentation is desmos showed that happens at F0/4
	float linearBrightness = Linear1( 2.0 * specLum );
	float specPow = max( 0.0, ( ( 8 * linearBrightness ) / F0.y ) - 2.0 );
	F0 *= min( 1.0, linearBrightness / ( F0.y * 0.25 ) );

	// specular power to roughness
	roughness = sqrt( 2.0 / ( specPow + 2.0 ) );

	// RB: do another sqrt because PBR shader squares it
	roughness = sqrt( roughness );
}

// takes roughness, unnormalized 0-1 normalmap texture and the distance to the camera
// returns roughness
float ApplySpecularAA( float roughness, float3 bumpMap, float camDist )
{
	float normLen = saturate( length( bumpMap.xyz * 2.0 - 1.0 ) );

	// roughness to specular power
	float specPow = ( 2.0 / ( roughness * roughness ) ) - 2.0;

	// toksvig AA to prevent speckles from sharp normal edges
	float specAA = 1.0 / ( 1.0 + specPow * ( ( 1.0 / normLen ) - 1.0 ) );

	// fade out AA close to the camera to prevent dull highlights close up
	float distMax = 100.0;
	float disMin = 1.0;
	specAA = lerp( specAA, 1.0, smoothstep( disMin, distMax, camDist ) );

	//apply AA
	specPow *= specAA;

	// specular power to roughness
	roughness = sqrt( 2.0 / ( specPow + 2.0 ) );

	return roughness;
}
// Kennedith98 end

// Environment BRDF approximations
// see s2013_pbs_black_ops_2_notes.pdf
/*
half a1vf( half g )
{
	return ( 0.25 * g + 0.75 );
}

half a004( half g, half vdotN )
{
	float t = min( 0.475 * g, exp2( -9.28 * vdotN ) );
	return ( t + 0.0275 ) * g + 0.015;
}

half a0r( half g, half vdotN )
{
	return ( ( a004( g, vdotN ) - a1vf( g ) * 0.04 ) / 0.96 );
}

float3 EnvironmentBRDF( half g, half vdotN, float3 rf0 )
{
	float4 t = float4( 1.0 / 0.96, 0.475, ( 0.0275 - 0.25 * 0.04 ) / 0.96, 0.25 );
	t *= float4( g, g, g, g );
	t += float4( 0.0, 0.0, ( 0.015 - 0.75 * 0.04 ) / 0.96, 0.75 );
	half a0 = t.x * min( t.y, exp2( -9.28 * vdotN ) ) + t.z;
	half a1 = t.w;

	return saturate( a0 + rf0 * ( a1 - a0 ) );
}


half3 EnvironmentBRDFApprox( half roughness, half vdotN, half3 specularColor )
{
	const half4 c0 = half4( -1, -0.0275, -0.572, 0.022 );
	const half4 c1 = half4( 1, 0.0425, 1.04, -0.04 );

	half4 r = roughness * c0 + c1;
	half a004 = min( r.x * r.x, exp2( -9.28 * vdotN ) ) * r.x + r.y;
	half2 AB = half2( -1.04, 1.04 ) * a004 + r.zw;

	return specularColor * AB.x + AB.y;
}
*/



