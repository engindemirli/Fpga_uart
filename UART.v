
//CLK_PER_BIT = CLK / BAUDRATE
//clock 50 mhz
//baudrate 9600
//50 000 000 / 9600 = 5,208



module UART
		(
			input i_clock,
			input i_rx_bit,
			output o_tx_bit,
			output o_tx_interrupt,
			output o_rx_interrupt
		);

	wire[7:0] w_rx_to_tx;
	wire		 w_rx_int;
	assign o_rx_interrupt = w_rx_int;
	Uart_Rx Rx(.i_clock(i_clock),.i_rx_bit(i_rx_bit),.or_rx_interrupt(w_rx_int),
	           .o_rx_data(w_rx_to_tx));
				  
	Uart_Tx Tx(.i_clock(i_clock),.i_tx_data_interrupt(w_rx_int),
				  .i_tx_data(w_rx_to_tx),.o_tx_interrupt(o_tx_interrupt),.o_tx_bit(o_tx_bit));
				  
		
endmodule
/*
module UART
		(
			input i_clock,
			input i_rx_bit,
			output o_rx_interrupt,
			output reg o = 1
		);

	wire[7:0] w_rx_to_tx;
	Uart_Rx Rx(.i_clock(i_clock),.i_rx_bit(i_rx_bit),.or_rx_interrupt(o_rx_interrupt),
	           .o_rx_data(w_rx_to_tx));
				  
		
endmodule
*/
 
module Uart_Rx
	//#(parameter CLK_PER_BIT = 5208)
	(
		input 		i_clock,
		input 		i_rx_bit,
		output reg or_rx_interrupt = 0 ,
		output[7:0] o_rx_data
	);
	
	parameter rx_idle  = 3'b000 ;
	parameter rx_start = 3'b001 ;
	parameter rx_data  = 3'b010 ;
	parameter rx_stop  = 3'b011 ;
	parameter rx_end   = 3'b100 ;
	parameter CLK_PER_BIT = 5208;
	
	reg[2:0]   r_rx_status       = 0 ;
	reg[7:0]   r_rx_data         = 0 ;
	reg[7:0]   r_rx_baud_count   = 0 ;
	reg[2:0]   r_rx_bit_count    = 0 ;
	
	


always @(posedge i_clock)
begin
	case(r_rx_status)
		
		rx_idle://check start bit 
		begin
			or_rx_interrupt <= 0 ;
			r_rx_bit_count <= 0 ;
			r_rx_baud_count   <= 0 ;
			
			if(i_rx_bit == 1'b0)// Start bit detected
				r_rx_status <= rx_start ;
			else
				r_rx_status <= rx_idle ;
		end//case rx_idle
		
		
		rx_start:// Check start bit remain 0 after clk_PER_BIT-1/2 time
		begin	
			if((CLK_PER_BIT-1)/2 == r_rx_baud_count)
			  begin
				if(i_rx_bit == 1'b0)
				  begin
					r_rx_status  <= rx_data ;
					r_rx_baud_count <= 0 ;
				  end
				else
					r_rx_status  <= rx_idle ;
			  end
			  
			else
			  begin
				r_rx_baud_count <= r_rx_baud_count + 1 ;
				r_rx_status <= rx_start ;
			  end
		end //case rx_start
		
		
		//read data to register
		rx_data:
		  begin
			if(r_rx_baud_count < CLK_PER_BIT-1)
			  begin
				r_rx_baud_count <= r_rx_baud_count + 1 ;
				r_rx_status <= rx_data ;
			  end
			else
			  begin
				r_rx_data[r_rx_bit_count] <= i_rx_bit ;
				r_rx_baud_count <= 0 ;
				if(r_rx_bit_count < 7 )
				  begin
					r_rx_bit_count <= r_rx_bit_count +1 ;
					r_rx_status <= rx_data ;
				  end
				else
				  begin
					r_rx_bit_count <=0 ;
					r_rx_status <= rx_stop ;
				  end
				
			end
		end//case rx_data
		
		
		 // Receive Stop bit.  Stop bit = 1
      rx_stop :
      begin
      // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
			if (r_rx_baud_count < CLK_PER_BIT-1)
			begin
				r_rx_baud_count <= r_rx_baud_count + 1 ;
				r_rx_status <= rx_stop ;
         end
         else
         begin
				or_rx_interrupt <= 1'b1;
				r_rx_baud_count   <= 0;
				r_rx_status    <= rx_end;
			end
      end // case rx_stop
		
		
		rx_end:
		begin
			or_rx_interrupt <= 1'b0;
			r_rx_status    <= rx_idle;
		end // case rx_end
		
	endcase
end
	
endmodule

module Uart_Tx
		//#(parameter CLK_PER_BIT = 5208)
		(
			input 		i_clock,
			input 		i_tx_data_interrupt,
			input [7:0]	i_tx_data,
			output 		o_tx_interrupt,
			output      o_tx_bit
		);
	parameter CLK_PER_BIT = 5208;
	parameter tx_idle  = 3'b000 ;
	parameter tx_start = 3'b001 ;
	parameter tx_send  = 3'b010 ;
	parameter tx_stop  = 3'b011 ;
	parameter tx_end   = 3'b100 ;
	
	reg[7:0] r_tx_data 		 = 0 ;
	reg[7:0] r_tx_baud_count = 0 ;
	reg[2:0] r_tx_bit_count  = 0 ;
	reg[2:0] r_tx_status     = 0 ;
	reg      r_tx_interrupt  = 0 ;
	reg 	 	r_tx_bit        = 1 ;
	
	wire w_tx_bit;
	wire w_tx_interrupt;
	
	assign w_tx_bit       = r_tx_bit       ;
	assign w_tx_interrupt = r_tx_interrupt ;
	
	assign o_tx_bit       = w_tx_bit       ;
	assign o_tx_interrupt = w_tx_interrupt ;
	
	always @ (posedge i_clock)// and (posedge r_tx_data_ready) )
	begin
		case(r_tx_status)
		
			tx_idle://check data ready
			begin
				r_tx_bit        <= 1 ;
				r_tx_baud_count <= 0 ;
				r_tx_bit_count  <= 0 ;
				r_tx_interrupt  <= 0 ;
				
				if(i_tx_data_interrupt == 1)
				  begin
				   r_tx_data   <= i_tx_data ;
					r_tx_status <= tx_start  ;
				  end
				else
					r_tx_status <= tx_idle;
			end//case tx_idle
			
			tx_start:// send start bit;
			begin
				if( r_tx_baud_count < CLK_PER_BIT -1 )
				  begin
				   r_tx_status     <= tx_start            ;
					r_tx_bit        <= 1'b0                ;
					r_tx_baud_count <= r_tx_baud_count + 1 ;
				  end
				else
				 begin
					r_tx_baud_count <= 0  ;
					r_tx_status     <= tx_send ;
					
				 end		
			end//case tx_start
			
			tx_send://send data
			begin
				if( r_tx_baud_count < CLK_PER_BIT -1 )
				  begin
					r_tx_bit        <= r_tx_data[r_tx_bit_count] ; 
					r_tx_baud_count <= r_tx_baud_count + 1       ;				  
				  end
				else
				  begin
				    r_tx_baud_count <= 0 ;
					 if(r_tx_bit_count < 7)
						r_tx_bit_count <= r_tx_bit_count + 1;
					 else	
					   r_tx_status     <= tx_end ;
						r_tx_baud_count <= 0      ;
						r_tx_bit_count  <= 0      ;
				  end			
			end//case tx_send
			
			
			tx_stop://send stop bit
			begin
				if( r_tx_baud_count < CLK_PER_BIT -1 )
				  begin
				   r_tx_status     <= tx_start            ;
					r_tx_bit        <= 1'b0                ;
					r_tx_baud_count <= r_tx_baud_count + 1 ;
				  end
				else
				 begin
				   r_tx_bit        <= 1'b1   ;
					r_tx_baud_count <= 0      ;
					r_tx_status     <= tx_end ;					
				 end		
			end//case tx_stop
			
			
			tx_end:
			begin
			   r_tx_bit       <= 1'b1    ;
				r_tx_interrupt <= 1'b1    ;
				r_tx_status    <= tx_idle ;
			end
			
			
		endcase
	end

endmodule
