module spi_master #(
    parameter integer CLKS_PER_HALF_BIT = 250
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] tx_data,
    input  wire       miso,
    output reg        sclk,
    output reg        mosi,
    output reg [1:0]  ss_n,
    output reg [7:0]  rx_data,
    output reg        busy,
    output reg        done
);

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [2:0] bit_count;
    reg [31:0] clk_count;
    reg finish_pending;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sclk           <= 1'b0;
            mosi           <= 1'b0;
            ss_n           <= 2'b11;
            rx_data        <= 8'h00;
            busy           <= 1'b0;
            done           <= 1'b0;
            tx_shift       <= 8'h00;
            rx_shift       <= 8'h00;
            bit_count      <= 3'd0;
            clk_count      <= 32'd0;
            finish_pending <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                sclk           <= 1'b0;
                ss_n           <= 2'b11;
                finish_pending <= 1'b0;

                if (start) begin
                    busy           <= 1'b1;
                    clk_count      <= 32'd0;
                    bit_count      <= 3'd0;
                    tx_shift       <= tx_data;
                    rx_shift       <= 8'h00;
                    mosi           <= tx_data[7];
                    finish_pending <= 1'b0;

                    if (tx_data[7] == 1'b0)
                        ss_n <= 2'b10;
                    else
                        ss_n <= 2'b01;
                end
            end else begin
                if (clk_count == CLKS_PER_HALF_BIT - 1) begin
                    clk_count <= 32'd0;

                    if (sclk == 1'b0) begin
                        sclk     <= 1'b1;
                        rx_shift <= {rx_shift[6:0], miso};

                        if (bit_count == 3'd7) begin
                            rx_data        <= {rx_shift[6:0], miso};
                            finish_pending <= 1'b1;
                        end else begin
                            bit_count <= bit_count + 3'd1;
                        end
                    end else begin
                        sclk     <= 1'b0;
                        tx_shift <= {tx_shift[6:0], 1'b0};
                        mosi     <= tx_shift[6];

                        if (finish_pending) begin
                            busy           <= 1'b0;
                            done           <= 1'b1;
                            ss_n           <= 2'b11;
                            finish_pending <= 1'b0;
                        end
                    end
                end else begin
                    clk_count <= clk_count + 32'd1;
                end
            end
        end
    end

endmodule