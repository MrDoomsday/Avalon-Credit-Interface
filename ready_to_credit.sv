module ready_to_credit
#(
	parameter data_width = 128,
	parameter empty_width = 4,
	parameter channel_width = 10,
	parameter credit_width = 5
)
(
	input clk,
	input reset_n,
	
	//Avalon-ST Credit 
	output 	logic 						update_credit,
	output 	logic [credit_width-1:0]	credit,
	input 	logic						return_credit, 	
	
	input 	logic [channel_width-1:0] 	avsi_channel,
	input 	logic [data_width-1:0] 		avsi_data,
	input 	logic 						avsi_valid,
	input 	logic 						avsi_sop,
	input 	logic 						avsi_eop,
	input 	logic [empty_width-1:0]		avsi_empty,



	output 	logic [channel_width-1:0]	avso_channel,
	output 	logic [data_width-1:0] 		avso_data,
	output 	logic 						avso_valid,
	output 	logic 						avso_sop,
	output 	logic 						avso_eop,
	output 	logic [empty_width-1:0] 	avso_empty,
	input 	logic 						avso_ready



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

logic [15:0] reset_register;


wire fifo_full, fifo_empty;
wire fifo_rd, fifo_wr;


always_ff @ (posedge clk or negedge reset_n)
	if(!reset_n)
		stream_in <= 'h0;
	else 	
	begin 
		stream_in.channel 	<= avsi_channel;
		stream_in.data		<= avsi_data;
		stream_in.valid		<= avsi_valid;
		stream_in.sop		<= avsi_sop;
		stream_in.eop 		<= avsi_eop;
		if(avsi_valid && avsi_eop)	stream_in.empty	<= avsi_empty;
		else 						stream_in.empty <= 'h0;
	end 

assign fifo_wr = stream_in.valid & !fifo_full;
assign fifo_rd = avso_ready & !fifo_empty;

scfifo	scfifo_data 
(
	.clock 	(clk),
	.data 	({stream_in.channel, stream_in.data, stream_in.sop, stream_in.eop, stream_in.empty}),
	.rdreq 	(fifo_rd),
	.wrreq 	(fifo_wr),
	.empty 	(fifo_empty),
	.full 	(fifo_full),
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
	if(!reset_n)	reset_register[15:0] <= 'h1;
	else 			reset_register[15:0] <= {reset_register[14:0], 1'b0};


always_ff @ (posedge clk or negedge reset_n)
	if(!reset_n)
	begin 
		credit 			<= 'h0;
		update_credit 	<= 1'h0;
	end 
	else 	if(reset_register[15])
			begin 
				credit 			<= 2**credit_width-1;
				update_credit 	<= 1'b1;
			end 
			else 	if(fifo_rd && return_credit)
					begin 
						credit 			<= 'h2;
						update_credit 	<= 1'b1;
					end 
					else 	if(fifo_rd || return_credit)
							begin 
								credit 			<= 'h1;
								update_credit 	<= 1'h1;
							end 
							else 
							begin 
								credit 			<= 'h0;
								update_credit 	<= 1'b0;
							end 
							
							
always_ff @ (posedge clk or negedge reset_n)
	if(!reset_n)
		stream_out[1].valid <= 'h0;
	else 	if(avso_ready)
				stream_out[1].valid <= fifo_rd;
							
							
							
//output logic 
always_ff @ (posedge clk or negedge reset_n)
	if(!reset_n)
	begin 
		avso_channel 	<= 'h0;
		avso_data 		<= 'h0;
		avso_valid 		<= 'h0;
		avso_sop 		<= 'h0;
		avso_eop 		<= 'h0;
		avso_empty 		<= 'h0;	
	end 
	else 	if(avso_ready)
			begin 
				avso_channel 	<= stream_out[1].channel;
				avso_data 		<= stream_out[1].data;
				avso_valid 		<= stream_out[1].valid;
				avso_sop 		<= stream_out[1].sop;
				avso_eop 		<= stream_out[1].eop;
				avso_empty 		<= stream_out[1].empty;				
			end 


endmodule 
