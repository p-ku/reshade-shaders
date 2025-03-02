#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#ifndef BARREL_DISTORTION
    #define BARREL_DISTORTION 1
#endif

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

#ifndef DITHERING
    #define DITHERING 1
#endif

#if BARREL_DISTORTION
    uniform float Barrel_Distortion_Intensity < __UNIFORM_SLIDER_FLOAT1
        ui_label = "Intensity";
        ui_category = "Barrel Distortion";
        ui_min = 0.0; ui_max = 1.0;
    > = 0.1;
    // from https://www.shadertoy.com/view/lstyzs
    float2 lensDistort(float2 c, const float factor)
    {
        c = (c - 0.5) * 2.0;
        c.y *= 3.0/4.0;
        c /= 1.0 + dot(c, c) * - factor + 1.6 * factor;
        c.y *= 4.0/3.0;
        c = c * 0.5 + 0.5;
        return c;
    }
#endif

#if CHROMATIC_ABERRATION
    #define PI 3.14159265359
    uniform float Chromatic_Aberration_Intensity < __UNIFORM_SLIDER_FLOAT1
        ui_label = "Intensity";
        ui_min = 0.0; ui_max = 1.0;
        ui_category = "Chromatic Aberration";
    > = 0.15;
    uniform uint Chromatic_Aberration_Samples < __UNIFORM_SLIDER_INT1
        ui_label = "Samples";
        ui_min = 4; ui_max = 32; ui_step = 4;
        ui_category = "Chromatic Aberration";
    > = 4;
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
#endif

#if DITHER
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
#endif

#if CHROMATIC_ABERRATION | FILM_GRAIN
    float nrand(const float2 uv, const float time )
    {
        return frac(sin(dot(uv + frac(time), float2(12.9898, 78.233)))* 43758.5453);
    }
#endif

#if CHROMATIC_ABERRATION | FILM_GRAIN | DITHERING
    uniform float timer < source = "timer"; >;
#endif

#if FILM_GRAIN | DITHER
    #define triangle(noise) sign(noise) * (1.0 - sqrt(1.0 - abs(noise))) // [-1;1]
#endif

float4 PkuPass(float4 vpos : SV_Position, float2 tex : TexCoord) : SV_Target
{
	#if BARREL_DISTORTION
	    tex = lensDistort(tex, Barrel_Distortion_Intensity);
	#endif

	float4 col = tex2D(ReShade::BackBuffer, tex);

	#if CHROMATIC_ABERRATION | VIGNETTE 
        const float2 reso = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
        float2 center = 0.5 * reso;
        float max_diagonal = length(center); // for scaling
        float center_distance = distance(vpos.xy, center);
	#endif

	#if CHROMATIC_ABERRATION | FILM_GRAIN | DITHERING
	    const float seconds = timer * 0.001;
	#endif

	#if CHROMATIC_ABERRATION	
        // determine how for to blur
        float blue_distance = center_distance * cos(0.25 * PI * center_distance * Chromatic_Aberration_Intensity / max_diagonal);
        float2 pixel_center_pos = vpos.xy - center;
        float2 blue_center_pos = pixel_center_pos * blue_distance / center_distance;
        float2 pixel_range = blue_center_pos - pixel_center_pos;
        
        // create steps for sample loop
        float2 pixel_size = 1.0 / reso;
        float2 sample_delta = pixel_range / Chromatic_Aberration_Samples;
        float spectrum_delta = 1.0 / Chromatic_Aberration_Samples;
        float2 uv_delta = sample_delta * pixel_size;

        // set location of first sample, jittered or not

        // Jitter
        #if CHROMATIC_ABERRATION_JITTER
			float white_noise = nrand(tex, seconds);
        #else 
			float white_noise = 0.5;
        #endif

        float2 sample_uv = tex + uv_delta * white_noise;
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
            filter_sum += spectrum_filter;
            spectrum_pos += spectrum_delta;
            sample_uv += uv_delta;
        }
        col = float4(sum / filter_sum,col.a);
	#endif

	#if VIGNETTE
        const float center_angle = atan(Vignette_Intensity * center_distance / max_diagonal);
        const float vig = pow(cos(center_angle), 4.0); // more natural
        col = float4(col.xyz * vig, col.a);
	#endif

	#if FILM_GRAIN
        float grain_noise = 2.0 * nrand(tex, seconds) - 1.0;
        grain_noise = triangle(grain_noise); // [-1;1]
        const float luma = dot(col.rgb, _LUMA_COEF);
        const float luma_factor =  max(Film_Grain_Intensity * (luma - luma * luma), 0.0);

        // add noise to luma
        const float new_luma = luma + luma_factor * grain_noise;
        col.rgb = (col.rgb + 0.5 / 255.0) * new_luma / luma;
        col = float4(col.rgb * new_luma / luma, col.a);
	#endif

	#if DITHER
        const uint2 dip = (1337 * uint(timer) + uint2(vpos.xy)) % uint2(_DITHER_NOISE_SIZE, _DITHER_NOISE_SIZE);
        float4 dither_noise = 2.0 * tex2Dfetch(Dither_Noise_Sampler, dip, 0) - 1.0;   // [-1;1]
        dither_noise = triangle(dither_noise); // [-1;1]
        col += (dither_noise + 0.5) / 255.0;
	#endif
	return col;
}

technique pku
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PkuPass;
	}
}
