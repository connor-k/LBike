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
	input PS2_DAT;	//this needs to be defined in UCF
	input PS2_CLK;	//this needs to be defined in UCF
	output St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar;
	output vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b;
	output An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp;
	output LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
	reg vga_r, vga_g, vga_b;
	
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/*  LOCAL SIGNALS */
	wire	reset, start, ClkPort, board_clk, clk, button_clk;
	
	BUF BUF1 (board_clk, ClkPort); 	
	BUF BUF2 (reset, Sw0);
	BUF BUF3 (start, Sw1);
	
	reg [25:0]	DIV_CLK;
	//generate the DIV_CLK signal
	always @ (posedge board_clk, posedge reset)  
	begin : CLOCK_DIVIDER
      if (reset)
			DIV_CLK <= 0;
      else
			DIV_CLK <= DIV_CLK + 1'b1;
	end

	wire[7:0] keyboard_input;
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
		SSD2 <= keyboard_in[7:4];
		SSD3 <= keyboard_in[3:0];
	end
	

	
	assign	button_clk = DIV_CLK[18];
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
	localparam GRID_SIZE = 64;
	localparam LOG_GRID_SIZE = 6;
	reg [GRID_SIZE - 1:0] grid[GRID_SIZE - 1:0]; // 256*256 locations in the grid (2d matrix)
	reg [1:0] p1_direction;
	reg [LOG_GRID_SIZE - 1:0] p1_position_x;
	reg [LOG_GRID_SIZE - 1:0] p1_position_y;
	
	// States
	// Store the current state and output it to top module.
	wire q_I, q_Straight, q_Collision, q_Done;
	reg collision;
	always @ (start, p1_position_y, p1_position_x)
	begin
		if (start)
			collision <= 0;
		else if (grid[p1_position_y][p1_position_x]) //TODO add || head-on collision
			collision <= 1;
	end
	
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
					if (btnC)
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
			end//todo indent
				end		
				DRIVING:
				begin
					// Data transfers
					// Mark the grid at last clock's position to be visited
					grid[p1_position_y][p1_position_x] <= 1;
					
					// BtnL and BtnU control P1 turn left or right
					if (btnU)
						p1_direction = p1_direction + 1;
					if (btnL&&~btnU)
						p1_direction = p1_direction == 0 ? 3 : p1_direction - 1;
					//TODO P2
					
					// Move forward one space
					case(p1_direction)
						2'b00:
							p1_position_x <= p1_position_x+1;
						2'b01:
							p1_position_y <= p1_position_y-1;
						2'b10:
							p1_position_x <= p1_position_x-1;
						2'b11:
							p1_position_y <= p1_position_y+1;
					endcase
					//TODO P2
					
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
			/*if(reset)
				position<=240;
			else if(btnD && ~btnU)
				position<=position+2;
			else if(btnU && ~btnD)
				position<=position-2;
	end */

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
	assign LD4 = reset;
	
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
	
//	assign SSD3 = 4'b1111;
//	assign SSD2 = 4'b1111;
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
			default: SSD_CATHODES = 7'bXXXXXXX ; // default is not needed as we covered all cases
		endcase
	end
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  SSD control ends here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
endmodule
