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
 * Module: tone_generator
 * Description:
        If one of the two inputs ('dit' and 'dah') or both are high,
        a square wave signal with 600 Hz is generated at the output.
        The generated tone is realized by using a counter.
        A clock of 1MHz is assumed at input 'clk'.
*/

`default_nettype none

module tone_generator (
    // Inputs
    input  clk,
    input  rst,
    input  dit,
    input  dah,

    // Output
    output tone_out
);

    // Constant parameters
    localparam SIZE_COUNTER = 10;       // 11-Bit counter
    localparam MAX_COUNT    = 10'h341;  // 600 Hz with 1MHz clock, for testing: 10'h8

    // Internal registers
    reg [SIZE_COUNTER-1:0] counter;
    reg [SIZE_COUNTER-1:0] next_counter;
    reg tone_output;
    reg next_tone_output;

    // Register process
    always @(posedge clk) begin
        if (rst) begin
            counter     <= {SIZE_COUNTER{1'b0}};
            tone_output <= 1'b0;
        end else begin
            counter     <= next_counter;
            tone_output <= next_tone_output;
        end
    end

    // Sequential logic
    always @(*) begin
    	// Default assignment
    	next_counter = counter;
    	next_tone_output = tone_output;
    	
        if (dit || dah) begin
            if (counter >= MAX_COUNT) begin
                // Toggle output and reset counter
                next_tone_output = ~tone_output;
                next_counter = {SIZE_COUNTER{1'b0}};
            end else begin
                // Count up
                next_counter = counter + {{(SIZE_COUNTER-1){1'b0}}, 1'b1};
                next_tone_output = tone_output;
            end
        end else begin
            // Reset counter
            next_counter     = {SIZE_COUNTER{1'b0}};
            next_tone_output = 1'b0;
        end
    end
    
    // Combinatoric logic
    assign tone_out = tone_output;

endmodule
