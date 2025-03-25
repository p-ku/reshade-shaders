#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#ifndef CHROMATIC_ABERRATION
    #define CHROMATIC_ABERRATION 1
#endif
#ifndef CHROMATIC_ABERRATION_JITTER
    #define CHROMATIC_ABERRATION_JITTER 1
#endif
#ifndef VIGNETTE
    #define VIGNETTE 1
#endif
#ifndef FILM_GRAIN
    #define FILM_GRAIN 1
#endif
#ifndef COLOR_FILM_GRAIN
    #define COLOR_FILM_GRAIN 0
#endif
#ifndef DITHERING_RATIO
    #define DITHERING_RATIO 255
#endif
#ifndef DITHERING_OFFSET
    #define DITHERING_OFFSET 500
#endif

#define PI 3.14159265359
#if CHROMATIC_ABERRATION
    uniform float Chromatic_Aberration_Intensity < __UNIFORM_SLIDER_FLOAT1
        ui_label = "Intensity";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Chromatic Aberration";
    > = 0.25;
    uniform uint Chromatic_Aberration_Samples < __UNIFORM_SLIDER_INT1
        ui_label = "Samples";
        ui_min = 4; ui_max = 32; ui_step = 4;
        ui_category = "Chromatic Aberration";
    > = 8;
#endif

#if VIGNETTE
    uniform float Vignette_Intensity < __UNIFORM_SLIDER_FLOAT1
        ui_label = "Intensity";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Vignette";
    > = 0.25;
#endif

#if FILM_GRAIN
    uniform float Film_Grain_Intensity < __UNIFORM_SLIDER_FLOAT1
        ui_label = "Intensity";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Film Grain";
    > = 0.1;
    #define _LUMA_COEF float3(0.2126,0.7152,0.0722)
    //#define _LUMA_COEF float3(0.299,0.587,0.114)
    float3 nrand3(float2 seed, float tr)
	{
		return frac(sin(dot(seed.xy, float2(34.483, 89.637) * tr)) * float3(29156.4765, 38273.5639, 47843.7546));
	}
#endif

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


#if CHROMATIC_ABERRATION | FILM_GRAIN
    float nrand(const float2 seed ) {return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);}
#endif

uniform float timer < source = "timer"; >;

#define triangle(noise) sign(noise) * (1.0 - sqrt(1.0 - abs(noise))) // [-1;1]

float4 PerfectPerspective_PS(
	float4 pixelPos  : SV_Position,
	float2 texCoord  : TEXCOORD0
) : SV_Target
{
	#if CHROMATIC_ABERRATION | VIGNETTE
	    const float2 reso = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
        const float2 center = 0.5 * reso;
        const float max_diagonal = length(center); // for scaling
        const float center_distance = distance(pixelPos.xy, center);
    #endif

    const float seconds = timer * 0.001;

	#if CHROMATIC_ABERRATION
        // determine how for to blur
        float blue_distance = center_distance * cos(0.25 * PI * center_distance * Chromatic_Aberration_Intensity / max_diagonal);
        float2 pixel_center_pos = pixelPos.xy - center;
        float2 blue_center_pos = pixel_center_pos * blue_distance / center_distance;
        float2 pixel_range = blue_center_pos - pixel_center_pos;
        
        // create steps for sample loop
        float2 pixel_size = 1.0 / reso;
        float2 sample_delta = pixel_range / Chromatic_Aberration_Samples;
        float2 uv_delta = sample_delta * pixel_size;
        float spectrum_delta = 1.0 / Chromatic_Aberration_Samples;
        // set location of first sample, jittered or not

        // Jitter
        #if CHROMATIC_ABERRATION_JITTER
			//float white_noise = nrand(texCoord, seconds);
			const static float white_noise = nrand(texCoord + nrand(texCoord + seconds));
		#else 
			const static float white_noise = 0.5;
        #endif

        float2 sample_uv = texCoord + uv_delta * white_noise;
        float spectrum_pos = spectrum_delta * white_noise;

        float3 filter_sum = float3(0.0,0.0,0.0);
        float3 sum = float3(0.0,0.0,0.0);
        
        // sample away
        //   [unroll(3)] while (spectrum_pos < 1.0) {
  
        for (uint i = 0; i<Chromatic_Aberration_Samples; i++) {
            // this set of equations determines the colors of the rainbow
            float c1 = 6.0 * spectrum_pos - 3.0;
            float3 spectrum_filter;
            spectrum_filter.g = 0.5 + 0.5 * sin(2.0 * PI * (spectrum_pos - 0.25));
            if (spectrum_pos < 0.5) 
                spectrum_filter.r = 0.5 + 0.5 * sin(4.0 * PI * spectrum_pos - 0.5 * PI);
            else
                spectrum_filter.b = 0.5 + 0.5 * sin(4.0 * PI * spectrum_pos - 0.5 * PI);

            sum += tex2D(ReShade::BackBuffer, sample_uv).rgb * spectrum_filter;
            //sum += tex2Dgrad(ReShade::BackBuffer, sample_uv, ddx(sample_uv), ddy(sample_uv)).rgb * spectrum_filter;
			//tex2Dgrad(BackBuffer, texCoord, ddx(texCoord), ddy(texCoord))
			filter_sum += spectrum_filter;
            spectrum_pos += spectrum_delta;
            sample_uv += uv_delta;
        }
        float4 display = float4(sum / filter_sum,1);
    #else
		float4 display = tex2Dfetch(ReShade::BackBuffer, pixelPos.xy);
	#endif
	
	#if VIGNETTE
        const float center_angle = atan(Vignette_Intensity * center_distance / max_diagonal);
        const float vig = pow(cos(center_angle), 4.0); // more natural
        display.rgb *= vig;
	#endif

	#if FILM_GRAIN
        const float luma = dot(display.rgb, _LUMA_COEF);
        const float luma_factor =  max(Film_Grain_Intensity * (luma - luma * luma), 0.0);

        // add noise to luma
        #if COLOR_FILM_GRAIN
        const float tr = frac(timer / 1337.7331) + 0.5;
        const float3 grain_noise = triangle(2.0 * nrand3(texCoord, tr) - 1.0);
        const float3 new_luma = luma + luma_factor * grain_noise;
        display.rgb = (display.rgb + 0.5 / 255.0) * new_luma / luma;
		#else
        const float tr = frac(timer / 1337.7331) + 0.5;
        const float grain_noise = triangle(2.0 * nrand(texCoord + tr) - 1.0);
        const float new_luma = luma + luma_factor * grain_noise;
        display = (display + 0.5 / 255.0) * new_luma / luma;
		#endif
	#endif


    const uint2 dip = (1337 * uint(timer + DITHERING_OFFSET) + uint2(pixelPos.xy)) % uint2(_DITHER_NOISE_SIZE, _DITHER_NOISE_SIZE);
    float4 dither_noise = 2.0 * tex2Dfetch(Dither_Noise_Sampler, dip, 0) - 1.0;   // [-1;1]
    dither_noise = triangle(dither_noise); // [-1;1]
	display += dither_noise / DITHERING_RATIO;
	return display;
}

technique pku
{
	pass PerspectiveDistortion
	{
		VertexShader = PostProcessVS;
		PixelShader  = PerfectPerspective_PS;
	}
}