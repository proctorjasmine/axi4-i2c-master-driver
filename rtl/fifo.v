`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// fifo module
// Jasmine Proctor
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo(
    input clk, 
    input reset, 
    input [7:0] wr_data, 
    input wr_request,
    output reg [7:0] rd_data, 
    input rd_request, 
    output empty, 
    output full, 
    output reg overflow, 
    input clear_overflow_request,
    output reg [3:0] wr_index,
    output reg [3:0] rd_index 
    );

    reg [7:0] fifo_mem [0:15];
    
    
    assign empty = (wr_index == rd_index);
    assign full = ((wr_index +1)%16 == rd_index);

        
    always @ (posedge clk)
    begin
        if (reset) begin       //if reset asserted 
            wr_index <= 4'b0000;
            rd_index <= 4'b0000;
            overflow <= 1'b0;
            rd_data <= 8'd0;
        end else begin
            if (clear_overflow_request)
                overflow <= 1'b0;

        //WRITE if requested and fifo is not full
        if (wr_request)
        begin
            if (!full) begin
                fifo_mem[wr_index] <= wr_data;
                wr_index <= (wr_index + 1'd1) %16;
            end else begin
                overflow <= 1'b1;
            end
        end
            
        //READ if requested and fifo is not empty
        if (rd_request && !empty) begin
            rd_data <= fifo_mem[rd_index];
            rd_index <= (rd_index +1'd1) % 16;
        end
        else rd_data <= fifo_mem[rd_index]; //makes data avaliable when rd request not asked 
     end
     end
     

endmodule