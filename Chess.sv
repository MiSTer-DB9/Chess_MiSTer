module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_OSD + USER_PP, USER_IN/OUT widened to 8 bits
	output        USER_OSD,
	output  [7:0] USER_PP,
	input   [7:0] USER_IN,
	output  [7:0] USER_OUT,
	// [MiSTer-DB9 END]

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
//assign USER_OUT = '1;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP + USER_OUT drivers
assign USER_PP  = USER_PP_DRIVE;
assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = 1'b0;            // 1P-only: joy_2p unused
wire         snac_active     = 1'b0;
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire         pad_1_6btn, pad_2_6btn;
wire  [15:0] joy_raw_payload;

// [MiSTer-DB9 BEGIN] - DB9 programmable-remap matrix wires
// joydb_*_mapped = MiSTer-standard joystick words (consumed in Layer B);
// db9_remap_* = 0xFD selector stream driven by the hps_io instance.
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;
// [MiSTer-DB9 END]
joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_sys            ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .remap_cmd       ( db9_remap_cmd      ),
  .remap_byte_cnt  ( db9_remap_byte_cnt ),
  .remap_din       ( db9_remap_din      ),
  .joydb_1_mapped  ( joydb_1_mapped     ),
  .joydb_2_mapped  ( joydb_2_mapped     ),
  .pad_1_6btn      ( pad_1_6btn      ),
  .pad_2_6btn      ( pad_2_6btn      ),
  .joy_raw         ( joy_raw_payload )
);
// [MiSTer-DB9 END]

assign AUDIO_S   = 0;
assign AUDIO_L   = audio;
assign AUDIO_R   = AUDIO_L;
assign AUDIO_MIX = 0;

assign LED_USER  = 0;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

assign VIDEO_ARX = status[8] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[8] ? 8'd9  : 8'd3;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CKE, SDRAM_CLK, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

`include "build_id.v"
parameter CONF_STR = {
	"Chess;;",
	"-;",
	"O7,Opponent,AI,Human;",
	"O46,AI Strength,1,2,3,4,5,6,7;",
	"O23,AI Randomness,0,1,2,3;",
	"O1,Player Color,White,Black;",
	"O9,Boardview,White,Black;",
	"OA,Overlay,Off,On;",
   "-;",
	"O8,Aspect Ratio,4:3,16:9;",
	"-;",
	"R0,Reset;",
	// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
	"O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
	// [MiSTer-DB9-Pro END]
	"J1,Action,Cancel,SaveState,LoadState,Rewind;",
	"jn,A,B;",
	"jp,A,B;",
	"V,v",`BUILD_DATE
};

wire reset = RESET | status[0] | buttons[1];

wire [21:0] gamma_bus;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: status widened to 128 bits
wire [127:0] status;
// [MiSTer-DB9 END]

wire [2:0] buttons;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USB-side joystick renamed + joydb mux
wire [15:0] joyA_USB;
wire [15:0] joyA = joydb_1ena ? (OSD_STATUS ? 16'b0 : joydb_1_mapped[15:0]) : joyA_USB;
// [MiSTer-DB9 END]

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),

	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USB-side joystick renamed
	.joystick_0(joyA_USB),
	// [MiSTer-DB9 END]
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw for OSD autodetect
	.joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
	// programmable remap matrix selector load (UIO_DB9_MAP 0xFD)
	.db9_remap_cmd(db9_remap_cmd),
	.db9_remap_byte_cnt(db9_remap_byte_cnt),
	.db9_remap_din(db9_remap_din),
	// [MiSTer-DB9 END]
	// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
	.saturn_unlocked(saturn_unlocked),
	// [MiSTer-DB9-Pro END]

	.status(status),
	.gamma_bus(gamma_bus)
);


wire clk;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk)
);

wire [15:0] audio = {1'b0, speaker, 14'd0};
wire speaker;

wire vsync, hsync, vblank, hblank;
wire [7:0] red, green, blue;

TopModule Chess (
	.Clk(clk),
	.reset(reset),
   .mirrorBoard(status[9]),
   .aiOn(~status[7]),
   .strength(status[6:4]),
   .randomness(status[3:2]),
   .playerBlack(status[1]),
   .overlayOn(status[10]),
   .input_up(joyA[3]),
   .input_down(joyA[2]),
   .input_left(joyA[1]),
   .input_right(joyA[0]),
   .input_action(joyA[4]),
   .input_cancel(joyA[5]),
   .input_save(joyA[6]),
   .input_load(joyA[7]),
   .input_rewind(joyA[8]),
	.vga_h_sync(hsync),
	.vga_v_sync(vsync),
	.vga_h_blank(hblank),
	.vga_v_blank(vblank),
	.vga_R(red),
	.vga_G(green),
	.vga_B(blue),
	.Speaker(speaker)
);

assign VGA_F1 = 0;
assign VGA_SL = 0;
assign CLK_VIDEO = clk;
assign CE_PIXEL = 1;

gamma_fast gamma
(
	.clk_vid(CLK_VIDEO),
	.ce_pix(1),

	.gamma_bus(gamma_bus),

	.HSync(hsync),
	.VSync(vsync),
	.DE(~(hblank | vblank)),
	.RGB_in({red, green, blue}),

	.HSync_out(VGA_HS),
	.VSync_out(VGA_VS),
	.DE_out(VGA_DE),
	.RGB_out({VGA_R, VGA_G, VGA_B})
);


endmodule
