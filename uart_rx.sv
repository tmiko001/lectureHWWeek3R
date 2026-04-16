`include "clock_mul.sv"

module uart_rx (
    input clk,
    input rx,
    output reg rx_ready,
    output reg [7:0] rx_data
);

parameter SRC_FREQ = 76800;
parameter BAUDRATE = 9600;

// STATES: State of the state machine
localparam DATA_BITS = 8;
localparam 
    INIT = 0, 
    IDLE = 1,
    RX_DATA = 2,
    STOP = 3;

// CLOCK MULTIPLIER: Instantiate the clock multiplier
wire uart_clk;
clock_mul #(
    .SRC_FREQ(SRC_FREQ),
    .OUT_FREQ(BAUDRATE)
) clkm (
    .src_clk(clk),
    .out_clk(uart_clk)
);

reg [2:0] state = INIT;
reg [2:0] bit_count = 0;
reg [7:0] rx_shift = 8'h00;
reg [7:0] rx_data_src = 8'h00;
reg rx_data_valid_src = 1'b0;
reg rx_data_valid_sync0 = 1'b0;
reg rx_data_valid_sync1 = 1'b0;
reg rx_data_valid_sync2 = 1'b0;
reg rx_data_valid_sync3 = 1'b0;

// CROSS CLOCK DOMAIN: The rx_ready flag should only be set 1 one for one source 
// clock cycle. Use the cross clock domain technique discussed in class to handle this.
always @(posedge clk) begin
    rx_data_valid_sync0 <= rx_data_valid_src;
    rx_data_valid_sync1 <= rx_data_valid_sync0;
    rx_data_valid_sync2 <= rx_data_valid_sync1;
    rx_data_valid_sync3 <= rx_data_valid_sync2;

    rx_data <= rx_data_src;
    rx_ready <= rx_data_valid_sync2 & ~rx_data_valid_sync3;
end

// STATE MACHINE: Use the UART clock to drive that state machine that receves a byte from the rx signal
always @(posedge uart_clk) begin
    rx_data_valid_src <= 1'b0;

    case (state)
        INIT: begin
            bit_count <= 0;
            state <= IDLE;
        end

        IDLE: begin
            if (rx == 1'b0) begin
                state <= RX_DATA;
            end
        end

        RX_DATA: begin
            rx_shift[bit_count] <= rx;
            if (bit_count == DATA_BITS - 1) begin
                state <= STOP;
            end else begin
                bit_count <= bit_count + 1;
            end
        end

        STOP: begin
            if (rx == 1'b1) begin
                rx_data_src <= rx_shift;
                rx_data_valid_src <= 1'b1;
            end
            bit_count <= 0;
            state <= IDLE;
        end
    endcase
end



endmodule