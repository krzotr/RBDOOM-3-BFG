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
Texture2D t_BaseColor	: register( t0 VK_DESCRIPTOR_SET( 0 ) );
Texture2D t_BlueNoise	: register( t1 VK_DESCRIPTOR_SET( 0 ) );

SamplerState s_LinearClamp	: register(s0 VK_DESCRIPTOR_SET( 1 ) );
SamplerState s_LinearWrap	: register(s1 VK_DESCRIPTOR_SET( 1 ) ); // blue noise 256

struct PS_IN
{
	float4 position : SV_Position;
	float2 texcoord0 : TEXCOORD0_centroid;
};

struct PS_OUT
{
	float4 color : SV_Target0;
};
// *INDENT-ON*


#define RESOLUTION_DIVISOR 4.0
#define NUM_COLORS 64 // original 61


float3 Average( float3 pal[NUM_COLORS] )
{
	float3 sum = _float3( 0 );

	for( int i = 0; i < NUM_COLORS; i++ )
	{
		sum += pal[i];
	}

	return sum / float( NUM_COLORS );
}

float3 Deviation( float3 pal[NUM_COLORS] )
{
	float3 sum = _float3( 0 );
	float3 avg = Average( pal );

	for( int i = 0; i < NUM_COLORS; i++ )
	{
		sum += abs( pal[i] - avg );
	}

	return sum / float( NUM_COLORS );
}

// squared distance to avoid the sqrt of distance function
float ColorCompare( float3 a, float3 b )
{
	float3 diff = b - a;
	return dot( diff, diff );
}

// find nearest palette color using Euclidean distance
float3 LinearSearch( float3 c, float3 pal[NUM_COLORS] )
{
	int index = 0;
	float minDist = ColorCompare( c, pal[0] );

	for( int i = 1; i <	NUM_COLORS; i++ )
	{
		float dist = ColorCompare( c, pal[i] );

		if( dist < minDist )
		{
			minDist = dist;
			index = i;
		}
	}

	return pal[index];
}

#define RGB(r, g, b) float3(float(r)/255.0, float(g)/255.0, float(b)/255.0)

void main( PS_IN fragment, out PS_OUT result )
{
#if 0
	// Ancient Heritage 30
	// https://lospec.com/palette-list/ancientheritage30
	const float3 palette[NUM_COLORS] = // 30
	{
		RGB( 2, 4, 5 ),
		RGB( 21, 33, 43 ),
		RGB( 32, 50, 66 ),
		RGB( 45, 71, 94 ),
		RGB( 67, 104, 121 ),
		RGB( 100, 166, 194 ),
		RGB( 119, 217, 213 ),
		RGB( 233, 241, 242 ),
		RGB( 176, 178, 181 ),
		RGB( 122, 129, 140 ),
		RGB( 83, 88, 94 ),
		RGB( 125, 69, 52 ),
		RGB( 175, 107, 66 ),
		RGB( 255, 168, 97 ),
		RGB( 255, 240, 156 ),
		RGB( 95, 26, 41 ),
		RGB( 146, 40, 62 ),
		RGB( 199, 78, 51 ),
		RGB( 240, 120, 62 ),
		RGB( 30, 56, 56 ),
		RGB( 41, 77, 70 ),
		RGB( 51, 99, 83 ),
		RGB( 109, 153, 106 ),
		RGB( 97, 31, 73 ),
		RGB( 140, 76, 128 ),
		RGB( 154, 116, 181 ),
		RGB( 171, 157, 227 ),
		RGB( 51, 38, 20 ),
		RGB( 77, 59, 34 ),
		RGB( 113, 89, 72 ),
	};

#elif 0

	// Meld Plus - a Sega candidate, very colorful
	// https://lospec.com/palette-list/meld-plus
	const float3 palette[NUM_COLORS] = // 45
	{
		RGB( 81, 6, 44 ),
		RGB( 149, 18, 58 ),
		RGB( 189, 101, 55 ),
		RGB( 230, 167, 88 ),
		RGB( 251, 227, 163 ),
		RGB( 255, 255, 255 ),
		RGB( 242, 230, 179 ),
		RGB( 210, 154, 173 ),
		RGB( 131, 97, 144 ),
		RGB( 64, 60, 105 ),
		RGB( 0, 0, 55 ),
		RGB( 64, 47, 93 ),
		RGB( 95, 92, 128 ),
		RGB( 149, 154, 187 ),
		RGB( 209, 234, 251 ),
		RGB( 255, 205, 243 ),
		RGB( 249, 132, 237 ),
		RGB( 194, 42, 218 ),
		RGB( 79, 10, 138 ),
		RGB( 30, 13, 78 ),
		RGB( 19, 33, 120 ),
		RGB( 29, 84, 177 ),
		RGB( 53, 135, 210 ),
		RGB( 97, 212, 255 ),
		RGB( 231, 255, 125 ),
		RGB( 133, 223, 83 ),
		RGB( 33, 165, 63 ),
		RGB( 0, 89, 86 ),
		RGB( 0, 60, 69 ),
		RGB( 4, 182, 146 ),
		RGB( 13, 233, 142 ),
		RGB( 152, 255, 192 ),
		RGB( 255, 231, 160 ),
		RGB( 255, 153, 51 ),
		RGB( 205, 80, 24 ),
		RGB( 135, 14, 87 ),
		RGB( 76, 2, 91 ),
		RGB( 209, 57, 103 ),
		RGB( 255, 94, 67 ),
		RGB( 255, 130, 87 ),
		RGB( 255, 211, 200 ),
		RGB( 247, 236, 206 ),
		RGB( 197, 180, 161 ),
		RGB( 156, 130, 119 ),
		RGB( 82, 48, 55 ),
	};

#elif 0

	// https://lospec.com/palette-list/nostalgia48
	const float3 palette[NUM_COLORS] = // 48
	{
		RGB( 5, 9, 15 ),
		RGB( 36, 55, 87 ),
		RGB( 60, 82, 117 ),
		RGB( 90, 113, 148 ),
		RGB( 127, 146, 179 ),
		RGB( 167, 183, 209 ),
		RGB( 206, 215, 232 ),
		RGB( 235, 238, 249 ),
		RGB( 13, 40, 41 ),
		RGB( 21, 66, 55 ),
		RGB( 35, 92, 68 ),
		RGB( 49, 117, 69 ),
		RGB( 66, 143, 66 ),
		RGB( 110, 168, 74 ),
		RGB( 163, 194, 85 ),
		RGB( 207, 219, 114 ),
		RGB( 117, 22, 35 ),
		RGB( 148, 42, 32 ),
		RGB( 179, 68, 40 ),
		RGB( 209, 102, 48 ),
		RGB( 230, 141, 62 ),
		RGB( 240, 174, 74 ),
		RGB( 240, 201, 85 ),
		RGB( 245, 232, 93 ),
		RGB( 92, 30, 28 ),
		RGB( 120, 54, 42 ),
		RGB( 145, 82, 55 ),
		RGB( 173, 112, 68 ),
		RGB( 199, 140, 88 ),
		RGB( 224, 173, 114 ),
		RGB( 235, 196, 138 ),
		RGB( 245, 217, 166 ),
		RGB( 254, 241, 199 ),
		RGB( 63, 26, 77 ),
		RGB( 109, 41, 117 ),
		RGB( 148, 57, 137 ),
		RGB( 179, 80, 141 ),
		RGB( 204, 107, 138 ),
		RGB( 230, 148, 143 ),
		RGB( 245, 186, 169 ),
		RGB( 34, 27, 82 ),
		RGB( 38, 44, 112 ),
		RGB( 48, 72, 140 ),
		RGB( 58, 114, 171 ),
		RGB( 83, 172, 204 ),
		RGB( 118, 213, 224 ),
		RGB( 167, 232, 231 ),
		RGB( 216, 240, 238 ),
	};

#elif 1

	// https://lospec.com/palette-list/famicube
	const float3 palette[NUM_COLORS] = // 64
	{
		RGB( 0, 0, 0 ),
		RGB( 224, 60, 40 ),
		RGB( 255, 255, 255 ),
		RGB( 215, 215, 215 ),
		RGB( 168, 168, 168 ),
		RGB( 123, 123, 123 ),
		RGB( 52, 52, 52 ),
		RGB( 21, 21, 21 ),
		RGB( 13, 32, 48 ),
		RGB( 65, 93, 102 ),
		RGB( 113, 166, 161 ),
		RGB( 189, 255, 202 ),
		RGB( 37, 226, 205 ),
		RGB( 10, 152, 172 ),
		RGB( 0, 82, 128 ),
		RGB( 0, 96, 75 ),
		RGB( 32, 181, 98 ),
		RGB( 88, 211, 50 ),
		RGB( 19, 157, 8 ),
		RGB( 0, 78, 0 ),
		RGB( 23, 40, 8 ),
		RGB( 55, 109, 3 ),
		RGB( 106, 180, 23 ),
		RGB( 140, 214, 18 ),
		RGB( 190, 235, 113 ),
		RGB( 238, 255, 169 ),
		RGB( 182, 193, 33 ),
		RGB( 147, 151, 23 ),
		RGB( 204, 143, 21 ),
		RGB( 255, 187, 49 ),
		RGB( 255, 231, 55 ),
		RGB( 246, 143, 55 ),
		RGB( 173, 78, 26 ),
		RGB( 35, 23, 18 ),
		RGB( 92, 60, 13 ),
		RGB( 174, 108, 55 ),
		RGB( 197, 151, 130 ),
		RGB( 226, 215, 181 ),
		RGB( 79, 21, 7 ),
		RGB( 130, 60, 61 ),
		RGB( 218, 101, 94 ),
		RGB( 225, 130, 137 ),
		RGB( 245, 183, 132 ),
		RGB( 255, 233, 197 ),
		RGB( 255, 130, 206 ),
		RGB( 207, 60, 113 ),
		RGB( 135, 22, 70 ),
		RGB( 163, 40, 179 ),
		RGB( 204, 105, 228 ),
		RGB( 213, 156, 252 ),
		RGB( 254, 201, 237 ),
		RGB( 226, 201, 255 ),
		RGB( 166, 117, 254 ),
		RGB( 106, 49, 202 ),
		RGB( 90, 25, 145 ),
		RGB( 33, 22, 64 ),
		RGB( 61, 52, 165 ),
		RGB( 98, 100, 220 ),
		RGB( 155, 160, 239 ),
		RGB( 152, 220, 255 ),
		RGB( 91, 168, 255 ),
		RGB( 10, 137, 255 ),
		RGB( 2, 74, 202 ),
		RGB( 0, 23, 125 ),
	};

#elif 1

	// https://lospec.com/palette-list/blk-nx64

	const float3 palette[NUM_COLORS] = // 64
	{
		RGB( 0, 0, 0 ),
		RGB( 18, 23, 61 ),
		RGB( 41, 50, 104 ),
		RGB( 70, 75, 140 ),
		RGB( 107, 116, 178 ),
		RGB( 144, 158, 221 ),
		RGB( 193, 217, 242 ),
		RGB( 255, 255, 255 ),
		RGB( 162, 147, 196 ),
		RGB( 123, 106, 165 ),
		RGB( 83, 66, 127 ),
		RGB( 60, 44, 104 ),
		RGB( 67, 30, 102 ),
		RGB( 93, 47, 140 ),
		RGB( 133, 76, 191 ),
		RGB( 180, 131, 239 ),
		RGB( 140, 255, 155 ),
		RGB( 66, 188, 127 ),
		RGB( 34, 137, 110 ),
		RGB( 20, 102, 91 ),
		RGB( 15, 74, 76 ),
		RGB( 10, 42, 51 ),
		RGB( 29, 26, 89 ),
		RGB( 50, 45, 137 ),
		RGB( 53, 74, 178 ),
		RGB( 62, 131, 209 ),
		RGB( 80, 185, 235 ),
		RGB( 140, 218, 255 ),
		RGB( 83, 161, 173 ),
		RGB( 59, 118, 143 ),
		RGB( 33, 82, 107 ),
		RGB( 22, 55, 85 ),
		RGB( 0, 135, 130 ),
		RGB( 0, 170, 165 ),
		RGB( 39, 211, 203 ),
		RGB( 120, 250, 230 ),
		RGB( 205, 197, 153 ),
		RGB( 152, 143, 100 ),
		RGB( 92, 93, 65 ),
		RGB( 53, 63, 35 ),
		RGB( 145, 155, 69 ),
		RGB( 175, 211, 112 ),
		RGB( 255, 224, 145 ),
		RGB( 255, 170, 110 ),
		RGB( 255, 105, 90 ),
		RGB( 178, 60, 64 ),
		RGB( 255, 102, 117 ),
		RGB( 221, 55, 69 ),
		RGB( 165, 38, 57 ),
		RGB( 114, 28, 47 ),
		RGB( 178, 46, 105 ),
		RGB( 229, 66, 134 ),
		RGB( 255, 110, 175 ),
		RGB( 255, 165, 213 ),
		RGB( 255, 211, 173 ),
		RGB( 204, 129, 122 ),
		RGB( 137, 86, 84 ),
		RGB( 97, 57, 59 ),
		RGB( 63, 31, 60 ),
		RGB( 114, 51, 82 ),
		RGB( 153, 76, 105 ),
		RGB( 195, 114, 137 ),
		RGB( 242, 159, 170 ),
		RGB( 255, 204, 208 ),
	};

#elif 0

	// Resurrect 64 - Most popular 64 colors palette
	// https://lospec.com/palette-list/resurrect-64

	const float3 palette[NUM_COLORS] = // 64
	{
		RGB( 46, 34, 47 ),
		RGB( 62, 53, 70 ),
		RGB( 98, 85, 101 ),
		RGB( 150, 108, 108 ),
		RGB( 171, 148, 122 ),
		RGB( 105, 79, 98 ),
		RGB( 127, 112, 138 ),
		RGB( 155, 171, 178 ),
		RGB( 199, 220, 208 ),
		RGB( 255, 255, 255 ),
		RGB( 110, 39, 39 ),
		RGB( 179, 56, 49 ),
		RGB( 234, 79, 54 ),
		RGB( 245, 125, 74 ),
		RGB( 174, 35, 52 ),
		RGB( 232, 59, 59 ),
		RGB( 251, 107, 29 ),
		RGB( 247, 150, 23 ),
		RGB( 249, 194, 43 ),
		RGB( 122, 48, 69 ),
		RGB( 158, 69, 57 ),
		RGB( 205, 104, 61 ),
		RGB( 230, 144, 78 ),
		RGB( 251, 185, 84 ),
		RGB( 76, 62, 36 ),
		RGB( 103, 102, 51 ),
		RGB( 162, 169, 71 ),
		RGB( 213, 224, 75 ),
		RGB( 251, 255, 134 ),
		RGB( 22, 90, 76 ),
		RGB( 35, 144, 99 ),
		RGB( 30, 188, 115 ),
		RGB( 145, 219, 105 ),
		RGB( 205, 223, 108 ),
		RGB( 49, 54, 56 ),
		RGB( 55, 78, 74 ),
		RGB( 84, 126, 100 ),
		RGB( 146, 169, 132 ),
		RGB( 178, 186, 144 ),
		RGB( 11, 94, 101 ),
		RGB( 11, 138, 143 ),
		RGB( 14, 175, 155 ),
		RGB( 48, 225, 185 ),
		RGB( 143, 248, 226 ),
		RGB( 50, 51, 83 ),
		RGB( 72, 74, 119 ),
		RGB( 77, 101, 180 ),
		RGB( 77, 155, 230 ),
		RGB( 143, 211, 255 ),
		RGB( 69, 41, 63 ),
		RGB( 107, 62, 117 ),
		RGB( 144, 94, 169 ),
		RGB( 168, 132, 243 ),
		RGB( 234, 173, 237 ),
		RGB( 117, 60, 84 ),
		RGB( 162, 75, 111 ),
		RGB( 207, 101, 127 ),
		RGB( 237, 128, 153 ),
		RGB( 131, 28, 93 ),
		RGB( 195, 36, 84 ),
		RGB( 240, 79, 120 ),
		RGB( 246, 129, 129 ),
		RGB( 252, 167, 144 ),
		RGB( 253, 203, 176 ),
	};

#elif 1

	// https://lospec.com/palette-list/twilioquest-76

	const float3 palette[NUM_COLORS] = // 76
	{
		RGB( 255, 255, 255 ),
		RGB( 234, 234, 232 ),
		RGB( 206, 202, 201 ),
		RGB( 171, 175, 185 ),
		RGB( 161, 136, 151 ),
		RGB( 117, 98, 118 ),
		RGB( 93, 70, 96 ),
		RGB( 76, 50, 80 ),
		RGB( 67, 38, 65 ),
		RGB( 40, 25, 47 ),
		RGB( 251, 117, 117 ),
		RGB( 251, 59, 100 ),
		RGB( 200, 49, 87 ),
		RGB( 142, 55, 92 ),
		RGB( 79, 35, 81 ),
		RGB( 53, 21, 68 ),
		RGB( 247, 74, 83 ),
		RGB( 242, 47, 70 ),
		RGB( 188, 22, 66 ),
		RGB( 252, 197, 57 ),
		RGB( 248, 123, 27 ),
		RGB( 248, 64, 27 ),
		RGB( 189, 39, 9 ),
		RGB( 124, 18, 43 ),
		RGB( 255, 224, 139 ),
		RGB( 250, 192, 90 ),
		RGB( 235, 143, 72 ),
		RGB( 209, 116, 65 ),
		RGB( 199, 82, 57 ),
		RGB( 177, 41, 53 ),
		RGB( 253, 189, 143 ),
		RGB( 240, 136, 107 ),
		RGB( 211, 104, 83 ),
		RGB( 174, 69, 74 ),
		RGB( 140, 49, 50 ),
		RGB( 84, 35, 35 ),
		RGB( 168, 88, 72 ),
		RGB( 131, 64, 76 ),
		RGB( 103, 49, 75 ),
		RGB( 63, 35, 35 ),
		RGB( 212, 149, 119 ),
		RGB( 159, 112, 90 ),
		RGB( 132, 87, 80 ),
		RGB( 99, 59, 63 ),
		RGB( 123, 215, 169 ),
		RGB( 82, 178, 129 ),
		RGB( 20, 133, 104 ),
		RGB( 20, 103, 86 ),
		RGB( 34, 71, 76 ),
		RGB( 16, 47, 52 ),
		RGB( 235, 255, 139 ),
		RGB( 179, 227, 99 ),
		RGB( 76, 189, 86 ),
		RGB( 47, 135, 53 ),
		RGB( 11, 89, 49 ),
		RGB( 151, 191, 110 ),
		RGB( 137, 159, 102 ),
		RGB( 97, 133, 90 ),
		RGB( 76, 96, 81 ),
		RGB( 115, 223, 242 ),
		RGB( 42, 187, 208 ),
		RGB( 49, 93, 205 ),
		RGB( 71, 42, 156 ),
		RGB( 160, 216, 215 ),
		RGB( 125, 190, 250 ),
		RGB( 102, 143, 175 ),
		RGB( 88, 93, 129 ),
		RGB( 69, 54, 93 ),
		RGB( 246, 186, 254 ),
		RGB( 213, 159, 244 ),
		RGB( 176, 112, 235 ),
		RGB( 124, 60, 225 ),
		RGB( 219, 207, 177 ),
		RGB( 169, 164, 141 ),
		RGB( 123, 131, 130 ),
		RGB( 95, 95, 110 ),
	};

#elif 0

	// Endesga 64 - very colorful and more complete
	// https://lospec.com/palette-list/endesga-64

	const float3 palette[NUM_COLORS] = // 64
	{
		RGB( 255, 0, 64 ),
		RGB( 19, 19, 19 ),
		RGB( 27, 27, 27 ),
		RGB( 39, 39, 39 ),
		RGB( 61, 61, 61 ),
		RGB( 93, 93, 93 ),
		RGB( 133, 133, 133 ),
		RGB( 180, 180, 180 ),
		RGB( 255, 255, 255 ),
		RGB( 199, 207, 221 ),
		RGB( 146, 161, 185 ),
		RGB( 101, 115, 146 ),
		RGB( 66, 76, 110 ),
		RGB( 42, 47, 78 ),
		RGB( 26, 25, 50 ),
		RGB( 14, 7, 27 ),
		RGB( 28, 18, 28 ),
		RGB( 57, 31, 33 ),
		RGB( 93, 44, 40 ),
		RGB( 138, 72, 54 ),
		RGB( 191, 111, 74 ),
		RGB( 230, 156, 105 ),
		RGB( 246, 202, 159 ),
		RGB( 249, 230, 207 ),
		RGB( 237, 171, 80 ),
		RGB( 224, 116, 56 ),
		RGB( 198, 69, 36 ),
		RGB( 142, 37, 29 ),
		RGB( 255, 80, 0 ),
		RGB( 237, 118, 20 ),
		RGB( 255, 162, 20 ),
		RGB( 255, 200, 37 ),
		RGB( 255, 235, 87 ),
		RGB( 211, 252, 126 ),
		RGB( 153, 230, 95 ),
		RGB( 90, 197, 79 ),
		RGB( 51, 152, 75 ),
		RGB( 30, 111, 80 ),
		RGB( 19, 76, 76 ),
		RGB( 12, 46, 68 ),
		RGB( 0, 57, 109 ),
		RGB( 0, 105, 170 ),
		RGB( 0, 152, 220 ),
		RGB( 0, 205, 249 ),
		RGB( 12, 241, 255 ),
		RGB( 148, 253, 255 ),
		RGB( 253, 210, 237 ),
		RGB( 243, 137, 245 ),
		RGB( 219, 63, 253 ),
		RGB( 122, 9, 250 ),
		RGB( 48, 3, 217 ),
		RGB( 12, 2, 147 ),
		RGB( 3, 25, 63 ),
		RGB( 59, 20, 67 ),
		RGB( 98, 36, 97 ),
		RGB( 147, 56, 143 ),
		RGB( 202, 82, 201 ),
		RGB( 200, 80, 134 ),
		RGB( 246, 129, 135 ),
		RGB( 245, 85, 93 ),
		RGB( 234, 50, 60 ),
		RGB( 196, 36, 48 ),
		RGB( 137, 30, 43 ),
		RGB( 87, 28, 39 ),
	};

#elif 0

	// like the Sega Master System
	// https://lospec.com/palette-list/6-bit-rgb

	const float3 palette[NUM_COLORS] = // 64
	{
		RGB( 0, 0, 0 ),
		RGB( 0, 0, 85 ),
		RGB( 0, 0, 170 ),
		RGB( 0, 0, 255 ),
		RGB( 85, 0, 0 ),
		RGB( 85, 0, 85 ),
		RGB( 85, 0, 170 ),
		RGB( 85, 0, 255 ),
		RGB( 170, 0, 0 ),
		RGB( 170, 0, 85 ),
		RGB( 170, 0, 170 ),
		RGB( 170, 0, 255 ),
		RGB( 255, 0, 0 ),
		RGB( 255, 0, 85 ),
		RGB( 255, 0, 170 ),
		RGB( 255, 0, 255 ),
		RGB( 0, 85, 0 ),
		RGB( 0, 85, 85 ),
		RGB( 0, 85, 170 ),
		RGB( 0, 85, 255 ),
		RGB( 85, 85, 0 ),
		RGB( 85, 85, 85 ),
		RGB( 85, 85, 170 ),
		RGB( 85, 85, 255 ),
		RGB( 170, 85, 0 ),
		RGB( 170, 85, 85 ),
		RGB( 170, 85, 170 ),
		RGB( 170, 85, 255 ),
		RGB( 255, 85, 0 ),
		RGB( 255, 85, 85 ),
		RGB( 255, 85, 170 ),
		RGB( 255, 85, 255 ),
		RGB( 0, 170, 0 ),
		RGB( 0, 170, 85 ),
		RGB( 0, 170, 170 ),
		RGB( 0, 170, 255 ),
		RGB( 85, 170, 0 ),
		RGB( 85, 170, 85 ),
		RGB( 85, 170, 170 ),
		RGB( 85, 170, 255 ),
		RGB( 170, 170, 0 ),
		RGB( 170, 170, 85 ),
		RGB( 170, 170, 170 ),
		RGB( 170, 170, 255 ),
		RGB( 255, 170, 0 ),
		RGB( 255, 170, 85 ),
		RGB( 255, 170, 170 ),
		RGB( 255, 170, 255 ),
		RGB( 0, 255, 0 ),
		RGB( 0, 255, 85 ),
		RGB( 0, 255, 170 ),
		RGB( 0, 255, 255 ),
		RGB( 85, 255, 0 ),
		RGB( 85, 255, 85 ),
		RGB( 85, 255, 170 ),
		RGB( 85, 255, 255 ),
		RGB( 170, 255, 0 ),
		RGB( 170, 255, 85 ),
		RGB( 170, 255, 170 ),
		RGB( 170, 255, 255 ),
		RGB( 255, 255, 0 ),
		RGB( 255, 255, 85 ),
		RGB( 255, 255, 170 ),
		RGB( 255, 255, 255 ),
	};

#elif 0

	// Sega Genesis Evangelion
	// https://lospec.com/palette-list/sega-genesis-evangelion

	const float3 palette[NUM_COLORS] = // 17
	{
		RGB( 207, 201, 179 ),
		RGB( 163, 180, 158 ),
		RGB( 100, 166, 174 ),
		RGB( 101, 112, 141 ),
		RGB( 52, 54, 36 ),
		RGB( 37, 34, 70 ),
		RGB( 39, 28, 21 ),
		RGB( 20, 14, 11 ),
		RGB( 0, 0, 0 ),
		RGB( 202, 168, 87 ),
		RGB( 190, 136, 51 ),
		RGB( 171, 85, 92 ),
		RGB( 186, 47, 74 ),
		RGB( 131, 25, 97 ),
		RGB( 102, 52, 143 ),
		RGB( 203, 216, 246 ),
		RGB( 140, 197, 79 ),
	};

#endif

	float2 uv = ( fragment.texcoord0 );
	float2 uvPixelated = floor( fragment.position.xy / RESOLUTION_DIVISOR ) * RESOLUTION_DIVISOR;

	float3 quantizationPeriod = _float3( 1.0 / NUM_COLORS );
	float3 quantDeviation = Deviation( palette );

	// get pixellated base color
	float3 color = t_BaseColor.Sample( s_LinearClamp, uvPixelated * rpWindowCoord.xy ).rgb;

	float2 uvDither = uvPixelated;
	//if( rpJitterTexScale.x > 1.0 )
	{
		uvDither = fragment.position.xy / ( RESOLUTION_DIVISOR / rpJitterTexScale.x );
	}
	float dither = DitherArray8x8( uvDither ) - 0.5;

#if 0
	if( uv.y < 0.0625 )
	{
		color = HSVToRGB( float3( uv.x, 1.0, uv.y * 16.0 ) );

		result.color = float4( color, 1.0 );
		return;
	}
	else if( uv.y < 0.125 )
	{
		// quantized
		color = HSVToRGB( float3( uv.x, 1.0, ( uv.y - 0.0625 ) * 16.0 ) );
		color = LinearSearch( color, palette );

		result.color = float4( color, 1.0 );
		return;
	}
	else if( uv.y < 0.1875 )
	{
		// dithered quantized
		color = HSVToRGB( float3( uv.x, 1.0, ( uv.y - 0.125 ) * 16.0 ) );

		color.rgb += float3( dither, dither, dither ) * quantDeviation * rpJitterTexScale.y;
		color = LinearSearch( color, palette );

		result.color = float4( color, 1.0 );
		return;
	}
	else if( uv.y < 0.25 )
	{
		color = _float3( uv.x );
		color = floor( color * NUM_COLORS ) * ( 1.0 / ( NUM_COLORS - 1.0 ) );
		color += float3( dither, dither, dither ) * quantDeviation * rpJitterTexScale.y;
		color = LinearSearch( color.rgb, palette );

		result.color = float4( color, 1.0 );
		return;
	}
#endif

	color.rgb += float3( dither, dither, dither ) * quantDeviation * rpJitterTexScale.y;

	// find closest color match from C64 color palette
	color = LinearSearch( color.rgb, palette );

	result.color = float4( color, 1.0 );
}
