/*

credit_to_ready credit_to_ready_inst
(
	.clk	(),
	.reset_n(),
		
		
	.avsi_channel	(),
	.avsi_data		(),
	.avsi_valid		(),
	.avsi_sop		(),
	.avsi_eop		(),
	.avsi_empty		(),
	.avsi_ready		(),



	//Avalon-ST Credit 
	.update_credit	(),
	.credit			(),
	.return_credit	(), 
		
	.avso_channel	(),
	.avso_data		(),
	.avso_valid		(),
	.avso_sop		(),
	.avso_eop		(),
	.avso_empty		()

);
	defparam credit_to_ready_inst.data_width = 128;
	defparam credit_to_ready_inst.empty_width = 4;
	defparam credit_to_ready_inst.channel_width = 10;
	defparam credit_to_ready_inst.fifo_depth = 12;
	defparam credit_to_ready_inst.credit_width = 16;

*/
module credit_to_ready
#(
	parameter data_width = 128,
	parameter empty_width = 4,
	parameter channel_width = 10,
	parameter credit_width = 5
)
(
	input clk,
	input reset_n,
	
	
	input 	logic [channel_width-1:0] 	avsi_channel,
	input 	logic [data_width-1:0] 		avsi_data,
	input 	logic 						avsi_valid,
	input 	logic 						avsi_sop,
	input 	logic 						avsi_eop,
	input 	logic [empty_width-1:0]		avsi_empty,
	output	logic  						avsi_ready,



	//Avalon-ST Credit 
	input 	logic 						update_credit,
	input 	logic [credit_width-1:0]	credit,
	output 	logic						return_credit, 
	
	output 	logic [channel_width-1:0]	avso_channel,
	output 	logic [data_width-1:0] 		avso_data,
	output 	logic 						avso_valid,
	output 	logic 						avso_sop,
	output 	logic 						avso_eop,
	output 	logic [empty_width-1:0] 	avso_empty



);


	
typedef struct packed 
{
	logic [channel_width-1:0] channel;
	logic [data_width-1:0] data;
	logic valid;
	logic sop;
	logic eop;
	logic [empty_width-1:0] empty;
} stream;



stream stream_in;
stream [2:0] stream_out;

reg [credit_width-1:0] current_credit;

wire fifo_data_full, fifo_data_empty;
wire fifo_data_rd, fifo_data_wr;

always_ff @ (posedge clk or negedge reset_n)
	if(!reset_n)
		stream_in <= 'h0;
	else 	if(avsi_ready)
			begin 
				stream_in.channel 	<= avsi_channel;
				stream_in.data		<= avsi_data;
				stream_in.valid		<= avsi_valid;
				stream_in.sop		<= avsi_sop;
				stream_in.eop 		<= avsi_eop;
				if(avsi_valid && avsi_eop)	stream_in.empty	<= avsi_empty;
				else 						stream_in.empty <= 'h0;
			end 



//control credit 
always_ff @ (posedge clk or negedge reset_n)
	if(!reset_n)
	begin
		current_credit 	<= 'h0;
		return_credit 	<= 'h0;
	end 
	else 	case({update_credit, fifo_data_rd})
				2'b00:	if(|current_credit)
						begin
							current_credit 	<= current_credit - 1'b1;
							return_credit 	<= 1'b1;
						end
						else
						begin
							current_credit 	<= 'h0;
							return_credit 	<= 1'b0;						
						end
				2'b01:		current_credit <= current_credit - 1'b1;
				2'b10:		current_credit <= current_credit + credit;
				2'b11:		current_credit <= current_credit + credit - 1'b1;
				default:	begin 
								current_credit <= 'h0;
								return_credit <= 1'b0;
							end 
			endcase 



assign avsi_ready = ~fifo_data_full;
assign fifo_data_wr = stream_in.valid & avsi_ready;
assign fifo_data_rd = ~fifo_data_empty & |current_credit;

scfifo	scfifo_data 
(
	.clock 	(clk),
	.data 	({stream_in.channel, stream_in.data, stream_in.sop, stream_in.eop, stream_in.empty}),
	.rdreq 	(fifo_data_rd),
	.wrreq 	(fifo_data_wr),
	.empty 	(fifo_data_empty),
	.full 	(fifo_data_full),
	.q 		({stream_out[1].channel, stream_out[1].data, stream_out[1].sop, stream_out[1].eop, stream_out[1].empty}),
	.usedw (),
	.aclr (~reset_n),
	.almost_empty (),
	.almost_full (),
	.eccstatus (),
	.sclr ()
);
defparam
	scfifo_data.add_ram_output_register = "ON",
	scfifo_data.intended_device_family = "Stratix 10",
	scfifo_data.lpm_numwords = 2**credit_width,
	scfifo_data.lpm_showahead = "OFF",
	scfifo_data.lpm_type = "scfifo",
	scfifo_data.lpm_width = channel_width + data_width + empty_width + 2,
	scfifo_data.lpm_widthu = credit_width,
	scfifo_data.overflow_checking = "ON",
	scfifo_data.underflow_checking = "ON",
	scfifo_data.use_eab = "ON";	





always_ff @ (posedge clk or negedge reset_n)
	if(!reset_n)	stream_out[1].valid <= 'h0;
	else 			stream_out[1].valid <= fifo_data_rd;
				
				

//output logic 
always_ff @ (posedge clk)
begin 
	avso_channel 	<= stream_out[1].channel;
	avso_data 		<= stream_out[1].data;
	avso_valid 		<= stream_out[1].valid;
	avso_sop 		<= stream_out[1].sop;
	avso_eop 		<= stream_out[1].eop;
	avso_empty 		<= stream_out[1].empty;				
end 

endmodule 
