/**
 * @Author: Jordi Jaspers
 *	@Date of Commence: 03/04/2019
 *
 *	@Project: POV_GLOBE
 *	
 *	I'll be programming a globe by using a led-strip and a Altera Nano Cyclone IV FPGA.
 * This globe will make use of the persistence of vision principle to.
 *
 **/
 
module Main(CLOCK_50, KEY, Data_in, Data_out);

/* Inputs & Outputs */
input 		CLOCK_50;
input [1:0] KEY;

output reg Data_out;				//Signal to send to WS2811 chain through the GPIO_header 
input Data_in;

/* Register */
reg [LED_ADDRESS_WIDTH-1:0] 	address;     	// The current LED number. This signal is incremented to the next value two cycles after the last time data_request was asserted.

/* Wires */
wire				hard_reset;        	// Reset FPGA
wire           reset_almost_done;
wire           led_almost_done;

wire 				data_request;			// This signal is asserted one cycle before red_in, green_in, and blue_in are sampled.
wire 				new_address;			// This signal is asserted whenever the address signal is updated to its new value.

wire [23:0]		Color_Data_Insert;

/* Function: Frequency to bits*/
function integer log2;
input integer value;
begin
	value = value - 1;
	for (log2 = 0; value > 0; log2 = log2 + 1)
	 value = value >> 1;
end
endfunction

/////////////////////////////////////////////////////
//						DataSheet: WS2812b					//
//																	//
//	reset_timing: 50us of meer --> 20kHz	++			//
//	transfer_timing: TH + TL = 1,25us --> 800kHz		//
//	transfer_bit 0: TH = 0.40us & TL = 0.85us 		//
//	--> duty cycle: 0.28										//
//	transfer_bit 1: TH = 0.8us & TL = 0.45us			//
//	--> duty cycle: 0.56										//
/////////////////////////////////////////////////////

/* Parameters */
parameter 				AMOUNT_LEDS		= 36;          	// The number of LEDS in the chain
parameter 				SYSTEM_CLOCK	= 50_000_000;  	// The frequency of the input clock signal, in Hz

/* Timing WS2812 */

localparam integer CYCLE_COUNT         = SYSTEM_CLOCK / 800000;
localparam integer RESET_COUNT         = 320 * CYCLE_COUNT; 		//50 us wait timer

localparam integer TH0_CYCLE_COUNT     = 0.32 * CYCLE_COUNT;		//Transfer_bit = 0
localparam integer TH1_CYCLE_COUNT     = 0.64 * CYCLE_COUNT;		//Transfer_bit = 1


localparam integer RESET_COUNTER_WIDTH = log2(RESET_COUNT);
localparam integer CLOCK_DIV_WIDTH     = log2(CYCLE_COUNT);
localparam integer LED_ADDRESS_WIDTH	= log2(AMOUNT_LEDS);        // Number of bits to use for address input

reg [CLOCK_DIV_WIDTH - 1:0]             clock_div;           // Clock divider for a cycle
reg [RESET_COUNTER_WIDTH - 1:0]         reset_counter;       // Counter for a reset cycle
reg [LED_ADDRESS_WIDTH - 1 :0]			 NEXT_LED;				 // Determines the next Color of the LED.

/* Finite State Machine: States */
reg [3:0] state;

localparam STATE_RESET    = 4'b0000;
localparam STATE_STATIC   = 4'b0001;
localparam STATE_PRE      = 4'b0010;
localparam STATE_TRANSMIT = 4'b0011;
localparam STATE_POST     = 4'b0100;
localparam STATE_RESTART  = 4'b0101;
localparam STATE_TIMER	  = 4'b0110;
localparam STATE_GRADIENT = 4'b0111;
localparam STATE_PICTURE  = 4'b1000;
localparam STATE_LINE	  = 4'b1001;
localparam STATE_FLOW	  = 4'b1010;

/* Finite State Machine: Color Code --> 7b GREEN, RED, BLUE*/
reg [1:0]	color;

localparam COLOR_G     = 2'b00;
localparam COLOR_R     = 2'b01;
localparam COLOR_B     = 2'b10;

reg [7:0]   green;						  
reg [7:0]   red;
reg [7:0]   blue;

reg [7:0]   current_byte;       // Current byte to send
reg [2:0]   current_bit;        // Current bit index to send

/* Finite State Machine: Color mode */
wire [2:0]	MODE;

localparam STATIC    = 3'b000;
localparam GRADIENT  = 3'b001;
localparam PICTURE   = 3'b010;
localparam LINE		= 3'b011;
localparam FLOW		= 3'b100;

/* Testing LEDS */

reg [23:0] 								Color_Data;
reg [5:0]								MODULE_COUNTER;
reg [LED_ADDRESS_WIDTH - 1 :0]	TOTAL_LEDS;
reg [21 :0] 							TIMER;
reg [1:0]								REVERSE_LED;
reg [1:0]								REVERSE_MODULE;
reg [1:0]								DIM_LED;
reg [1:0]								HALL_SWITCHED;
reg [3:0]								HALL_TIMER;

/* Assigns */
assign reset = !KEY[0];

assign reset_almost_done = (state == STATE_RESET) && (reset_counter == RESET_COUNT-1);
assign led_almost_done   = (state == STATE_POST)  && (color == COLOR_B) && (current_bit == 0) && (address != 0);

assign data_request = reset_almost_done || led_almost_done;
assign new_address  = (state == STATE_PRE) && (current_bit == 7);

assign MODE = PICTURE;

/* modules */
ROM1 rom(MODULE_COUNTER, CLOCK_50, Color_Data_Insert);

always @(posedge CLOCK_50)
begin
 if (reset) 
	begin
		//Reset instructions
		state <= STATE_RESET;
		color <= COLOR_G;
		
		HALL_SWITCHED <= 0;
		TOTAL_LEDS <= 0;
		REVERSE_LED <= 0;
		REVERSE_MODULE <= 0;
		DIM_LED <= 0;
		NEXT_LED <= 0;
		Data_out <= 0;
		HALL_TIMER <= 0;
		
		address <= 0;
		reset_counter <= 0;
		current_bit <= 7;
		MODULE_COUNTER <= 0;
	 end 
 else 
	begin
		//Main Finite State Loop.
		case (state)
			STATE_TIMER:
				begin
					if(TIMER == {20{1'b1}})
						begin
							state <= STATE_RESTART;
						end	
					else
						begin
							TIMER <= TIMER + 1;
						end	
				end
			STATE_RESTART:
				begin
						TIMER <= 0;
						state <= STATE_RESET;
						color <= COLOR_G;
						
						Data_out <= 0;
						address <= 0;
						reset_counter <= 0;
						current_bit <= 7;

						NEXT_LED <= 0;			
				end
			STATE_RESET: //laag zetten voor 50us minimum
				begin
					Data_out <= 0;
					if (reset_counter == RESET_COUNT - 1)
						begin
							reset_counter <= 0;
							
							case(MODE)
								STATIC:
									begin
										state <= STATE_STATIC;
									end
								GRADIENT:
									begin
										state <= STATE_GRADIENT;
									end
								PICTURE:
									begin
										state <= STATE_PICTURE;
									end
								LINE:
									begin
										state <= STATE_LINE;
									end
								FLOW:
									begin
										state <= STATE_FLOW;
									end	
							endcase		
						  end
					  else 
						  begin
							  reset_counter <= reset_counter + 1;
						  end
				end
			STATE_GRADIENT: //GRADIENT_CONTROLLER
				begin
					if(NEXT_LED != TOTAL_LEDS)
						begin
							state <= STATE_PRE;
							color <= COLOR_G;
							
							red <= Color_Data[7:0];
							green <= Color_Data[15:8];
							blue <= Color_Data[23:16];
							
							NEXT_LED	<= NEXT_LED + 1;

							address <= address + 1;

							current_byte <= green;
							current_bit <= 7;
						end
					else
						begin
							if(REVERSE_LED == 0)
								begin
									if(TOTAL_LEDS == AMOUNT_LEDS)
										begin
											REVERSE_LED <= 1;
											DIM_LED <= 1;
										end
									else
										begin
											TOTAL_LEDS <= TOTAL_LEDS + 1;
											state <= STATE_TIMER;
										end
								end
							if(REVERSE_LED == 1)	
								begin	
									if(TOTAL_LEDS == 0 && MODULE_COUNTER == 6'b100101)
										begin
											REVERSE_MODULE <= 1;
											Color_Data <= Color_Data_Insert;
										end
									if(TOTAL_LEDS == 0 && MODULE_COUNTER == 0)
										begin
											REVERSE_MODULE <= 0;
											Color_Data <= Color_Data_Insert;
										end	
										
									if(TOTAL_LEDS == 0 && MODULE_COUNTER != 6'b100101 && REVERSE_MODULE == 0)
										begin
											MODULE_COUNTER <= MODULE_COUNTER + 1;
											Color_Data <= Color_Data_Insert;
										end
									if(TOTAL_LEDS == 0 && MODULE_COUNTER != 0 && REVERSE_MODULE == 1)
										begin
											MODULE_COUNTER <= MODULE_COUNTER - 1;
											Color_Data <= Color_Data_Insert;
										end
										
									if(TOTAL_LEDS == 0 && MODULE_COUNTER == 6'b100101)
										begin
											MODULE_COUNTER <= MODULE_COUNTER - 1;
										end
									if(TOTAL_LEDS == 0 && MODULE_COUNTER == 0)
										begin
											MODULE_COUNTER <= MODULE_COUNTER + 1;
										end	

									if(TOTAL_LEDS == 0)
										begin
											TOTAL_LEDS <= TOTAL_LEDS + 1;
											REVERSE_LED <= 0;
										end
										
									if(TOTAL_LEDS != 0)
										begin
											if(DIM_LED == 1)
												begin
													state <= STATE_TIMER;
													Color_Data <= 24'b000000000000000000000000;
													DIM_LED <= 0;
												end
											else
												begin
													state <= STATE_RESTART;
													Color_Data <= Color_Data_Insert;
													DIM_LED <= 1;
													TOTAL_LEDS  <= TOTAL_LEDS - 1;
												end
										end
								end
						end
				end
			STATE_STATIC: //Static Color
				begin
					TOTAL_LEDS <= AMOUNT_LEDS;
					Color_Data	<= 24'b000000001111111100000000;
					
					if(NEXT_LED != TOTAL_LEDS)
						begin
							state <= STATE_PRE;
							color <= COLOR_G;
							
							red <= Color_Data[7:0];
							green <= Color_Data[15:8];
							blue <= Color_Data[23:16];
							
							NEXT_LED	<= NEXT_LED + 1;

							address <= address + 1;

							current_byte <= green;
							current_bit <= 7;
						end
				end
			STATE_PICTURE:
				begin
					TOTAL_LEDS <= AMOUNT_LEDS;
			
					if(Data_in == 1 && HALL_SWITCHED == 0)
					begin
						if(NEXT_LED != TOTAL_LEDS)
							begin
								state <= STATE_PRE;
								color <= COLOR_G;
								
								MODULE_COUNTER <= MODULE_COUNTER + 1;
								Color_Data <= Color_Data_Insert;
								
								red <= Color_Data[7:0];
								green <= Color_Data[15:8];
								blue <= Color_Data[23:16];
								
								NEXT_LED	<= NEXT_LED + 1;

								address <= address + 1;

								current_byte <= green;
								current_bit <= 7;
							end
							
						if(MODULE_COUNTER == 9'b1111100111)
						begin
							MODULE_COUNTER <= 0;
							Color_Data	<= Color_Data_Insert;
						end	
					end
					
					if(Data_in == 0 && HALL_SWITCHED == 1)
					begin
						if(NEXT_LED != TOTAL_LEDS)
							begin
								state <= STATE_PRE;
								color <= COLOR_G;
								
								Color_Data <= 24'b000000000000000000000000;
								
								red <= Color_Data[7:0];
								green <= Color_Data[15:8];
								blue <= Color_Data[23:16];
								
								NEXT_LED	<= NEXT_LED + 1;

								address <= address + 1;

								current_byte <= green;
								current_bit <= 7;
							end
						else
							begin
								state <= STATE_RESTART;
								HALL_SWITCHED <= 0;
							end	
					end
					
					if(Data_in == 0)
					begin
						HALL_SWITCHED <= 1;
					end
					
					if(Data_in == 1)
					begin
						HALL_SWITCHED <= 0;
					end
				end
			STATE_FLOW: //Werken met de hall-Sensor
				begin	
					
					if(NEXT_LED == 0 && Data_in == 1 && HALL_SWITCHED == 0)
						begin
							HALL_SWITCHED <= 1;
							if(MODULE_COUNTER == 6'b100101)
								begin
									REVERSE_MODULE <= 1;
									MODULE_COUNTER <= MODULE_COUNTER - 1;
								end
							if(MODULE_COUNTER == 0)
								begin
									REVERSE_MODULE <= 0;
									MODULE_COUNTER <= MODULE_COUNTER + 1;
								end
							if(MODULE_COUNTER != 6'b100101 && REVERSE_MODULE == 0)
								begin
									MODULE_COUNTER <= MODULE_COUNTER + 1;
								end
							if(MODULE_COUNTER != 0 && REVERSE_MODULE == 1)
								begin
									MODULE_COUNTER <= MODULE_COUNTER - 1;
								end
						end
						
					if(Data_in == 0 && NEXT_LED == AMOUNT_LEDS)
						begin
							HALL_SWITCHED <= 0;
						end	
						
					TOTAL_LEDS <= AMOUNT_LEDS;	
					Color_Data	<= Color_Data_Insert;
					
					if(NEXT_LED != TOTAL_LEDS)
						begin
							state <= STATE_PRE;
							color <= COLOR_G;
							
							red <= Color_Data[7:0];
							green <= Color_Data[15:8];
							blue <= Color_Data[23:16];
							
							NEXT_LED	<= NEXT_LED + 1;

							address <= address + 1;

							current_byte <= green;
							current_bit <= 7;
						end
					else
						begin
							state <= STATE_RESTART;
						end	
				end
			STATE_LINE:
				begin
					TOTAL_LEDS <= AMOUNT_LEDS;
					
					if(NEXT_LED != TOTAL_LEDS)
						begin
							Color_Data <= 24'b000000000000000011111111;
							
							if(NEXT_LED >= 10 && NEXT_LED <= 23)
								begin
									Color_Data <= 24'b111111110000000000000000;
								end
							
							state <= STATE_PRE;
							color <= COLOR_G;
							
							red <= Color_Data[7:0];
							green <= Color_Data[15:8];
							blue <= Color_Data[23:16];
									
							NEXT_LED	<= NEXT_LED + 1;

							address <= address + 1;

							current_byte <= green;
							current_bit <= 7;
						end
				end
			STATE_PRE: //GPIO hoog maken en clock_cycle tellen.
				begin
					state <= STATE_TRANSMIT;
					clock_div <= 0;
					Data_out <= 1;
				end
			STATE_TRANSMIT: //Beginnen met het doorsturen van de het signaal afhankelijk als het 1 of 0 is.
				begin
              if (current_byte[7] == 0 && clock_div >= TH0_CYCLE_COUNT) 
					begin
                 Data_out <= 0;
					end
              else if (current_byte[7] == 1 && clock_div >= TH1_CYCLE_COUNT) 
					begin
                 Data_out <= 0;
					end

              if (clock_div == CYCLE_COUNT-1)
					begin
						  state <= STATE_POST;
					end
              else 
					begin
						  clock_div <= clock_div + 1;
					end
				end
			STATE_POST: 
				begin
					if (current_bit != 0) 
						begin
						  current_byte <= {current_byte[6:0], 1'b0};
						  case (current_bit)
							  7: current_bit <= 6;
							  6: current_bit <= 5;
							  5: current_bit <= 4;
							  4: current_bit <= 3;
							  3: current_bit <= 2;
							  2: current_bit <= 1;
							  1: current_bit <= 0;
						  endcase
						  state <= STATE_PRE;
						end
					else 
						begin
						  case (color)
							  COLOR_G: 
								begin
								  state <= STATE_PRE;
								  color <= COLOR_R;
								  current_byte <= red;
								  current_bit <= 7;
								end
							  COLOR_R: 
								begin
								 state <= STATE_PRE;
								 color <= COLOR_B;
								 current_byte <= blue;
								 current_bit <= 7;
								end
							  COLOR_B: 
								begin
								 if (address == 0) 
									begin
										state <= STATE_RESET;
									end
								 else 
									begin
										case(MODE)
										STATIC:
											begin
												state <= STATE_STATIC;
											end
										GRADIENT:
											begin
												state <= STATE_GRADIENT;
											end
										PICTURE:
											begin
												state <= STATE_PICTURE;
											end
										LINE:
											begin
												state <= STATE_LINE;
											end
										FLOW:
											begin
												state <= STATE_FLOW;
											end	
									endcase	
									end	
								end	
							endcase
						end
				end
			default:
				begin
					state <= STATE_TIMER;
				end
		endcase
	end 
end

endmodule




