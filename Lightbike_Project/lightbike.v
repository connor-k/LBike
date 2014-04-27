/* 
 * Connor Kerns & Nolan Miller
 * EE 201 Final Project -- State Machine (One-Hot)
 * Spring 2014
*/
`timescale 1ns / 1ps
module lightbike(ClkPort, vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b, Sw0, Sw1, btnU, btnD, btnL, btnR, btnC,
	St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar,
	An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp,
	LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7,PS2_DAT,PS2_CLK);
	input ClkPort, Sw0, btnC, btnU, btnD, btnL, btnR, Sw0, Sw1;
	input PS2_DAT;
	input PS2_CLK;
	output St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar;
	output vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b;
	output An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp;
	output LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
	reg vga_r, vga_g, vga_b;
	
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/*  LOCAL SIGNALS */
	wire	reset, start, ClkPort, board_clk, clk, button_clk;
	
	/* Keyboard Codes 
	   start = ack = space = 29
		reset = escape = 76
	*/
	wire[7:0] keyboard_input;
	reg[7:0] keyboard_buffer;
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
	
	always @(posedge scan_ready)
	begin
		//do something with keyboard_in
		keyboard_buffer <= keyboard_input;
	end
	
	BUF BUF1 (board_clk, ClkPort);
	assign reset = keyboard_buffer[7:0] == 16'h76;
	assign start = keyboard_buffer[7:0] == 16'h29;
	reg [25:0]	DIV_CLK;
	//generate the DIV_CLK signal
	always @ (posedge board_clk, posedge reset)  
	begin : CLOCK_DIVIDER
      if (reset)
			DIV_CLK <= 0;
      else
			DIV_CLK <= DIV_CLK + 1'b1;
	end
	
	//assign	button_clk = DIV_CLK[18];
	assign	clk = DIV_CLK[1];
	assign 	{St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar} = {5'b11111};
	
	wire inDisplayArea;
	wire [9:0] CounterX;
	wire [9:0] CounterY;
	
	hvsync_generator syncgen(.clk(clk), .reset(reset),.vga_h_sync(vga_h_sync), .vga_v_sync(vga_v_sync), .inDisplayArea(inDisplayArea), .CounterX(CounterX), .CounterY(CounterY));
	
	/////////////////////////////////////////////////////////////////
	///////////////		VGA control starts here		/////////////////
	/////////////////////////////////////////////////////////////////
	//reg [9:0] position;
	localparam GRID_SIZE = 32;
	localparam LOG_GRID_SIZE = 8;
	reg [GRID_SIZE - 1:0] grid[GRID_SIZE - 1:0]; // 256*256 locations in the grid (2d matrix)
	reg [1:0] p1_direction;
	reg [LOG_GRID_SIZE - 1:0] p1_position_x;
	reg [LOG_GRID_SIZE - 1:0] p1_position_y;
	reg [LOG_GRID_SIZE - 1:0] p2_position_x;
	reg [LOG_GRID_SIZE - 1:0] p2_position_y;
	
	// Assign player directions
	/* Keyboard codes:
						W = 1D
						S = 1B
						A = 1C
						D = 23
						UP = 75
						DOWN = 72
						LEFT = 66
						RIGHT = 74
					*/
	//TODO
	
	// States
	// Store the current state and output it to top module.
	wire q_I, q_Straight, q_Collision, q_Done;
	wire collision;
	assign collision = grid[p1_position_y][p1_position_x];
	
	reg [3:0] state;
	assign {q_I, q_Driving, q_Collision, q_Done} = state;
	
	// localparam's for the state case statements
	localparam
	I = 4'b0001, DRIVING = 4'b0010, COLLISION = 4'b0100, DONE = 4'b1000, UNK = 4'bXXXX;
	
	integer i, j;
	// State machine
	always @(posedge DIV_CLK[25])
	begin
		if (reset) 
		begin
			state <= I;
			p1_position_x <= 8'bx;
			p1_position_y <= 8'bx;
			p1_direction = 2'bXX;
			
			// Initialize the grid
			for (j = 1; j < GRID_SIZE - 2; j = j + 1)
			begin
				for (i = 1; i < GRID_SIZE - 2; i = i + 1)
				begin
					grid[j][i] <= 1'bX;
				end
			end
		end
		else
			case (state)	
				I:
				begin
					// State transfers
					if (start)
						state <= DRIVING;
					
					p1_position_x <= 10;
					p1_position_y <= 10;
					p1_direction = 0;
			
					// Initialize the grid
					for (j = 0; j < GRID_SIZE - 1; j = j + 1)
					begin
						grid[j][0] <= 1;
						grid[j][GRID_SIZE - 1] <= 1;
						grid[0][j] <= 1;
						grid[GRID_SIZE - 1][j] <= 1;
					end
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
					grid[p1_position_y][p1_position_x] <= 1;
					
					// Move player1 and player2 forward one space in their current direction
					case(p1_direction)
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
					
					// State transfers
					if (collision)
						state <= COLLISION;
				end
				COLLISION:
				begin
					if (start) //TODO ack
						state <= DONE;
				end
				DONE:
				begin
					if (btnC)
						state <= I;
				end
				default:		
					state <= UNK;
			endcase
	end

	// Players' current locations
	wire R = q_I || q_Done || p1_position_y == CounterY && p1_position_x == CounterX;// && CounterY<=(position+10) && CounterX[8:5]==7;
	// Players' previously visited squares, so counterx/y as indices of Grid array
	wire B = grid[CounterY][CounterX];
	// The outer border
	wire G = CounterX < 1 || (CounterX >= (GRID_SIZE - 1) && CounterX < GRID_SIZE) || CounterY < 1 || (CounterY >= (GRID_SIZE - 1)  && CounterY < GRID_SIZE); // && CounterX<200 && CounterY[5:3]==7;

	always @(posedge clk)
	begin
		vga_r <= R & inDisplayArea;
		vga_g <= (G && ~R) & inDisplayArea;
		vga_b <= (B && ~R && ~G) & inDisplayArea;
	end
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  VGA control ends here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  LD control starts here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
	`define QI 			 4'b0001
	`define QDRIVING 	 4'b0010
	`define QCOLLISION 4'b0100
	`define QDONE 		 4'b1000
	
	//reg [3:0] p2_score;
	//reg [3:0] p1_score;
	//reg [1:0] state;
	wire LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
	
	assign LD0 = 1;//(p1_score == 4'b1010);
	assign LD1 = 1;//(p2_score == 4'b1010);
	
	assign LD2 = start;
	assign LD4 = DIV_CLK[25]; //reset;
	
	assign LD3 = (state == `QI);
	assign LD5 = (state == `QDRIVING);
	assign LD6 = (state == `QCOLLISION);
	assign LD7 = (state == `QDONE);
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  LD control ends here 	 	////////////////////
	/////////////////////////////////////////////////////////////////
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  SSD control starts here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
	reg 	[3:0]	SSD;
	wire 	[3:0]	SSD0, SSD1, SSD2, SSD3;
	wire 	[1:0] ssdscan_clk;
	
assign SSD3 = keyboard_buffer[7:4];//4'b1111;
	assign SSD2 = keyboard_buffer[3:0];//4'b1111;
	assign SSD1 = 4'b1111;
	assign SSD0 = 4'b0000;//position[3:0];
	
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
