#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#ifndef DITHERING_RATIO
    #define DITHERING_RATIO 255
#endif
#ifndef DITHERING_OFFSET
    #define DITHERING_OFFSET 0
#endif
uniform float timer < source = "timer"; >;
#define _DITHER_NOISE_SIZE 1024
texture Dither_Noise_Tex <
    source = "BlueNoise.png";
    > {
        Format = RGBA8;
        Width  = _DITHER_NOISE_SIZE;
        Height = _DITHER_NOISE_SIZE;
    };

sampler Dither_Noise_Sampler
{
    Texture  = Dither_Noise_Tex;
    AddressU = BORDER;
    AddressV = BORDER;
};

uniform uint FovAngle
<	__UNIFORM_SLIDER_INT1
	ui_category_closed = true;
	ui_units = "°";
	ui_label = "Field of view (FOV)";
	ui_tooltip = "Should match in-game FOV value.";
	ui_min = 1u;
	ui_max = 90u;
> = 30u;

uniform uint FovType
<	__UNIFORM_COMBO_INT1
	ui_label = "Field of view type";
	ui_items =
		"horizontal\0"
		"vertical\0";
> = 1u;

uniform float K
<	__UNIFORM_SLIDER_FLOAT1
	ui_category_closed = true;
	ui_units = " k";
	ui_label = "Fisheye profile";
	ui_min = 0.01f; ui_max = 0.99f; ui_step = 0.01;
> = 0.5;

uniform float CroppingFactor
<	__UNIFORM_SLIDER_FLOAT1
	ui_label = "Cropping";
	ui_min = 0f; ui_max = 1f; ui_step = 0.005;
> = 0.0;

float4 triangle(float4 noise) {return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));} // [-1;1]

/* Linear pixel step function for anti-aliasing by Jakub Max Fober.
   This algorithm is part of scientific paper:
   · arXiv:2010.04077 [cs.GR] (2020) */
float aastep(float grad)
{
	// Differential vector
	float2 Del = float2(ddx(grad), ddy(grad));
	// Gradient normalization to pixel size, centered at the step edge
	return saturate(mad(rsqrt(dot(Del, Del)), grad, 0.5)); // half-pixel offset
}

/* Azimuthal spherical perspective projection equations © 2022 Jakub Maksymilian Fober
   These algorithms are part of the following scientific papers:
   · arXiv:2003.10558 [cs.GR] (2020)
   · arXiv:2010.04077 [cs.GR] (2020) */
float get_radius(float theta, float rcp_f, float k) // get image radius
{
	return tan(abs(k)*theta)/rcp_f/abs(k); // stereographic, rectilinear projections
}

// Get radius at Ω for a given FOV type
float getRadiusOfOmega(float2 viewProportions)
{
	switch (FovType) // uniform input
	{
		case 1u: // vertical
			return viewProportions.y;
		default: // horizontal
			return viewProportions.x;
	}
}

// Border mask shader with rounded corners
float GetBorderMask(float2 borderCoord)
{
	// Get coordinates for each corner
	borderCoord = abs(borderCoord);
	return aastep(max(abs(borderCoord.x), abs(borderCoord.y))-1f);
}

// Vertex shader generating a triangle covering the entire screen
void PerfectPerspective_VS(
	in  uint   vertexId  : SV_VertexID,
	out float4 position  : SV_Position,
	out float2 texCoord  : TEXCOORD0,
	out float2 viewCoord : TEXCOORD1
)
{
	// Generate vertex position for triangle ABC covering whole screen
	position.x = vertexId==2? 3f :-1f;
	position.y = vertexId==1?-3f : 1f;
	// Initialize other values
	position.z = 0f; // not used
	position.w = 1f; // not used

	// Export screen centered texture coordinates
	texCoord.x = viewCoord.x =  position.x;
	texCoord.y = viewCoord.y = -position.y;
	// Map to corner and normalize texture coordinates
	texCoord = texCoord*0.5+0.5;
	// Get aspect ratio transformation vector
	static const float2 viewProportions = normalize(BUFFER_SCREEN_SIZE);
	// Correct aspect ratio, normalized to the corner
	viewCoord *= viewProportions;
	
	//----------------------------------------------
// begin cropping of image bounds

	// Half field of view angle in radians
	static const float halfOmega = radians(FovAngle*0.5);
	// Get radius at Ω for a given FOV type
	static const float radiusOfOmega = getRadiusOfOmega(viewProportions);
	// Reciprocal focal length
	static const float rcp_focal = get_radius(halfOmega, radiusOfOmega, K);

	// Horizontal point radius
	static const float croppingHorizontal = get_radius(
			atan(tan(halfOmega)/radiusOfOmega*viewProportions.x),
		rcp_focal, K)/viewProportions.x;

	// Vertical point radius
	static const float croppingVertical = get_radius(
			atan(tan(halfOmega)/radiusOfOmega*viewProportions.y),
		rcp_focal, K)/viewProportions.y;
	// Diagonal point radius
	static const float anamorphicDiagonal = length(float2(
		viewProportions.x,
		viewProportions.y
	));


	// Circular fish-eye
	static const float circularFishEye = max(croppingHorizontal, croppingVertical);
	// Cropped circle
	static const float croppedCircle = min(croppingHorizontal, croppingVertical);
	// Full-frame
	static const float fullFrame = get_radius(
		atan(tan(halfOmega)/radiusOfOmega*anamorphicDiagonal),
		rcp_focal, K)/anamorphicDiagonal;

	// Get radius scaling for bounds alignment
	static const float croppingScalar =
		lerp(
			circularFishEye, // cropped circle
			fullFrame, // full-frame
			CroppingFactor // ↤ [1,2] range
		);

	// Scale view coordinates to cropping bounds
	viewCoord *= croppingScalar;
}

// Main perspective shader pass
float4	 PerfectPerspective_PS(
	float4 pixelPos  : SV_Position,
	float2 texCoord  : TEXCOORD0,
	float2 viewCoord : TEXCOORD1
) : SV_Target
{
//----------------------------------------------
// begin of perspective mapping

	// Aspect ratio transformation vector
	static const float2 viewProportions = normalize(BUFFER_SCREEN_SIZE);
	// Half field of view angle in radians
	static const float halfOmega = radians(FovAngle * 0.5);
	// Get radius at Ω for a given FOV type
	static const  float radiusOfOmega = getRadiusOfOmega(viewProportions);

	// Reciprocal focal length
	static const float rcp_focal = get_radius(halfOmega, radiusOfOmega, K);
	// Image radius
	float radius = sqrt(dot(viewCoord, viewCoord));

	float theta = atan(K * radius * rcp_focal) / K;

	// Rectilinear perspective transformation
	viewCoord *= tan(theta)/radius;
	// Back to normalized, centered coordinates
	static const float2 toUvCoord = radiusOfOmega/(tan(halfOmega)*viewProportions);
	
	viewCoord *= toUvCoord;

// end of perspective mapping
//----------------------------------------------

	// Back to UV Coordinates
	texCoord = viewCoord*0.5+0.5;

	// Get border image
	static const float4 border = float4(0,0,0,1);
	// Outside border mask with anti-aliasing
	static const float borderMask = GetBorderMask(viewCoord);
	//float4 display = tex2Dgrad(ReShade::BackBuffer, texCoord, ddx(texCoord), ddy(texCoord));
    float4 display = tex2D(ReShade::BackBuffer, texCoord);
    const uint2 dip = (1337 * uint(timer + DITHERING_OFFSET) + uint2(pixelPos.xy)) % uint2(_DITHER_NOISE_SIZE, _DITHER_NOISE_SIZE);
    float4 dither_noise = 2.0 * tex2Dfetch(Dither_Noise_Sampler, dip, 0) - 1.0;   // [-1;1]
    dither_noise = triangle(dither_noise); // [-1;1]
	display += dither_noise / DITHERING_RATIO;

	display = lerp(display, border, borderMask);

	return display;
	
}

technique pku
{
	pass PerspectiveDistortion
	{
		VertexShader = PerfectPerspective_VS;
		PixelShader  = PerfectPerspective_PS;
	}
}