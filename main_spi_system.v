module main_spi_system (
    input  wire       clk,
    input  wire       rst,
    input  wire       start_btn,
    input  wire [7:0] sw,
    output wire [3:0] led,
    output reg  [3:0] an,
    output reg  [6:0] seg
);

    localparam integer SPI_HALF_PERIOD = 250000;
    localparam integer REFRESH_DIVIDER = 50000;

    wire       sclk;
    wire       mosi;
    wire [1:0] ss_n;
    wire [7:0] rx_data;
    wire       busy;
    wire       done;
    wire       miso_0;
    wire       miso_1;
    wire       miso_bus;
    wire [3:0] slave0_out;
    wire [3:0] slave1_out;
    wire [6:0] seg_slave0;
    wire [6:0] seg_slave1;

    reg        start_sync_0;
    reg        start_sync_1;
    reg        start_sync_2;
    reg [31:0] refresh_count;
    reg        digit_sel;

    assign miso_bus = (ss_n[0] == 1'b0) ? miso_0 :
                      (ss_n[1] == 1'b0) ? miso_1 : 1'b0;

    assign led = rx_data[3:0];

    spi_master #(
        .CLKS_PER_HALF_BIT(SPI_HALF_PERIOD)
    ) master_inst (
        .clk(clk),
        .rst(rst),
        .start(start_sync_1 & ~start_sync_2),
        .tx_data(sw),
        .miso(miso_bus),
        .sclk(sclk),
        .mosi(mosi),
        .ss_n(ss_n),
        .rx_data(rx_data),
        .busy(busy),
        .done(done)
    );

    spi_slave slave0_inst (
        .clk(clk),
        .rst(rst),
        .sclk(sclk),
        .ss_n(ss_n[0]),
        .mosi(mosi),
        .miso(miso_0),
        .data_out(slave0_out)
    );

    spi_slave slave1_inst (
        .clk(clk),
        .rst(rst),
        .sclk(sclk),
        .ss_n(ss_n[1]),
        .mosi(mosi),
        .miso(miso_1),
        .data_out(slave1_out)
    );

    seven_seg_hex hex0_inst (
        .value(slave0_out),
        .seg(seg_slave0)
    );

    seven_seg_hex hex1_inst (
        .value(slave1_out),
        .seg(seg_slave1)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            start_sync_0 <= 1'b0;
            start_sync_1 <= 1'b0;
            start_sync_2 <= 1'b0;
        end else begin
            start_sync_0 <= start_btn;
            start_sync_1 <= start_sync_0;
            start_sync_2 <= start_sync_1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            refresh_count <= 32'd0;
            digit_sel     <= 1'b0;
        end else begin
            if (refresh_count == REFRESH_DIVIDER - 1) begin
                refresh_count <= 32'd0;
                digit_sel     <= ~digit_sel;
            end else begin
                refresh_count <= refresh_count + 32'd1;
            end
        end
    end

    always @(*) begin
        an  = 4'b1111;
        seg = 7'b1111111;

        if (digit_sel == 1'b0) begin
            an  = 4'b1110;
            seg = seg_slave0;
        end else begin
            an  = 4'b1101;
            seg = seg_slave1;
        end
    end

endmodule