/* 
    Copyright 2024 Daniel Baumgartner

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE−2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

/*
 * Module: tt_um_ps2_morse_encoder_top
 * Description:
        Top module which initialises all other modules and connects them.
        Furthermore, all inputs and outputs are correctly assigned.
*/

`default_nettype none

module tt_um_ps2_morse_encoder_top (
    // Inputs
    input  wire       ena,      // Enable, will go high when the design is enabled
    input  wire       clk,      // Clock
    input  wire       rst_n,    // Reset - low to reset
    input  wire [7:0] ui_in,    // Connected to the input switches
    input  wire [7:0] uio_in,   // IOs: Bidirectional input path
    
    // Outputs
    output wire [7:0] uo_out,   // Connected to the 7 segment display
    output wire [7:0] uio_oe,   // IOs: Bidirectional enable path (active high: 0=input, 1=output)
    output wire [7:0] uio_out   // IOs: Bidirectional output path
);

    // Internal wires
    wire       reset =! rst_n;  // Inverted reset - high to reset
    wire [7:0] ps2_received_data;
    wire       ps2_received_data_strb;

    // Combinatoric logic
    assign uo_out[1] = 1'b0;
    assign uo_out[2] = 1'b0;
    assign uo_out[4] = 1'b0;
    assign uo_out[5] = 1'b0;
    assign uio_out   = 0;
    assign uio_oe    = 0;

    ps2_controller ps2_controller (
        // Inputs
        .clk(clk),
        .rst(reset),
        .ps2_clk(ui_in[0]),     // PS/2 clock
        .ps2_data(ui_in[1]),    // PS/2 data

        // Outputs
        .ps2_received_data(ps2_received_data),
        .ps2_received_data_strb(ps2_received_data_strb)
    );

    morse_code_encoder morse_code_encoder (
        // Inputs
        .clk(clk),
        .rst(reset),
        .ps2_received_data(ps2_received_data),
        .ps2_received_data_strb(ps2_received_data_strb),

        // Outputs
        .dit_out(uo_out[0]),        // Segment A of 7 segment display
        .dah_out(uo_out[3]),        // Segment D of 7 segment display
        .morse_code_out(uo_out[6])  // Segment G of 7 segment display
    );

    tone_generator tone_generator (
        // Inputs
        .clk(clk),
        .rst(reset),
        .dit(uo_out[0]),
        .dah(uo_out[3]),

        // Outputs
        .tone_out(uo_out[7])        // Segment DP of 7 segment display
    );
endmodule
