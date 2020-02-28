`timescale 1ns/1ps

module uart_tb ();

    reg [1:0] csize = 2'b11;
    reg cstopb = 1'b0;
    reg parenb = 1'b0;
    reg parodd = 1'b0;

    wire [7:0] tx_data_mem[0:255];
    reg [7:0] tx_data;
    reg [8:0] tx_data_pos = 9'h000;
    reg [8:0] tx_data_len = 9'h000;
    reg tx_data_load = 1'b0;

    reg [2:0] clock = 3'b000;
    reg [1:0] clock_selector = 2'b00;

    reg rst = 1'b0;
    reg rxd = 1'b0;
    wire data_received;
    wire [7:0] data_rx;

    wire rx_rst_ack;
    wire tx_rst_ack;

    reg tx_clock;

    wire txd;
    wire tx_complete;

    uart_receiver receiver (
        .clock(clock[0]),
        .btu(21'd319),
        .reset_in(rst),
        .reset_ack(rx_rst_ack),
        .csize(csize),
        .parenb(parenb),
        .parodd(parodd),
        .rxd(rxd),
        .char(data_rx),
        .received(data_received)
    );

    uart_transmitter transmitter (
        .clock(tx_clock),
        .btu(21'd319),
        .reset_in(rst),
        .reset_ack(tx_rst_ack),
        .csize(csize),
        .cstopb(cstopb),
        .parenb(parenb),
        .parodd(parodd),
        .char(tx_data),
        .load(tx_data_load),
        .txd(txd),
        .transmitted(tx_complete)
    );

    genvar i;
    generate
        for (i = 0; i < 256; i = i + 1) begin: mem
            assign tx_data_mem[i] = i;
        end
    endgenerate

    always begin
        #1 clock[0] = ~clock[0];
    end

    always begin
        #0.985 clock[1] = ~clock[1];
    end

    always begin
        #1.015 clock[2] = ~clock[2];
    end

    always @ (clock or clock_selector) begin
        case (clock_selector)
            2'b00: tx_clock = clock[0];
            2'b01: tx_clock = clock[1];
            2'b10: tx_clock = clock[2];
            default: tx_clock = clock[0];
        endcase
    end

    always @ (tx_data_pos or tx_data_len) begin
        if (tx_data_pos == tx_data_len) begin
            tx_data_load = 1'b0;
        end else begin
            tx_data_load = 1'b1;
        end
    end

    always @ (negedge tx_clock) begin
        if (rst == 1'b1) begin
            tx_data_pos <= 9'h000;
        end else begin
            if (tx_complete == 1'b1) begin
                tx_data_pos <= tx_data_pos + 1'b1;
            end
        end
        tx_data <= tx_data_mem[tx_data_pos];
    end

    initial begin
        $dumpfile("uart_tb.lxt");
        $dumpvars(0, uart_tb);
        #1 rst = 1;
        #640 rst = 0;
    end

    initial begin
        #0 rxd = 1;        // idle
        #30000 rxd = 0;    // start bit
        #640 rxd = 1;    // bit 0
        #640 rxd = 0;    // bit 1
        #640 rxd = 1;    // bit 2
        #640 rxd = 0;    // bit 3
        #640 rxd = 1;    // bit 4
        #640 rxd = 0;    // bit 5
        #640 rxd = 1;    // bit 6
        #640 rxd = 0;    // bit 7
        #640 rxd = 1;    // stop bit - 0x55
        #640 rxd = 0;    // start bit
        #640 rxd = 0;    // bit 0
        #640 rxd = 1;    // bit 1
        #640 rxd = 0;    // bit 2
        #640 rxd = 1;    // bit 3
        #640 rxd = 0;    // bit 4
        #640 rxd = 1;    // bit 5
        #640 rxd = 0;    // bit 6
        #640 rxd = 1;    // bit 7
        #2000 rxd = 1;    // stop bit - 0xaa
        #640 rxd = 0;    // start bit
        #640 rxd = 1;    // bit 0
        #640 rxd = 1;    // bit 1
        #640 rxd = 1;    // bit 2
        #640 rxd = 1;    // bit 3
        #640 rxd = 0;    // bit 4
        #640 rxd = 0;    // bit 5
        #640 rxd = 0;    // bit 6
        #640 rxd = 0;    // bit 7
        #640 rxd = 1;    // stop bit - 0x0f
        #3200 rxd = 1;    // idle
        #640 rxd = 0;    // start bit
        #640 rxd = 0;    // bit 0
        #640 rxd = 0;    // bit 1
        #480 rxd = 0;    // bit 2
        #80 rxd = 1;    // bit 2 - glitch
        #80 rxd = 0;    // bit 2
        #640 rxd = 0;    // bit 3
        #640 rxd = 0;    // bit 4
        #640 rxd = 0;    // bit 5
        #640 rxd = 0;    // bit 6
        #640 rxd = 0;    // bit 7
        #640 rxd = 1;    // stop bit
        #4000 rxd = 1;    // idle
        #640 rxd = 0;    // start bit
        #640 rxd = 1;    // bit 0
        #640 rxd = 1;    // bit 1
        #640 rxd = 1;    // bit 2
        #640 rxd = 1;    // bit 3
        #640 rxd = 0;    // bit 4
        #640 rxd = 0;    // bit 5
        #640 rxd = 0;    // bit 6
        #640 rxd = 0;    // bit 7
        #640 rxd = 0;    // stop bit - missed
        #640 rxd = 0;    // idle
        #4000 rxd = 1;    // recovery
        #1000 rxd = 0;    // start bit
        #640 rxd = 0;    // bit 0
        #640 rxd = 0;    // bit 1
        #640 rxd = 0;    // bit 2
        #640 rxd = 0;    // bit 3
        #640 rxd = 1;    // bit 4
        #640 rxd = 1;    // bit 5
        #640 rxd = 1;    // bit 6
        #640 rxd = 1;    // bit 7
        #640 rxd = 1;    // stop bit - 0xf0
        #640 rxd = 1;    // idle
        #4000 rxd = 1;
        #4000 rxd = 1;

        #2000 assign rxd = txd; clock_selector = 2'b10; tx_data_len = 9'h100;
        #2500000 $finish;
    end

endmodule
