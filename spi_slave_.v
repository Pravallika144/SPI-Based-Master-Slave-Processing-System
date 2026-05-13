module spi_slave (
    input  wire       clk,
    input  wire       rst,
    input  wire       sclk,
    input  wire       ss_n,
    input  wire       mosi,
    output wire       miso,
    output reg  [3:0] data_out
);

    reg [7:0] rx_shift;
    reg [7:0] tx_shift;
    reg [2:0] bit_count;
    reg       sclk_d;
    reg       ss_d;
    reg [7:0] rx_next;

    wire sclk_rise;
    wire sclk_fall;
    wire ss_fall;

    assign sclk_rise = (~sclk_d) & sclk;
    assign sclk_fall = sclk_d & (~sclk);
    assign ss_fall   = ss_d & (~ss_n);

    assign miso = (!ss_n) ? tx_shift[7] : 1'b0;

    function [3:0] execute_command;
        input [2:0] cmd;
        input [3:0] din;
        reg   [3:0] upper2;
        reg   [3:0] lower2;
        begin
            upper2 = {2'b00, din[3:2]};
            lower2 = {2'b00, din[1:0]};

            case (cmd)
                3'b000: execute_command = din;
                3'b001: execute_command = ~din;
                3'b010: execute_command = (~din) + 4'b0001;
                3'b011: execute_command = upper2 + lower2;
                3'b100: execute_command = upper2 - lower2;
                3'b101: execute_command = din[3:2] * din[1:0];
                3'b110: execute_command = {din[0], din[1], din[2], din[3]};
                3'b111: execute_command = {3'b000, ^din};
                default: execute_command = din;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_shift  <= 8'h00;
            tx_shift  <= 8'h00;
            bit_count <= 3'd0;
            data_out  <= 4'h0;
            sclk_d    <= 1'b0;
            ss_d      <= 1'b1;
            rx_next   <= 8'h00;
        end else begin
            sclk_d <= sclk;
            ss_d   <= ss_n;

            if (ss_fall) begin
                rx_shift  <= 8'h00;
                tx_shift  <= {4'h0, data_out};
                bit_count <= 3'd0;
            end else if (!ss_n) begin
                if (sclk_rise) begin
                    rx_next  = {rx_shift[6:0], mosi};
                    rx_shift <= rx_next;

                    if (bit_count == 3'd7) begin
                        bit_count <= 3'd0;
                        data_out  <= execute_command(rx_next[6:4], rx_next[3:0]);
                    end else begin
                        bit_count <= bit_count + 3'd1;
                    end
                end

                if (sclk_fall) begin
                    tx_shift <= {tx_shift[6:0], 1'b0};
                end
            end
        end
    end

endmodule