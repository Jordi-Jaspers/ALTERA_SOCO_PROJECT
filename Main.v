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
 
module Main(CLOCK_50, GPIO, KEY);

/* Inputs */
input 		CLOCK_50;
input [1:0] KEY; 

/* Outputs */
output reg 			[33:0]		GPIO;				//Signal to send to WS2811 chain through the GPIO_header

reg [LED_ADDRESS_WIDTH-1:0] 	address;     	// The current LED number. This signal is incremented to the next value two cycles after the last time data_request was asserted.

/* Wires */
wire				hard_reset;        	// Reset FPGA
wire           reset_almost_done;
wire           led_almost_done;

wire 				data_request;			// This signal is asserted one cycle before red_in, green_in, and blue_in are sampled.
wire 				new_address;			// This signal is asserted whenever the address signal is updated to its new value.

wire	[23:0]	Color_Data;

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
//						DataSheet: WS2812						//
//																	//
//	reset_timing: 50us of meer --> 2kHz	++			   //
//	transfer_timing: TH + TL = 1,25us --> 800kHz		//
//	transfer_bit 0: TH = 0.35us & TL = 0.8us 			//
//	--> duty cycle: 0.28										//
//	transfer_bit 1: TH = 0.7us & TL = 0.6us			//
//	--> duty cycle: 0.56										//
/////////////////////////////////////////////////////

/* Parameters */
parameter 				AMOUNT_LEDS		= 5;          	// The number of LEDS in the chain
parameter 				SYSTEM_CLOCK	= 50_000_000;  	// The frequency of the input clock signal, in Hz

/* Timing WS2812 */

localparam integer CYCLE_COUNT         = SYSTEM_CLOCK / 800000;
localparam integer RESET_COUNT         = 100 * CYCLE_COUNT; 		//almost 75us instead of 50 us

localparam integer TH0_CYCLE_COUNT     = 0.28 * CYCLE_COUNT;		//Transfer_bit = 0
localparam integer TH1_CYCLE_COUNT     = 0.56 * CYCLE_COUNT;		//Transfer_bit = 1

localparam integer RESET_COUNTER_WIDTH = log2(RESET_COUNT);
localparam integer CLOCK_DIV_WIDTH     = log2(CYCLE_COUNT);
localparam integer LED_ADDRESS_WIDTH	= log2(AMOUNT_LEDS);        // Number of bits to use for address input

reg [CLOCK_DIV_WIDTH - 1:0]             clock_div;           // Clock divider for a cycle
reg [RESET_COUNTER_WIDTH - 1:0]         reset_counter;       // Counter for a reset cycle
reg [LED_ADDRESS_WIDTH - 1 :0]			 next_LED;				 // Determines the next Color of the LED.

/* Finite State Machine: States */
reg [2:0] state;

localparam STATE_RESET    = 3'b000;
localparam STATE_LATCH    = 3'b001;
localparam STATE_PRE      = 3'b010;
localparam STATE_TRANSMIT = 3'b011;
localparam STATE_POST     = 3'b100;

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

/* modules */
Memory memory(next_LED, CLOCK_50, 7'b0, 1'b0, Color_Data);

/* Assigns */
assign reset = !KEY[0];

assign reset_almost_done = (state == STATE_RESET) && (reset_counter == RESET_COUNT-1);
assign led_almost_done   = (state == STATE_POST)  && (color == COLOR_B) && (current_bit == 0) && (address != 0);

assign data_request = reset_almost_done || led_almost_done;
assign new_address  = (state == STATE_PRE) && (current_bit == 7);

/* Testing LEDS */

//parameter [23:0] 	Color_Data			= 7169291;
//assign green_in = {Color_Data[7:0]};
//assign red_in = {Color_Data[15:8]};
//assign blue_in = {Color_Data[23:16]};
//wire	[7:0]		green_in;		
//wire	[7:0]		red_in;
//wire	[7:0]		blue_in;

always @(posedge CLOCK_50)
begin
 if (reset) 
	begin
		//Reset instructions
		state <= STATE_RESET;
		color <= COLOR_G;
		
		next_LED <= 0;
		GPIO <= 0;
		address <= 0;
		reset_counter <= 0;
		current_bit <= 7;
	 end 
 else 
	begin
		//Main Finite State Loop.
		case (state)
			STATE_RESET: //GPIO laag zetten voor 50us minimum
				begin
					GPIO <= 0;
					  if (reset_counter == RESET_COUNT - 1)
						  begin
							  reset_counter <= 0;
							  state <= STATE_LATCH;
						  end
					  else 
						  begin
							  reset_counter <= reset_counter + 1;
						  end
				end
			STATE_LATCH: //Alle variabelen klaarzetten voor de volgende state
				begin
					state <= STATE_PRE;
					color <= COLOR_G;
					
					green <= Color_Data[7:0];
					red <= Color_Data[15:8];
					blue <= Color_Data[23:16];
					
//					green <= green_in;
//					red <= red_in;
//					blue <= blue_in;
					
					next_LED	<= next_LED + 1;

					address <= address + 1;

					current_byte <= green;
					current_bit <= 7;
				end
			STATE_PRE: //GPIO hoog maken en clock_cycle tellen.
				begin
					state <= STATE_TRANSMIT;
					clock_div <= 0;
					GPIO <= 1;
				end
			STATE_TRANSMIT: //Beginnen met het doorsturen van de het signaal afhankelijk als het 1 of 0 is.
				begin
              if (current_byte[7] == 0 && clock_div >= TH0_CYCLE_COUNT) 
					begin
                 GPIO <= 0;
					end
              else if (current_byte[7] == 1 && clock_div >= TH1_CYCLE_COUNT) 
					begin
                 GPIO <= 0;
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
									 state <= STATE_LATCH;
									end	
								end	
							endcase
						end
				end
			default:
				begin
					state <= STATE_RESET;
				end
		endcase
	end 
end

endmodule




