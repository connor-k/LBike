/* 
 * Connor Kerns & Nolan Miller
 * EE 201 Final Project
 * Spring 2014
*/
`timescale 1ns / 1ps
module lightbike(ClkPort, vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b, Sw0,
	St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar,
	An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp,
	LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7,PS2_DAT,PS2_CLK);
	input ClkPort, Sw0;
	input PS2_DAT;
	input PS2_CLK;
	output St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar;
	output vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b;
	output An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp;
	output LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
	reg vga_r, vga_g, vga_b;
	
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/*  LOCAL SIGNALS */
	wire ClkPort, board_clk, clk, button_clk;
	reg start;
	wire reset;
	BUF BUF2(reset, Sw0);
	
	wire[7:0] keyboard_input;
	reg[7:0] keyboard_buffer;
	// Keyboard SM Transition Codes:
	//	start and ack mapped to space (= 29)
	//	reset mapped to escape (= 76)
	wire read;
	wire scan_ready;
	wire CLOCK_50;
	assign CLOCK_50 = DIV_CLK[0];
	
	pulse_gen pulser(
		.pulse_out(read),
		.trigger_in(scan_ready),
		.clk(CLOCK_50)
	);
	
	keyboard kb(
		.keyboard_clk(PS2_CLK),
		.keyboard_data(PS2_DAT),
		.clock50(CLOCK_50),
		.reset(reset),
		.read(read),
		.scan_ready(scan_ready),
		.scan_code(keyboard_input)
	);
	
	/* Handle keyboard input */
	always @(posedge scan_ready)
	begin
		keyboard_buffer <= keyboard_input;
		start <= 1'b0;
		// Get directions
		if (q_I)
		begin
			p1_dir <= RIGHT;
			p2_dir <= LEFT;
		end
		case(keyboard_buffer)
			16'h1D://W
				p1_dir <= UP;
			16'h1B://S
				p1_dir <= DOWN;
			16'h1C://A
				p1_dir <= LEFT;
			16'h23://D
				p1_dir <= RIGHT;
			16'h75://UP
				p2_dir <= UP;
			16'h72://DOWN
				p2_dir <= DOWN;
			16'h6B://LEFT
				p2_dir <= LEFT;
			16'h74://RIGHT
				p2_dir <= RIGHT;
			16'h29://space
				start <= 1'b1;
		endcase
	end
	
	BUF BUF1 (board_clk, ClkPort);
	reg [24:0]	DIV_CLK;
	initial DIV_CLK = 0;
	// Generate the DIV_CLK signal
	always @ (posedge board_clk)  
	begin : CLOCK_DIVIDER
		if (reset)
			DIV_CLK <= 0;
		else
			DIV_CLK <= DIV_CLK + 1'b1;
	end
	
	assign	clk = DIV_CLK[1];
	assign 	{St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar} = {5'b11111};
	
	wire inDisplayArea;
	wire [9:0] CounterX;
	wire [9:0] CounterY;
	
	hvsync_generator syncgen(.clk(clk), .reset(reset),.vga_h_sync(vga_h_sync), .vga_v_sync(vga_v_sync), .inDisplayArea(inDisplayArea), .CounterX(CounterX), .CounterY(CounterY));
	
	/////////////////////////////////////////////////////////////////
	///////////////		VGA & game control starts here		/////////
	/////////////////////////////////////////////////////////////////
	// Registers to represent the playing grid
	localparam GRID_SIZE = 50;
	localparam LOG_GRID_SIZE = 6;
	reg [GRID_SIZE - 1:0] grid[GRID_SIZE - 1:0]; // 256*256 locations in the grid (2d matrix)

	// The current position and direction each player is heading
	reg [1:0] p1_dir;
	reg [1:0] p2_dir;
	reg [LOG_GRID_SIZE - 1:0] p1_position_x;
	reg [LOG_GRID_SIZE - 1:0] p1_position_y;
	reg [LOG_GRID_SIZE - 1:0] p2_position_x;
	reg [LOG_GRID_SIZE - 1:0] p2_position_y;

	// Store the number of games each player has won
	reg[3:0] p1_score;
	initial p1_score <= 0;
	reg[3:0] p2_score;
	initial p2_score <= 0;
	
	// Determine which player is at fault for a collision (or if both)
	assign p1_fault = grid[p1_position_y][p1_position_x];
	assign p2_fault = grid[p2_position_y][p2_position_x];
	assign both_fault = ((p1_position_y == p2_position_y) && (p1_position_x == p2_position_x));
	assign collision =  p1_fault|| p2_fault||both_fault;

	// States
	// Store the current state and output it to top module.
	wire q_I, q_Straight, q_Collision, q_Done;
	wire collision;
	wire p1_fault;
	wire p2_fault;
	wire both_fault;
	reg [3:0] state;
	assign {q_Done, q_Collision, q_Driving, q_I} = state;
	
	// localparam's for the state case statements
	localparam I = 4'b0001, DRIVING = 4'b0010, COLLISION = 4'b0100, DONE = 4'b1000,
	UNK = 4'bXXXX, UP = 2'b00, RIGHT = 2'b01, DOWN = 2'b10, LEFT = 2'b11;
	
	// Local variables to loop through the grid during processing
	integer i, j;
	// State machine
	always @(posedge DIV_CLK[23])
	begin
		if (reset)
		begin
			state <= I;
			p1_score <= 0;
			p2_score <= 0;
		end
		else
			case (state)	
				I:
				begin
					// State transfers
					if (start)
						state <= DRIVING;
						
					// Set players' starting positions
					p1_position_x <= GRID_SIZE/4;
					p1_position_y <= GRID_SIZE/2;
					
					p2_position_x <= GRID_SIZE/4*3 - 2;
					p2_position_y <= GRID_SIZE/2;
			
					// Initialize the border of the grid to visited (out of bounds)
					for (j = 0; j < GRID_SIZE - 1; j = j + 1)
					begin
						grid[j][0] <= 1;
						grid[j][GRID_SIZE - 1] <= 1;
						grid[0][j] <= 1;
						grid[GRID_SIZE - 1][j] <= 1;
					end
					// Initialize the inside of the grid to unvisited (valid positions)
					for (j = 1; j < GRID_SIZE - 2; j = j + 1)
					begin
						for (i = 1; i < GRID_SIZE - 2; i = i + 1)
						begin
							grid[j][i] <= 0;
						end
					end
				end		
				DRIVING:
				begin
					// Data transfers
					// Mark the grid at last clock's position to be visited
					if (!collision)
					begin
						grid[p1_position_y][p1_position_x] <= 1;
						grid[p2_position_y][p2_position_x] <= 1;
			
						// Move player1 and player2 forward one space in their current direction
						case(p1_dir)
							UP:
								p1_position_y <= p1_position_y - 1;
							DOWN:
								p1_position_y <= p1_position_y + 1;
							LEFT:
								p1_position_x <= p1_position_x - 1;
							RIGHT:
								p1_position_x <= p1_position_x + 1;
						endcase
						case(p2_dir)
							UP:
								p2_position_y <= p2_position_y - 1;
							DOWN:
								p2_position_y <= p2_position_y + 1;
							LEFT:
								p2_position_x <= p2_position_x - 1;
							RIGHT:
								p2_position_x <= p2_position_x + 1;
						endcase
					end
					
					// State transfers
					if (collision)
					begin
						state <= COLLISION;
						if(p2_fault)
							p1_score <= p1_score+1;
						if(p1_fault)
							p2_score <= p2_score+1;
					end
				end
				COLLISION:
				begin
					if (start)
						state <= DONE;
				end
				DONE:
				begin
					if (start)
						state <= I;
				end
				default:		
					state <= UNK;
			endcase
	end
	
	// Define a scale for VGA display (how large one grid square is)
	localparam SCALE = 8;
	// Offsets to center the game on the screen
	localparam x_offset = (640-GRID_SIZE*SCALE)/2;
	localparam y_offset = (480-GRID_SIZE*SCALE)/2;
	
	// Determine the appropriate colors for each pixel
	assign onGrid = (CounterX >= x_offset && CounterX < x_offset + GRID_SIZE*SCALE - SCALE && CounterY >= y_offset && CounterY < y_offset + GRID_SIZE*SCALE - SCALE);
	// Green is player 1's head
	wire G = !p1_fault && p2_fault || p1_position_y == (CounterY - y_offset)/SCALE && p1_position_x == (CounterX - x_offset)/SCALE;
	// Blue is player 2's head
	wire B = !p2_fault && p1_fault || p2_position_y == (CounterY - y_offset)/SCALE && p2_position_x == (CounterX - x_offset)/SCALE;
	// Red is the outer border and previously visited squares (light walls)
	wire R = collision || onGrid&&grid[(CounterY-y_offset)/SCALE][(CounterX-x_offset)/SCALE];
	// Everything else is black
	
	// Set the calculated color
	always @(posedge clk)
	begin
		vga_g <= G & inDisplayArea;
		vga_r <= (R && ~B && ~G) & inDisplayArea;
		vga_b <= (B && ~G) & inDisplayArea;
	end
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  VGA control ends here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  LD control starts here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
	`define QI 			 4'b0001
	`define QDRIVING 	 4'b0010
	`define QCOLLISION   4'b0100
	`define QDONE 		 4'b1000
	
	// Light up the LEDs to display the current status of the game (states, signals)
	wire LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
	assign LD0 = DIV_CLK[24];
	assign LD1 = start;
	assign LD2 = reset;
	assign LD3 = 0;
	assign LD4 = (state == `QI);
	assign LD5 = (state == `QDRIVING);
	assign LD6 = (state == `QCOLLISION);
	assign LD7 = (state == `QDONE);
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  LD control ends here 	 	////////////////////
	/////////////////////////////////////////////////////////////////
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  SSD control starts here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
	reg 	[3:0]  SSD;
	wire 	[3:0]  SSD0, SSD1, SSD2, SSD3;
	wire 	[1:0]  ssdscan_clk;
	
	// Display the keyboard code for the most recent key pressed and the player scores on the SSD
	assign SSD3 = keyboard_buffer[7:4];
	assign SSD2 = keyboard_buffer[3:0];
	assign SSD1 = p1_score;
	assign SSD0 = p2_score;
	
	// need a scan clk for the seven segment display 
	// 191Hz (50MHz / 2^18) works well
	assign ssdscan_clk = DIV_CLK[19:18];	
	assign An0	= !(~(ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 00
	assign An1	= !(~(ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 01
	assign An2	= !( (ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 10
	assign An3	= !( (ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 11
	
	always @ (ssdscan_clk, SSD0, SSD1, SSD2, SSD3)
	begin : SSD_SCAN_OUT
		case (ssdscan_clk) 
			2'b00:
					SSD = SSD0;
			2'b01:
					SSD = SSD1;
			2'b10:
					SSD = SSD2;
			2'b11:
					SSD = SSD3;
		endcase 
	end	

	// and finally convert SSD_num to ssd
	reg [6:0]  SSD_CATHODES;
	assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp} = {SSD_CATHODES, 1'b1};
	// Following is Hex-to-SSD conversion
	always @ (SSD) 
	begin : HEX_TO_SSD
		case (SSD)		
			4'b1111: SSD_CATHODES = 7'b1111111 ; //Nothing 
			4'b0000: SSD_CATHODES = 7'b0000001 ; //0
			4'b0001: SSD_CATHODES = 7'b1001111 ; //1
			4'b0010: SSD_CATHODES = 7'b0010010 ; //2
			4'b0011: SSD_CATHODES = 7'b0000110 ; //3
			4'b0100: SSD_CATHODES = 7'b1001100 ; //4
			4'b0101: SSD_CATHODES = 7'b0100100 ; //5
			4'b0110: SSD_CATHODES = 7'b0100000 ; //6
			4'b0111: SSD_CATHODES = 7'b0001111 ; //7
			4'b1000: SSD_CATHODES = 7'b0000000 ; //8
			4'b1001: SSD_CATHODES = 7'b0000100 ; //9
			4'b1010: SSD_CATHODES = 7'b0001000 ; //10 or A
			4'b1011: SSD_CATHODES = 7'b1100000 ; //11 or B
			4'b1100: SSD_CATHODES = 7'b0110001 ; //12 or C
			4'b1101: SSD_CATHODES = 7'b1000010 ; //13 or D
			4'b1110: SSD_CATHODES = 7'b0110000 ; //14 or E
			4'b1111: SSD_CATHODES = 7'b0111000 ; //15 or F
			default: SSD_CATHODES = 7'bXXXXXXX ; // default is not needed as we covered all cases
		endcase
	end
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  SSD control ends here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
endmodule