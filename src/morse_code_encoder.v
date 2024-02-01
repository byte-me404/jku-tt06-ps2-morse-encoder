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
 * Module: morse_code_encoder
 * Description:
        If input 'ps2_received_data_strb' is high, the data from 'ps2_received_data' is stored in an internal buffer (shift register).
        The mode can be changed with F1 and F4. In mode 1 (F1), the data is output when scancode
        '5A' (ENTER) is present --> data in the shift register is output in sequence as Morse code.
        In mode 2 (F4), the data is output when scan code '29' (SPACE) is present.
        The generation of the Morse code is realized by a counter.
        The timings are configured so that a Morse signal of approx. 15 WPM is generated.
        'dit_out' and 'dah_out' are used as outputs.
*/

`default_nettype none

module morse_code_encoder (
    // Inputs
    input       clk,
    input       rst,
    input [7:0] ps2_received_data,
    input       ps2_received_data_strb,

    // Output
    output      dit_out,
    output      dah_out,
    output      morse_code_out
);

    // Constant parameters
    localparam BUFFER_LENGTH       = 4'hC;  // Input buffer (12)
    localparam SIZE_DATA_COUNTER   = 4;     // 4-Bit counter
    localparam SIZE_TIMING_COUNTER = 21;    // 21-Bit counter

    // Counter values for tone generation, about 15 WPM (Word per Minute) at 1MHz clock
    localparam [SIZE_TIMING_COUNTER-1:0] DIT_TIME             = 80000;    // 80ms, for testing: 800
    localparam [SIZE_TIMING_COUNTER-1:0] DAH_TIME             = 240000;   // 240ms, for testing: 2400
    localparam [SIZE_TIMING_COUNTER-1:0] BETWEEN_DIT_DAH_TIME = 80000;    // 80ms, for testing: 800
    localparam [SIZE_TIMING_COUNTER-1:0] BETWEEN_CHAR_TIME    = 240000;   // 240ms, for testing: 2400
    localparam [SIZE_TIMING_COUNTER-1:0] SPACE_TIME           = 560000;   // 560ms, fot testing: 5600
    
    // Scancodes for diffrent keys
    localparam BREAK_CODE = 8'hF0;
    localparam ENTER      = 8'h5A;
    localparam SPACE      = 8'h29;
    localparam F1_KEY     = 8'h05;
    localparam F4_KEY     = 8'h0C;
    //localparam F6_KEY     = 8'h0B;
    
    // Internal registers
    reg [(BUFFER_LENGTH*8)-1:0]   data_shift_reg;
    reg [(BUFFER_LENGTH*8)-1:0]   next_data_shift_reg;
    reg [SIZE_DATA_COUNTER-1:0]   data_counter;
    reg [SIZE_DATA_COUNTER-1:0]   next_data_counter;
    reg [SIZE_TIMING_COUNTER-1:0] timing_counter;
    reg [SIZE_TIMING_COUNTER-1:0] next_timing_counter;
    reg [2:0] encoding_state;
    reg [2:0] next_encoding_state;
    reg [7:0] current_scancode;  
    reg [7:0] next_scancode;  
    reg operation_mode;            // 0 - Output when ENTER, 1 - Ouput when SPACE
    reg next_operation_mode;
    reg dit;
    reg next_dit;
    reg dah;
    reg next_dah;


    // FSM-States
    localparam ENCODING_STATE_0_IDLE        = 3'h0,
               ENCODING_STATE_1_DATA_IN     = 3'h1,
               ENCODING_STATE_2_BREAK_CODE  = 3'h2,
               ENCODING_STATE_3_BUFFER_DATA = 3'h3,
               ENCODING_STATE_4_DATA_OUT    = 3'h4;
    localparam DEFAULT_SCANCODE             = 8'hFF,
               COUNT_DOWN                   = 8'h00;

    // Register process
    always @(posedge clk) begin
        if (rst) begin
            data_shift_reg      <= {BUFFER_LENGTH*8{1'b0}};
            data_counter        <= BUFFER_LENGTH - 4'h1;
            timing_counter      <= {SIZE_TIMING_COUNTER{1'b0}};
            encoding_state      <= ENCODING_STATE_0_IDLE;
            current_scancode    <= DEFAULT_SCANCODE;
            operation_mode      <= 1'b0;
            dit                 <= 1'b0;
            dah                 <= 1'b0;
        end else begin
            data_shift_reg      <= next_data_shift_reg;
            data_counter        <= next_data_counter;
            timing_counter      <= next_timing_counter;
            encoding_state      <= next_encoding_state;
            current_scancode    <= next_scancode;
            operation_mode      <= next_operation_mode;
            dit                 <= next_dit;
            dah                 <= next_dah;
        end
    end

    // Sequential logic
    always @(*) begin
        // Default assignment
        next_data_shift_reg     = data_shift_reg;
        next_data_counter       = data_counter;
        next_timing_counter     = timing_counter;
        next_encoding_state     = ENCODING_STATE_0_IDLE;
        next_scancode           = DEFAULT_SCANCODE;       
        next_operation_mode     = operation_mode;
        next_dit                = dit;
        next_dah                = dah;

        // FSM
        case (encoding_state)
            ENCODING_STATE_0_IDLE:
                begin
                    // Wait for data
                    if (ps2_received_data_strb)
                        next_encoding_state = ENCODING_STATE_1_DATA_IN;
                    else
                        next_encoding_state = ENCODING_STATE_0_IDLE;
                end
            ENCODING_STATE_1_DATA_IN:
                begin
                    if (ps2_received_data == BREAK_CODE)
                        // Do not store break codes
                        next_encoding_state = ENCODING_STATE_2_BREAK_CODE;
                    else
                        // Store data in buffer
                        next_encoding_state = ENCODING_STATE_3_BUFFER_DATA;
                end
            ENCODING_STATE_2_BREAK_CODE:
                begin
                    // If an break code is detected, the system waits for the next scan code,
                    // which indicates which button has been released. This scan code should not be saved,
                    // as it was already saved when the key was pressed.
                    if (ps2_received_data_strb)
                        next_encoding_state = ENCODING_STATE_0_IDLE;
                    else
                        next_encoding_state = ENCODING_STATE_2_BREAK_CODE;
                end
            ENCODING_STATE_3_BUFFER_DATA:
                begin
                    if ((ps2_received_data == SPACE && operation_mode == 1'b1) || ps2_received_data == ENTER)
                        // Depending on the mode the data is ouput when SPACE or ENTER gets pressed
                        next_encoding_state = ENCODING_STATE_4_DATA_OUT;
                    else begin
                        if (ps2_received_data >= 8'h15 && ps2_received_data <= 8'h4D) begin
                            if (ps2_received_data != 8'h1F &&
                                ps2_received_data != 8'h27 &&
                                (ps2_received_data != 8'h29 || operation_mode != 1'b1) &&
                                ps2_received_data != 8'h2F &&
                                ps2_received_data != 8'h41 &&
                                ps2_received_data != 8'h49 &&
                                ps2_received_data != 8'h4A &&
                                ps2_received_data != 8'h4C) begin
                                // Only numbers and letters get stored
                                // Last scancode is at LSB position
                                next_data_shift_reg = {data_shift_reg[(BUFFER_LENGTH*8)-1-8:0], ps2_received_data};
                            end
                        end else if (ps2_received_data == F1_KEY)
                            // Chang operation mode to ouput when ENTER gets pressed
                            next_operation_mode = 1'b0;
                        else if (ps2_received_data == F4_KEY)
                            // Chang operation mode to ouput when SPACE gets pressed
                            next_operation_mode = 1'b1;
                        
                        next_encoding_state = ENCODING_STATE_0_IDLE;

                        /* Easter Egg
                        if (ps2_received_data == F6_KEY) begin
                            next_data_shift_reg = 96'h2C4331352C1C4D24443C2C;
                            next_encoding_state = ENCODING_STATE_4_DATA_OUT;
                        end*/
                    end
                end
            ENCODING_STATE_4_DATA_OUT:
                begin
                    next_encoding_state = ENCODING_STATE_4_DATA_OUT;

                    if (timing_counter == {SIZE_TIMING_COUNTER{1'b1}}) begin
                        // Reset timing counter
                        next_timing_counter = {SIZE_TIMING_COUNTER{1'b0}};
                    end else begin
                        // Advance timing counter
                        next_timing_counter = timing_counter + {{(SIZE_TIMING_COUNTER-1){1'b0}}, 1'b1};
                    end

                    // FSM
                    case(current_scancode)
                        DEFAULT_SCANCODE:
                            begin
                                // Reset timing counter
                                next_timing_counter = {SIZE_TIMING_COUNTER{1'b0}};
                                // Get next scancode
                                next_scancode = data_shift_reg[(data_counter+1)*8-1 -: 8];
                            end
                        COUNT_DOWN:
                            begin
                                if (data_counter == {SIZE_DATA_COUNTER{1'b0}}) begin
                                    next_data_counter   = BUFFER_LENGTH - 4'h1;    // Reset data counter
                                    next_data_shift_reg = {BUFFER_LENGTH*8{1'b0}}; // Clear receive buffer
                                    next_encoding_state = ENCODING_STATE_0_IDLE;   // Next state --> Wait for data
                                end else begin
                                    // Decrement the data counter to get the next scan code in the next state
                                    next_data_counter = data_counter - {{(SIZE_DATA_COUNTER-1){1'b0}}, 1'b1};
                                end
                                next_scancode = DEFAULT_SCANCODE;
                            end    
                        // Morse code generation for the corresponding scan code
                        8'h1C:    // A
                            begin
                                next_scancode = 8'h1C;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME + DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME + DAH_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else begin
                                    next_scancode = COUNT_DOWN;
                                end
                            end
                        8'h32:    // B
                            begin
                                next_scancode = 8'h32;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h21:    // C
                            begin
                                next_scancode = 8'h21;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h23:    // D
                            begin
                                next_scancode = 8'h23;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h24:    // E
                            begin
                                next_scancode = 8'h24;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h2B:    // F
                            begin
                                next_scancode = 8'h2B;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h34:    // G
                            begin
                                next_scancode = 8'h34;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h33:    // H
                            begin
                                next_scancode = 8'h33;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 4 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 4 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h43:    // I
                            begin
                                next_scancode = 8'h43;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h3B:    // J
                            begin
                                next_scancode = 8'h3B;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h42:    // K
                            begin
                                next_scancode = 8'h42;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h4B:    // L
                            begin
                                next_scancode = 8'h4B;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h3A:    // M
                            begin
                                next_scancode = 8'h3A;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h31:    // N
                            begin
                                next_scancode = 8'h31;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h44:    // O
                            begin
                                next_scancode = 8'h44;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h4D:    // P
                            begin
                                next_scancode = 8'h4D;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h15:    // Q
                            begin
                                next_scancode = 8'h15;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h2D:    // R
                            begin
                                next_scancode = 8'h2D;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h1B:    // S
                            begin
                                next_scancode = 8'h1B;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h2C:    // T
                            begin
                                next_scancode = 8'h2C;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < DAH_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h3C:    // U
                            begin
                                next_scancode = 8'h3C;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h2A:    // V
                            begin
                                next_scancode = 8'h2A;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h1D:    // W
                            begin
                                next_scancode = 8'h1D;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h22:    // X
                            begin
                                next_scancode = 8'h22;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h35:    // Y
                            begin
                                next_scancode = 8'h35;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h1A:    // Z
                            begin
                                next_scancode = 8'h1A;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h45:    // 0
                            begin
                                next_scancode = 8'h45;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 4 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 4 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 5 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 5 * DAH_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h16:    // 1
                            begin
                                next_scancode = 8'h16;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 4 * DAH_TIME + DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 4 * DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h1E:    // 2
                            begin
                                next_scancode = 8'h1E;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + 2 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h26:    // 3
                            begin
                                next_scancode = 8'h26;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 3 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 3 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h25:    // 4
                            begin
                                next_scancode = 8'h25;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 4 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 4 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 4 * DIT_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 4 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dah = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h2E:    // 5
                            begin
                                next_scancode = 8'h2E;
                                if (timing_counter < DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 4 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 4 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 5 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 5 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h36:    // 6
                            begin
                                next_scancode = 8'h36;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 4 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + DAH_TIME + 4 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h3D:    // 7
                            begin
                                next_scancode = 8'h3D;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 *DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 3 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME + 3 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h3E:    // 8
                            begin
                                next_scancode = 8'h3E;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + 2 * DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME + 2 * DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        8'h46:    // 9
                            begin
                                next_scancode = 8'h46;
                                if (timing_counter < DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 2 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 2 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 3 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 3 * BETWEEN_DIT_DAH_TIME + 4 * DAH_TIME)
                                    next_dah = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 4 * DAH_TIME)
                                    next_dah = 1'b0;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 4 * DAH_TIME + DIT_TIME)
                                    next_dit = 1'b1;
                                else if (timing_counter < 4 * BETWEEN_DIT_DAH_TIME + 4 * DAH_TIME + DIT_TIME + BETWEEN_CHAR_TIME)
                                    next_dit = 1'b0;
                                else
                                    next_scancode = COUNT_DOWN;
                            end
                        SPACE:    // SPACE
                            begin
                                next_scancode = 8'h29;
                                if (timing_counter < SPACE_TIME) begin
                                    next_dit = 1'b0;
                                    next_dah = 1'b0;
                                end else
                                    next_scancode = COUNT_DOWN;
                            end
                        default:
                            begin
                                next_scancode = DEFAULT_SCANCODE;
                            end
                    endcase
                end
            default:
                begin
                    next_encoding_state = ENCODING_STATE_0_IDLE;
                end
        endcase
    end
    
    // Combinatoric logic
    assign dit_out = dit;
    assign dah_out = dah;
    assign morse_code_out = dit_out | dah_out;
    
endmodule
