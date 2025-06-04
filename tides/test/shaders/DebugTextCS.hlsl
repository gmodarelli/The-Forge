#include "Defines.hlsli"

// Ported from https://www.shadertoy.com/view/wdSSD1
#define MAX_INT_DIGITS 4

#define CHAR_SIZE float2(8, 12)
#define CHAR_SPACING float2(8, 12)

#define STRWIDTH(c) (c * CHAR_SPACING.x)
#define STRHEIGHT(c) (c * CHAR_SPACING.y)

static const float4 char_table[96] = {
	float4(0x000000,0x000000,0x000000,0x000000), // SP 	0
	float4(0x003078,0x787830,0x300030,0x300000), // !	1
	float4(0x006666,0x662400,0x000000,0x000000), // "	2
	float4(0x006C6C,0xFE6C6C,0x6CFE6C,0x6C0000), // #	3
	float4(0x30307C,0xC0C078,0x0C0CF8,0x303000), // $	4
	float4(0x000000,0xC4CC18,0x3060CC,0x8C0000), // %	5
	float4(0x0070D8,0xD870FA,0xDECCDC,0x760000), // &	6
	float4(0x003030,0x306000,0x000000,0x000000), // '	7
	float4(0x000C18,0x306060,0x603018,0x0C0000), // (	8
	float4(0x006030,0x180C0C,0x0C1830,0x600000), // )	9
	float4(0x000000,0x663CFF,0x3C6600,0x000000), // *	10
	float4(0x000000,0x18187E,0x181800,0x000000), // +	11
	float4(0x000000,0x000000,0x000038,0x386000), // ,	12
	float4(0x000000,0x0000FE,0x000000,0x000000), // -	13
	float4(0x000000,0x000000,0x000038,0x380000), // .	14
	float4(0x000002,0x060C18,0x3060C0,0x800000), // /	15
	float4(0x007CC6,0xD6D6D6,0xD6D6C6,0x7C0000), // 0	16
	float4(0x001030,0xF03030,0x303030,0xFC0000), // 1	17
	float4(0x0078CC,0xCC0C18,0x3060CC,0xFC0000), // 2	18
	float4(0x0078CC,0x0C0C38,0x0C0CCC,0x780000), // 3	19
	float4(0x000C1C,0x3C6CCC,0xFE0C0C,0x1E0000), // 4	20
	float4(0x00FCC0,0xC0C0F8,0x0C0CCC,0x780000), // 5	21
	float4(0x003860,0xC0C0F8,0xCCCCCC,0x780000), // 6	22
	float4(0x00FEC6,0xC6060C,0x183030,0x300000), // 7	23
	float4(0x0078CC,0xCCEC78,0xDCCCCC,0x780000), // 8	24
	float4(0x0078CC,0xCCCC7C,0x181830,0x700000), // 0	25
	float4(0x000000,0x383800,0x003838,0x000000), // :	26
	float4(0x000000,0x383800,0x003838,0x183000), // ;	27
	float4(0x000C18,0x3060C0,0x603018,0x0C0000), // <	28
	float4(0x000000,0x007E00,0x7E0000,0x000000), // =	29
	float4(0x006030,0x180C06,0x0C1830,0x600000), // >	30
	float4(0x0078CC,0x0C1830,0x300030,0x300000), // ?	31
	float4(0x007CC6,0xC6DEDE,0xDEC0C0,0x7C0000), // @	32
	float4(0x003078,0xCCCCCC,0xFCCCCC,0xCC0000), // A	33
	float4(0x00FC66,0x66667C,0x666666,0xFC0000), // B	34
	float4(0x003C66,0xC6C0C0,0xC0C666,0x3C0000), // C	35
	float4(0x00F86C,0x666666,0x66666C,0xF80000), // D	36
	float4(0x00FE62,0x60647C,0x646062,0xFE0000), // E	37
	float4(0x00FE66,0x62647C,0x646060,0xF00000), // F	38
	float4(0x003C66,0xC6C0C0,0xCEC666,0x3E0000), // G	39
	float4(0x00CCCC,0xCCCCFC,0xCCCCCC,0xCC0000), // H	40
	float4(0x007830,0x303030,0x303030,0x780000), // I	41
	float4(0x001E0C,0x0C0C0C,0xCCCCCC,0x780000), // J	42
	float4(0x00E666,0x6C6C78,0x6C6C66,0xE60000), // K	43
	float4(0x00F060,0x606060,0x626666,0xFE0000), // L	44
	float4(0x00C6EE,0xFEFED6,0xC6C6C6,0xC60000), // M	45
	float4(0x00C6C6,0xE6F6FE,0xDECEC6,0xC60000), // N	46
	float4(0x00386C,0xC6C6C6,0xC6C66C,0x380000), // O	47
	float4(0x00FC66,0x66667C,0x606060,0xF00000), // P	48
	float4(0x00386C,0xC6C6C6,0xCEDE7C,0x0C1E00), // Q	49
	float4(0x00FC66,0x66667C,0x6C6666,0xE60000), // R	50
	float4(0x0078CC,0xCCC070,0x18CCCC,0x780000), // S	51
	float4(0x00FCB4,0x303030,0x303030,0x780000), // T	52
	float4(0x00CCCC,0xCCCCCC,0xCCCCCC,0x780000), // U	53
	float4(0x00CCCC,0xCCCCCC,0xCCCC78,0x300000), // V	54
	float4(0x00C6C6,0xC6C6D6,0xD66C6C,0x6C0000), // W	55
	float4(0x00CCCC,0xCC7830,0x78CCCC,0xCC0000), // X	56
	float4(0x00CCCC,0xCCCC78,0x303030,0x780000), // Y	57
	float4(0x00FECE,0x981830,0x6062C6,0xFE0000), // Z	58
	float4(0x003C30,0x303030,0x303030,0x3C0000), // [	59
	float4(0x000080,0xC06030,0x180C06,0x020000), // \	60
	float4(0x003C0C,0x0C0C0C,0x0C0C0C,0x3C0000), // ]	61
	float4(0x10386C,0xC60000,0x000000,0x000000), // ^	62
	float4(0x000000,0x000000,0x000000,0x00FF00), // _	63
	float4(0x000000,0x000000,0x000000,0x000000), // `	64 MISSING
	float4(0x000000,0x00780C,0x7CCCCC,0x760000), // a	65
	float4(0x00E060,0x607C66,0x666666,0xDC0000), // b	66
	float4(0x000000,0x0078CC,0xC0C0CC,0x780000), // c	67
	float4(0x001C0C,0x0C7CCC,0xCCCCCC,0x760000), // d	68
	float4(0x000000,0x0078CC,0xFCC0CC,0x780000), // e	69
	float4(0x00386C,0x6060F8,0x606060,0xF00000), // f	70
	float4(0x000000,0x0076CC,0xCCCC7C,0x0CCC78), // g	71
	float4(0x00E060,0x606C76,0x666666,0xE60000), // h	72
	float4(0x001818,0x007818,0x181818,0x7E0000), // i	73
	float4(0x000C0C,0x003C0C,0x0C0C0C,0xCCCC78), // j	74
	float4(0x00E060,0x60666C,0x786C66,0xE60000), // k	75
	float4(0x007818,0x181818,0x181818,0x7E0000), // l	76
	float4(0x000000,0x00FCD6,0xD6D6D6,0xC60000), // m	77
	float4(0x000000,0x00F8CC,0xCCCCCC,0xCC0000), // n	78
	float4(0x000000,0x0078CC,0xCCCCCC,0x780000), // o	79
	float4(0x000000,0x00DC66,0x666666,0x7C60F0), // p	80
	float4(0x000000,0x0076CC,0xCCCCCC,0x7C0C1E), // q	81
	float4(0x000000,0x00EC6E,0x766060,0xF00000), // r	82
	float4(0x000000,0x0078CC,0x6018CC,0x780000), // s	83
	float4(0x000020,0x60FC60,0x60606C,0x380000), // t	84
	float4(0x000000,0x00CCCC,0xCCCCCC,0x760000), // u	85
	float4(0x000000,0x00CCCC,0xCCCC78,0x300000), // v	86
	float4(0x000000,0x00C6C6,0xD6D66C,0x6C0000), // w	87
	float4(0x000000,0x00C66C,0x38386C,0xC60000), // x	88
	float4(0x000000,0x006666,0x66663C,0x0C18F0), // y	89
	float4(0x000000,0x00FC8C,0x1860C4,0xFC0000), // z	90
	float4(0x001C30,0x3060C0,0x603030,0x1C0000), // {	91
	float4(0x001818,0x181800,0x181818,0x180000), // |	92
	float4(0x00E030,0x30180C,0x183030,0xE00000), // }	93
	float4(0x0073DA,0xCE0000,0x000000,0x000000), // ~	94
	float4(0x000000,0x10386C,0xC6C6FE,0x000000), // DEL?
};

//Extracts bit b from the given number.
//Shifts bits right (num / 2^bit) then ANDs the result with 1 (mod(result,2.0)).
float extract_bit(float n, float b)
{
    b = clamp(b, -1.0, 24.0);
	// return floor(mod(floor(n / pow(2.0, floor(b))), 2.0));
	return floor(floor(n / pow(2.0, floor(b))) % 2.0);
}

//Returns the pixel at uv in the given bit-packed sprite.
float sprite(float4 spr, float2 size, float2 uv)
{
    uv = floor(uv);

    //Calculate the bit to extract (x + y * width) (flipped on x-axis)
    float bit = (size.x - uv.x -1.0) + uv.y * size.x;

    //Clipping bound to remove garbage outside the sprite's boundaries.
    // bool bounds = all(greaterThanEqual(uv, float2(0, 0))) && all(lessThan(uv, size));
	bool bounds = all(uv >= float2(0, 0)) && all(uv < size);

    float pixels = 0.0;
    pixels += extract_bit(spr.x, bit - 72.0);
    pixels += extract_bit(spr.y, bit - 48.0);
    pixels += extract_bit(spr.z, bit - 24.0);
    pixels += extract_bit(spr.w, bit - 00.0);

    return bounds ? pixels : 0.0;
}

//Prints a character and moves the print position forward by 1 character width.
float print_char(float4 ch, float2 uv, inout float2 print_position)
{
    float px = sprite(ch, CHAR_SIZE, uv - print_position);
    print_position.x += CHAR_SPACING.x;
    return px;
}

struct TextData
{
    float3 color;
    int scale;
    int2 offset;
	uint text_buffer_index;
	uint text_buffer_offset;
	uint text_length;
};

cbuffer g_CBO : register(b0, SPACE_PerFrame)
{
    TextData g_text_data;
};

RWTexture2D<float4> g_output : register(u1, SPACE_PerFrame);

float output_character(uint ascii_index, float2 uv, inout float2 print_position)
{
	float4 character = char_table[0];
	if (ascii_index < 96) {
		character = char_table[ascii_index];
	}

	return print_char(character, uv, print_position);
}

[RootSignature(ComputeRootSignature)]
[numthreads(32, 32, 1)]
void main(uint3 DTid : SV_DispatchThreadID, uint3 workGroupId : SV_GroupID, uint3 localInvocationId : SV_GroupThreadID)
{
	uint width;
	uint height;
	g_output.GetDimensions(width, height);

	float2 uv = float2(DTid.x, DTid.y);
	uv.y = height - uv.y;
	uv /= g_text_data.scale;

	float2 duv = floor(uv);

	float2 res = float2(width, height) / g_text_data.scale;

	ByteAddressBuffer text_buffer = ResourceDescriptorHeap[g_text_data.text_buffer_index];

	float2 shadow_print_position = floor(float2(STRWIDTH(g_text_data.offset.x) + 1, res.y - STRHEIGHT(g_text_data.offset.y) - 1));
	float2 print_position = floor(float2(STRWIDTH(g_text_data.offset.x), res.y - STRHEIGHT(g_text_data.offset.y)));
	float output_color = 0.0;
	float output_shadow = 0.0;

	for (uint i = 0; i < g_text_data.text_length; i++) {
    	uint ascii = text_buffer.Load<uint>((g_text_data.text_buffer_offset + i) * sizeof(uint));
		uint ch4 = ascii >> 24;
		uint ch3 = (ascii & 0x00ff0000) >> 16;
		uint ch2 = (ascii & 0x0000ff00) >> 8;
		uint ch1 = (ascii & 0x000000ff);

		output_color += output_character(ch1, uv, print_position);
		output_color += output_character(ch2, uv, print_position);
		output_color += output_character(ch3, uv, print_position);
		output_color += output_character(ch4, uv, print_position);

		output_shadow += output_character(ch1, uv, shadow_print_position);
		output_shadow += output_character(ch2, uv, shadow_print_position);
		output_shadow += output_character(ch3, uv, shadow_print_position);
		output_shadow += output_character(ch4, uv, shadow_print_position);
	}

	if (output_shadow > 0.0) {
		g_output[DTid.xy].rgb = saturate(g_output[DTid.xy].rgb - output_shadow);
	}

	if (output_color > 0.0) {
		g_output[DTid.xy].rgb += g_text_data.color * output_color;
	}
}