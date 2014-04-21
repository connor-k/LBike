/* 
 * Connor Kerns & Nolan Miller
 * EE 201 Final Project -- State Machine (One-Hot)
 * Spring 2014
*/
`timescale 1ns / 1ps

//TODO variables to track current position, direction heading
module ee201_Lightbike(Clk, Reset, Start, Ack, Grid, P1L, P1R, P2L, P2R, q_I, q_Straight, q_Turning, q_Collision, q_Done);
	/*  INPUTS */
	input Clk, Reset, Start, Ack, P1L, P1R, P2L, P2R;
	
	/*  OUTPUTS */
	// Store the Grid as a reg. It is continuously output to the top module.
	output reg [65535:0] Grid; // 256*256 locations in the grid (1d vector vs 2d matrix)
	// Store the current state and output it to top module.
	output q_I, q_Straight, q_Turning, q_Collision, q_Done;
	reg [4:0] state;
	assign {q_I, q_Straight, q_Turning, q_Collision, q_Done} = state;
	
	// localparam's for the state case statements
	localparam
	I = 5'b00001, STRAIGHT = 5'b00010, TURNING = 5'b00100, COLLISION = 5'b01000, DONE = 5'b10000, UNK = 5'bXXXXX;
	
	// Next State Logic and State Machine
	always @ (posedge Clk, posedge Reset)
	begin : my_lightbike_sm
		if (Reset) 
		  begin
			state <= I;
			Grid <= 0;
			//TODO set border to visited
		  end
		else
			case (state)	
				I:
				begin
					// State transfers
					if (Start)
						state <= SUB;
				end		
				STRAIGHT:
				begin	
					// State transfers
					if (P1L || P1R || P2L || P2R)
						state <= TURNING;
					// Data transfers
					//TODO mark the squares ahead of current position to be visited
					//TODO check for collision. Perhaps have an always block above and collision signal???
				end
				TURN:
				begin
					// State transfers
					if ~((P1L || P1R || P2L || P2R))
						state <= STRAIGHT;
					// Data transfers
					//TODO mark the squares ahead of current position to be visited
					//TODO check for collision. Perhaps have an always block above and collision signal???
				end
				COLLISION: //TODO consider removing this state
				begin
					state <= DONE;
				end
				DONE:
				begin
					if (Ack)
						state <= I;
				end
				default:		
					state <= UNK;
			endcase
	end
		
	//TODO OFL ?
	
endmodule
