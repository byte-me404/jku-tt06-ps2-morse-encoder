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
 * Module: tb_custom_tests
 * Description:
        Custom testbench.
*/

`timescale 1ns / 1ns

// Include other modules
`include "project.v"
`include "ps2_controller.v"
`include "morse_code_encoder.v"
`include "tone_generator.v"

module tb_custom_tests ();

    // Registers and wires for testing
    reg  ps2_clk  = 1'b0;
    reg  ps2_data = 1'b1;
    wire dit_out;
    wire dah_out;
    wire morse_code_out;
    wire morse_tone_out;

    // Registers and wires for DUT
    reg  ena   = 1'b1;
    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    wire [7:0] ui_in;
    wire [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // DUT
    tt_um_ps2_morse_encoder_top tt_um_ps2_morse_encoder_top_DUT (
        // Inputs
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n),
        .ui_in(ui_in),
        .uio_in(uio_in),

        // Outputs
        .uo_out(uo_out),
        .uio_oe(uio_oe),
        .uio_out(uio_out)
    );

    // Assign values
    assign dit_out = uo_out[0];
    assign dah_out = uo_out[3];
    assign morse_code_out = uo_out[6];
    assign morse_tone_out = uo_out[7];
    assign ui_in[0] = ps2_clk;
    assign ui_in[1] = ps2_data;

    /* verilator lint_off STMTDLY */
    always #500 clk = ~clk;             // System-Clock 1MHz
    always #40000 ps2_clk = ~ps2_clk;   // Simulated PS/2 clock 12kHz
    /* verilator lint_on STMTDLY */

    initial begin
        $dumpfile("tb_ps2_controller.vcd");
        $dumpvars;

        /* verilator lint_off STMTDLY */
        #10000 rst_n = 1'b1;

        // Simulate PS/2 data
        // h1C (A) from Device to Host
        #619900 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h29 (Space) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h32 (B) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h1C (A) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // hF0 (Break-Code) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h21 (C) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h1C (A) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h29 (Space) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h32 (B) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h1C (A) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h1C (A) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h29 (Space) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h32 (B) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h1C (A) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h21 (C) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h1C (A) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h29 (Space) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h32 (B) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h1C (A) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h5A (Enter) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h1C (A) from Device to Host
        #120000000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h32 (B) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h21 (C) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h0C (F4) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        // h29 (Space) from Device to Host
        #640000 ps2_data = 1'b0;   // Start-Bit
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b1;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;
        #80000  ps2_data = 1'b0;    // Parity-Bit
        #80000  ps2_data = 1'b1;

        #40000000 $finish;
        /* verilator lint_on STMTDLY */
    end
endmodule
