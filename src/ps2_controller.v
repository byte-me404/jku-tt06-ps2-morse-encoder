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
 * Module: ps2_controller
 * Description:
        This module has 'ps2_clk' and 'ps2_data' as input.
        The scancodes sent from the keyboard are decoded and stored in the variable 'ps2_received_data'.
        Internally a FSM is used. As soon as a data frame has been processed,
        a strobe is output ('ps2_received_data_strb'), which signals that the data is available.
*/

`default_nettype none

module ps2_controller (
    // Inputs
    input        clk,
    input        rst,
    input        ps2_clk,
    input        ps2_data,

    // Outputs
    output [7:0] ps2_received_data,
    output       ps2_received_data_strb
);

    // Internal wires
    wire ps2_clk_posedge;

    // Internal registers
    reg [3:0] data_count;
    reg [3:0] next_data_count;
    reg [7:0] data_shift_reg;
    reg [7:0] next_data_shift_reg;
    reg [7:0] received_data;
    reg [7:0] next_received_data;
    reg [2:0] receiver_state;
    reg [2:0] next_receiver_state;
    reg       received_data_strb;
    reg       next_received_data_strb;
    reg       last_ps2_clk;

    // FSM-States
    localparam PS2_STATE_0_IDLE      = 3'h0,
               PS2_STATE_1_DATA_IN   = 3'h1,
               PS2_STATE_2_PARITY_IN = 3'h2,
               PS2_STATE_3_STOP_IN   = 3'h3;

    // Register process
    always @(posedge clk) begin
        if (rst) begin
            receiver_state     <= PS2_STATE_0_IDLE;
            data_count         <= 4'h0;
            data_shift_reg     <= 8'h00;
            received_data      <= 8'h00;
            received_data_strb <= 1'b0;
        end else begin
            receiver_state     <= next_receiver_state;
            data_count         <= next_data_count;
            data_shift_reg     <= next_data_shift_reg;
            received_data      <= next_received_data;
            received_data_strb <= next_received_data_strb;
            last_ps2_clk       <= ps2_clk;
        end
    end

    // Sequential logic
    always @(*) begin
        // Default assignment
        next_receiver_state     = PS2_STATE_0_IDLE;
        next_data_count         = data_count;
        next_data_shift_reg     = data_shift_reg;
        next_received_data      = received_data;
        next_received_data_strb = 1'b0;

        // FSM
        case (receiver_state)
            PS2_STATE_0_IDLE:
                begin
                    // Wait for data
                    // Keyboard starts transmission of data by pulling the data line low (start bit)
                    if (!ps2_data && ps2_clk_posedge && !received_data_strb)
                        next_receiver_state = PS2_STATE_1_DATA_IN;
                    else
                        next_receiver_state = PS2_STATE_0_IDLE;
                end
            PS2_STATE_1_DATA_IN:
                begin
                    // After the start bit there are eight data bits (LSB first)
                    if (ps2_clk_posedge) begin
                        if (data_count == 4'h7) begin
                            // Reset counter
                            next_data_count = 4'h0;
                            // After the data bits comes the parity bit
                            next_receiver_state = PS2_STATE_2_PARITY_IN;
                        end else begin
                            next_data_count = data_count + 4'h1;
                            next_receiver_state = PS2_STATE_1_DATA_IN;
                        end
                        // Store current bit in shift register at positiv clock edge
                        next_data_shift_reg = {ps2_data, data_shift_reg[7:1]};
                    end else
                        next_receiver_state = PS2_STATE_1_DATA_IN;
                end
            PS2_STATE_2_PARITY_IN:
                begin
                    if (ps2_clk_posedge)
                        // After the parity bit comes the stop bit
                        next_receiver_state = PS2_STATE_3_STOP_IN;
                    else
                        // Wait for parity bit
                        next_receiver_state = PS2_STATE_2_PARITY_IN;
                end
            PS2_STATE_3_STOP_IN:
                begin
                    if (ps2_clk_posedge) begin
                        // Trigger strobe and return to IDLE
                        next_received_data_strb = 1'b1;
                        next_receiver_state = PS2_STATE_0_IDLE;
                    end else begin
                        next_receiver_state = PS2_STATE_3_STOP_IN;
                    end
                    next_received_data = data_shift_reg;
                end
            default:
                begin
                    next_receiver_state = PS2_STATE_0_IDLE;
                end
        endcase
    end

    // Combinatoric logic
    assign ps2_received_data      = received_data;
    assign ps2_received_data_strb = received_data_strb;
    assign ps2_clk_posedge        = (ps2_clk && !last_ps2_clk) ? 1'b1 : 1'b0;

endmodule
