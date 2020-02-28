`timescale 1ns/1ps

module uart_receiver (
    clock,
    btu,
    reset_in,
    reset_ack,
    csize,
    parenb,
    parodd,
    rxd,
    char,
    received,
    error
);

    input clock;
    input [20:0] btu;
    input reset_in;
    output reset_ack;
    input [1:0] csize;
    input parenb;
    input parodd;
    input rxd;
    output [7:0] char;
    output received;
    output [2:0] error;

    reg reset_ack;
    reg [1:0] reset_internal_ack;

    reg [1:0] rxd_sample;
    reg bit_received;
    reg bit_value;
    reg [7:0] char;
    reg received;

    reg [20:0] btu_counter;

    reg [10:0] data_internal;

    reg parity;

    reg [2:0] error, error_next;

    reg [3:0] state, state_next;

    parameter [3:0] IDLE        = 4'h0;
    parameter [3:0] START_BIT   = 4'h1;
    parameter [3:0] BIT_0       = 4'h2;
    parameter [3:0] BIT_1       = 4'h3;
    parameter [3:0] BIT_2       = 4'h4;
    parameter [3:0] BIT_3       = 4'h5;
    parameter [3:0] BIT_4       = 4'h6;
    parameter [3:0] BIT_5       = 4'h7;
    parameter [3:0] BIT_6       = 4'h8;
    parameter [3:0] BIT_7       = 4'h9;
    parameter [3:0] PARITY_BIT  = 4'ha;
    parameter [3:0] STOP_BIT    = 4'hb;

    always @ (reset_internal_ack) begin
        reset_ack = (reset_internal_ack[0] & reset_internal_ack[1]);
    end

    always @ (negedge clock) begin
        if (reset_in == 1'b1) begin
            received <= 1'b0;
            error <= 3'b000;
            reset_internal_ack[0] <= 1'b1;
        end else begin
            reset_internal_ack[0] <= 1'b0;
            if ((state == START_BIT) && (data_internal[0] == 1'b0) && (received == 1'b0)) begin
                received <= 1'b1;
            end else begin
                received <= 1'b0;
            end
            error <= error_next;
        end
    end

    always @ (posedge clock) begin
        if (reset_in == 1'b1) begin
            rxd_sample <= 2'b11;
            bit_received <= 1'b0;
            bit_value <= 1'b0;
            btu_counter <= 21'h000000;
            data_internal <= 11'h7ff;
            state <= IDLE;
            parity <= 1'b0;
            reset_internal_ack[1] <= 1'b1;
        end else begin
            reset_internal_ack[1] <= 1'b0;
            rxd_sample <= {rxd_sample[0], rxd};
            if ((state == START_BIT) && (rxd_sample[1] == 1'b1) && (rxd_sample[0] == 1'b0)) begin
                btu_counter <= {1'b0, btu[20:1]};
            end else if (btu_counter == 21'h000000) begin
                bit_received <= 1'b1;
                bit_value <= rxd_sample[1];
                if (csize == 2'b11) begin
                    if (parenb == 1'b1) begin
                        data_internal <= {rxd_sample[1], data_internal[10:1]};
                    end else begin
                        data_internal <= {1'b1, rxd_sample[1], data_internal[9:1]};
                    end
                    char <= data_internal[9:2];
                    parity <= (data_internal[3] ^ data_internal[4] ^ data_internal[5] ^ data_internal[6] ^ data_internal[7] ^ data_internal[8] ^ data_internal[9] ^ data_internal[10] ^ parodd);
                end else if (csize == 2'b10) begin
                    if (parenb == 1'b1) begin
                        data_internal <= {1'b1, rxd_sample[1], data_internal[9:1]};
                    end else begin
                        data_internal <= {2'b11, rxd_sample[1], data_internal[8:1]};
                    end
                    char <= {1'b0, data_internal[8:2]};
                    parity <= (data_internal[3] ^ data_internal[4] ^ data_internal[5] ^ data_internal[6] ^ data_internal[7] ^ data_internal[8] ^ data_internal[9] ^ parodd);
                end else if (csize == 2'b01) begin
                    if (parenb == 1'b1) begin
                        data_internal <= {2'b11, rxd_sample[1], data_internal[8:1]};
                    end else begin
                        data_internal <= {3'b111, rxd_sample[1], data_internal[7:1]};
                    end
                    char <= {2'b00, data_internal[7:2]};
                    parity <= (data_internal[3] ^ data_internal[4] ^ data_internal[5] ^ data_internal[6] ^ data_internal[7] ^ data_internal[8] ^ parodd);
                end else begin
                    if (parenb == 1'b1) begin
                        data_internal <= {3'b111, rxd_sample[1], data_internal[7:1]};
                    end else begin
                        data_internal <= {4'b1111, rxd_sample[1], data_internal[6:1]};
                    end
                    char <= {3'b000, data_internal[6:2]};
                    parity <= (data_internal[3] ^ data_internal[4] ^ data_internal[5] ^ data_internal[6] ^ data_internal[7] ^ parodd);
                end
                btu_counter <= btu;
            end else begin
                btu_counter <= btu_counter - 1'b1;
                bit_received <= 1'b0;
            end
            state <= state_next;
            case (state)
                IDLE: begin
                    data_internal <= 11'h7ff;
                end
                START_BIT: begin
                    if ((data_internal[0] == 1'b0) && (received == 1'b1)) begin
                        data_internal <= 11'h7ff;
                    end
                end
            endcase
        end
    end

    always @ (state or bit_received or bit_value or csize or parenb or parity) begin
        case (state)
            IDLE: begin
                if (bit_received == 1'b1) begin
                    if (bit_value == 1'b1) begin
                        state_next = START_BIT;
                        error_next = 3'b000;
                    end else begin
                        state_next = IDLE;
                        error_next = 3'b100;
                    end
                end else begin
                    state_next = IDLE;
                    error_next = 3'b000;
                end
            end
            START_BIT: begin
                if ((bit_received == 1'b1) && (bit_value == 1'b0)) begin
                    state_next = BIT_0;
                end else begin
                    state_next = START_BIT;
                end
                error_next = 3'b000;
            end
            BIT_0: begin
                if (bit_received == 1'b1) begin
                    state_next = BIT_1;
                end else begin
                    state_next = BIT_0;
                end
                error_next = 3'b000;
            end
            BIT_1: begin
                if (bit_received == 1'b1) begin
                    state_next = BIT_2;
                end else begin
                    state_next = BIT_1;
                end
                error_next = 3'b000;
            end
            BIT_2: begin
                if (bit_received == 1'b1) begin
                    state_next = BIT_3;
                end else begin
                    state_next = BIT_2;
                end
                error_next = 3'b000;
            end
            BIT_3: begin
                if (bit_received == 1'b1) begin
                    state_next = BIT_4;
                end else begin
                    state_next = BIT_3;
                end
                error_next = 3'b000;
            end
            BIT_4: begin
                if (bit_received == 1'b1) begin
                    if (csize == 2'b00) begin
                        if (parenb == 1'b1) begin
                            state_next = PARITY_BIT;
                        end else begin
                            state_next = STOP_BIT;
                        end
                    end else begin
                        state_next = BIT_5;
                    end
                end else begin
                    state_next = BIT_4;
                end
                error_next = 3'b000;
            end
            BIT_5: begin
                if (bit_received == 1'b1) begin
                    if (csize == 2'b01) begin
                        if (parenb == 1'b1) begin
                            state_next = PARITY_BIT;
                        end else begin
                            state_next = STOP_BIT;
                        end
                    end else begin
                        state_next = BIT_6;
                    end
                end else begin
                    state_next = BIT_5;
                end
                error_next = 3'b000;
            end
            BIT_6: begin
                if (bit_received == 1'b1) begin
                    if (csize == 2'b10) begin
                        if (parenb == 1'b1) begin
                            state_next = PARITY_BIT;
                        end else begin
                            state_next = STOP_BIT;
                        end
                    end else begin
                        state_next = BIT_7;
                    end
                end else begin
                    state_next = BIT_6;
                end
                error_next = 3'b000;
            end
            BIT_7: begin
                if (bit_received == 1'b1) begin
                    if (parenb == 1'b1) begin
                        state_next = PARITY_BIT;
                    end else begin
                        state_next = STOP_BIT;
                    end
                end else begin
                    state_next = BIT_7;
                end
                error_next = 3'b000;
            end
            PARITY_BIT: begin
                if (bit_received == 1'b1) begin
                    if (bit_value == parity) begin
                        state_next = STOP_BIT;
                        error_next = 3'b000;
                    end else begin
                        state_next = IDLE;
                        error_next = 3'b001;
                    end
                end else begin
                    state_next = PARITY_BIT;
                    error_next = 3'b000;
                end
            end
            STOP_BIT: begin
                if (bit_received == 1'b1) begin
                    if (bit_value == 1'b1) begin
                        state_next = START_BIT;
                        error_next = 3'b000;
                    end else begin
                        state_next = IDLE;
                        error_next = 3'b010;
                    end
                end else begin
                    state_next = STOP_BIT;
                    error_next = 3'b000;
                end
            end
            default: begin
                state_next = IDLE;
                error_next = 3'b000;
            end
        endcase
    end

endmodule

module uart_transmitter (
    clock,
    btu,
    reset_in,
    reset_ack,
    csize,
    cstopb,
    parenb,
    parodd,
    char,
    load,
    txd,
    transmitted
);

    input clock;
    input [20:0] btu;
    input reset_in;
    output reset_ack;
    input [1:0] csize;
    input cstopb;
    input parenb;
    input parodd;
    input [7:0] char;
    input load;
    output txd;
    output transmitted;

    reg reset_ack;
    reg [1:0] reset_internal_ack;

    reg [20:0] btu_counter;
    reg [10:0] serializer;
    reg done;
    reg txd;
    reg transmitted;
    reg parity;
    reg [7:0] char_internal;

    always @ (reset_internal_ack) begin
        reset_ack = (reset_internal_ack[0] & reset_internal_ack[1]);
    end

    always @ (char_internal or csize or parodd) begin
        if (csize == 2'b11) begin
            parity = (char_internal[0] ^ char_internal[1] ^ char_internal[2] ^ char_internal[3] ^ char_internal[4] ^ char_internal[5] ^ char_internal[6] ^ char_internal[7] ^ parodd);
        end else if (csize == 2'b10) begin
            parity = (char_internal[0] ^ char_internal[1] ^ char_internal[2] ^ char_internal[3] ^ char_internal[4] ^ char_internal[5] ^ char_internal[6] ^ parodd);
        end else if (csize == 2'b01) begin
            parity = (char_internal[0] ^ char_internal[1] ^ char_internal[2] ^ char_internal[3] ^ char_internal[4] ^ char_internal[5] ^ parodd);
        end else begin
            parity = (char_internal[0] ^ char_internal[1] ^ char_internal[2] ^ char_internal[3] ^ char_internal[4] ^ parodd);
        end
    end

    always @ (posedge clock) begin
        if (reset_in == 1'b1) begin
            btu_counter <= 21'h000000;
            serializer <= 11'h000;
            done <= 1'b1;
            txd <= 1'b1;
            char_internal <= 8'h00;
            reset_internal_ack[0] <= 1'b1;
        end else begin
            reset_internal_ack[0] <= 1'b0;
            char_internal <= char;
            if (done == 1'b1) begin
                if (load == 1'b1) begin
                    if (csize == 2'b11) begin
                        if ((cstopb == 1'b1) && (parenb == 1'b1)) begin
                            serializer <= {2'b11, parity, char_internal};
                        end else if ((cstopb == 1'b0) && (parenb == 1'b1)) begin
                            serializer <= {2'b01, parity, char_internal};
                        end else if ((cstopb == 1'b1) && (parenb == 1'b0)) begin
                            serializer <= {3'b011, char_internal};
                        end else begin
                            serializer <= {3'b001, char_internal};
                        end
                    end else if (csize == 2'b10) begin
                        if ((cstopb == 1'b1) && (parenb == 1'b1)) begin
                            serializer <= {3'b011, parity, char_internal[6:0]};
                        end else if ((cstopb == 1'b0) && (parenb == 1'b1)) begin
                            serializer <= {3'b001, parity, char_internal[6:0]};
                        end else if ((cstopb == 1'b1) && (parenb == 1'b0)) begin
                            serializer <= {4'b0011, char_internal[6:0]};
                        end else begin
                            serializer <= {4'b0001, char_internal[6:0]};
                        end
                    end else if (csize == 2'b01) begin
                        if ((cstopb == 1'b1) && (parenb == 1'b1)) begin
                            serializer <= {4'b0011, parity, char_internal[5:0]};
                        end else if ((cstopb == 1'b0) && (parenb == 1'b1)) begin
                            serializer <= {4'b0001, parity, char_internal[5:0]};
                        end else if ((cstopb == 1'b1) && (parenb == 1'b0)) begin
                            serializer <= {5'b00011, char_internal[5:0]};
                        end else begin
                            serializer <= {5'b00001, char_internal[5:0]};
                        end
                    end else begin
                        if ((cstopb == 1'b1) && (parenb == 1'b1)) begin
                            serializer <= {5'b00011, parity, char_internal[4:0]};
                        end else if ((cstopb == 1'b0) && (parenb == 1'b1)) begin
                            serializer <= {5'b00001, parity, char_internal[4:0]};
                        end else if ((cstopb == 1'b1) && (parenb == 1'b0)) begin
                            serializer <= {6'b000011, char_internal[4:0]};
                        end else begin
                            serializer <= {6'b000001, char_internal[4:0]};
                        end
                    end
                    btu_counter <= btu;
                    txd <= 1'b0;
                    done <= 1'b0;
                end
            end else if (btu_counter == 21'h000001) begin
                if (serializer == 11'h000) begin
                    done <= 1'b1;
                end
                btu_counter <= 21'h000000;
            end else if (btu_counter == 21'h000000) begin
                btu_counter <= btu;
                txd <= serializer[0];
                serializer <= {1'b0, serializer[10:1]};
            end else begin
                btu_counter <= btu_counter - 1'b1;
            end
        end
    end

    always @ (negedge clock) begin
        if (reset_in == 1'b1) begin
            transmitted <= 1'b0;
            reset_internal_ack[1] <= 1'b1;
        end else begin
            reset_internal_ack[1] <= 1'b0;
            if ((serializer == 11'h001) && (btu_counter == 21'h000001) && (transmitted == 1'b0)) begin
                transmitted <= 1'b1;
            end else begin
                transmitted <= 1'b0;
            end
        end
    end

endmodule
