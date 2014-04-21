/* 
 * Connor Kerns & Nolan Miller
 * EE 201 Final Project -- Top Design
 * Spring 2014
*/
`timescale 1ns / 1ps

module ee201_Lightbike_top
	(MemOE, MemWR, RamCS, FlashCS, QuadSpiFlashCS, // Disable the three memory chips
    ClkPort,                           // The 100 MHz incoming clock signal
	BtnL, BtnU, BtnD, BtnR,            // The Left, Up, Down, and the Right buttons
	BtnC,                              // The center button (reset)
	An3, An2, An1, An0,			       // 4 anodes
	Ca, Cb, Cc, Cd, Ce, Cf, Cg,        // 7 cathodes
	Dp                                 // Dot Point Cathode on SSDs
    );

	/*  INPUTS */
	// Clock & Reset I/O
	input		ClkPort;
	// Reset and Turning buttons
	input		BtnL, BtnU, BtnD, BtnR, BtnC;
	
	/*  OUTPUTS */
	// Control signals on Memory chips 	(to disable them)
	output 	MemOE, MemWR, RamCS, FlashCS, QuadSpiFlashCS;
	// SSD Outputs
	output 	Cg, Cf, Ce, Cd, Cc, Cb, Ca, Dp;
	output 	An0, An1, An2, An3;	

	
	/*  LOCAL SIGNALS */
	wire		Reset, ClkPort;
	wire		board_clk, sys_clk;
	wire [1:0] 	ssdscan_clk;
	reg [26:0]	DIV_CLK;
	
	wire Start_Ack_Pulse;
	wire BtnR_Pulse, BtnU_Pulse;
	wire q_I, q_Straight, q_Turning, q_Collision, q_Done;
	reg [65535:0] Grid_top;
	reg A_bar_slash_B;
	reg [3:0]	SSD;
	wire [3:0]	SSD3, SSD2, SSD1, SSD0;
	reg [7:0]  SSD_CATHODES;
	
	//------------
	// Disable the three memories so that they do not interfere with the rest of the design.
	assign {MemOE, MemWR, RamCS, FlashCS, QuadSpiFlashCS} = 5'b11111;
	
	
	//------------
	// CLOCK DIVISION

	// The clock division circuitary works like this:
	//
	// ClkPort ---> [BUFGP2] ---> board_clk
	// board_clk ---> [clock dividing counter] ---> DIV_CLK
	// DIV_CLK ---> [constant assignment] ---> sys_clk;
	
	BUFGP BUFGP1 (board_clk, ClkPort); 	

	// As the ClkPort signal travels throughout our design,
	// it is necessary to provide global routing to this signal. 
	// The BUFGPs buffer these input ports and connect them to the global 
	// routing resources in the FPGA.

	// BUFGP BUFGP2 (Reset, BtnC); In the case of Spartan 3E (on Nexys-2 board), we were using BUFGP to provide global routing for the reset signal. But Spartan 6 (on Nexys-3) does not allow this.
	assign Reset = BtnC;
	
	//------------
	// Our clock is too fast (100MHz) for SSD scanning
	// create a series of slower "divided" clocks
	// each successive bit is 1/2 frequency
	always @(posedge board_clk, posedge Reset) 	
    begin							
        if (Reset)
		DIV_CLK <= 0;
        else
		DIV_CLK <= DIV_CLK + 1'b1;
    end
	//-------------------	
	// In this design, we run the core design at full 50MHz clock!
	assign	sys_clk = board_clk;
	// assign	sys_clk = DIV_CLK[25];

	//------------
	// INPUT: SWITCHES & BUTTONS
	// BtnL is used as both Start and Acknowledge. 
	// To make this possible, we need a single clock producing  circuit.

	ee201_debouncer #(.N_dc(28)) ee201_debouncer_2(.CLK(sys_clk), .RESET(Reset), .PB(BtnL), .DPB( ), .SCEN(Start_Ack_Pulse), .MCEN( ), .CCEN( ));
		 		 
	// BtnR is used to generate in_AB_Pulse to record the values of 
	// the inputs A and B as set on the switches.
	// BtnU is used as CEN_Pulse to allow single-stepping
	assign {in_AB_Pulse, CEN_Pulse} = {BtnR_Pulse, BtnU_Pulse};

ee201_debouncer #(.N_dc(28)) ee201_debouncer_1 
        (.CLK(sys_clk), .RESET(Reset), .PB(BtnR), .DPB( ), 
		.SCEN(BtnR_Pulse), .MCEN( ), .CCEN( ));

ee201_debouncer #(.N_dc(28)) ee201_debouncer_0 // ****** TODO  in Part 2 ******
        (.CLK(sys_clk), .RESET(Reset), .PB(BtnU), .DPB( ), 
		.SCEN(BtnU_Pulse), .MCEN( ), .CCEN( ));
		/*(                                      // complete this instantiation
		                                    ); // to produce BtnU_Pulse from BtnU */
		
//------------
// DESIGN
	// On two pushes of BtnR, numbers A and B are recorded in Ain and Bin
    // (registers of the TOP) respectively
	always @ (posedge sys_clk, posedge Reset)
	begin
		if(Reset)
		 begin			// ****** TODO  in Part 2 ******
			Ain <= 8'b0000000;  	// Is it necessary or desirable to initiate
			Bin <=  8'b0000000;	//  Ain and Bin to zero?
			// When you download the TA's .bit file or when you reset the Nexys-2 
			// do you see "0000" on the SSDs or some random combination?
			// When you go from DONE state to INITIAL state after working on a set
			// Ain and Bin, do you see "0000" again in the INITIAL state?
			// If not, what do you see?
			
			A_bar_slash_B <= 0;
		 end
		else
		 begin
			if (in_AB_Pulse)  	// Note: in_AB_Pulse is same as BtnR_Pulse.
								// ****** TODO  in Part 2 ******
								// Complete the lines below so that you deposit the value on switches
								// either in Ain or in Bin based on the value of the flag A_bar_slash_B. 
								// Also you need to toggle the value of the flag A_bar_slash_B.
				begin
					A_bar_slash_B <= ~ A_bar_slash_B;  	// should this line be "before" (as shown) 
														// or "after" the "if" statement?
														// Please discuss with your TA.
														// Recall aspects of the non-blocking assignment, and how delta-T 
														// avoids race condition in real (physical) registers operation
					if (A_bar_slash_B)  // complete this line
						Ain <= {Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0};
					else
						Bin <= {Sw7, Sw6, Sw5, Sw4, Sw3, Sw2, Sw1, Sw0}; // complete this line
				end
		 end
	end
	
	// the state machine module
	ee201_GCD ee201_GCD_1(.Clk(sys_clk), .CEN(CEN_Pulse), .Reset(Reset), .Start(Start_Ack_Pulse), .Ack(Start_Ack_Pulse), 
						  .Ain(Ain), .Bin(Bin), .A(A), .B(B), .AB_GCD(AB_GCD), .i_count(i_count),
						  .q_I(q_I), .q_Sub(q_Sub), .q_Mult(q_Mult), .q_Done(q_Done));

//------------
// OUTPUT: LEDS
	
	assign {Ld7, Ld6, Ld5, Ld4} = {q_I, q_Sub, q_Mult, q_Done};
	assign {Ld3, Ld2, Ld1, Ld0} = {BtnL, BtnU, BtnR, BtnD}; // Reset is driven by BtnC
	// Here
	// BtnL = Start/Ack
	// BtnU = Single-Step
	// BtnR = in_A_in_B
	// BtnD = not used here
	
//------------
// SSD (Seven Segment Display)
	
	//SSDs show Ain and Bin in initial state, A and B in subtract state, and GCD and i_count in multiply and done states.
	// ****** TODO  in Part 2 ******
	// assign y = s ? i1 : i0;  // an example of a 2-to-1 mux coding
	// assign y = s1 ? (s0 ? i3: i2): (s0 ? i1: i0); // an example of a 4-to-1 mux coding
	assign SSD3 = (q_Mult | q_Done) ? AB_GCD[7:4]  : q_I ? Bin[7:4] : B[7:4];
	assign SSD2 = (q_Mult | q_Done) ? AB_GCD[3:0]  : q_I ? Bin[3:0] : B[3:0];
	assign SSD1 = (q_Mult | q_Done) ? i_count[7:4]  : q_I ? Ain[7:4] : A[7:4];
	assign SSD0 = (q_Mult | q_Done) ? i_count[3:0]  : q_I ? Ain[3:0] : A[3:0];


	// need a scan clk for the seven segment display 
	
	// 100 MHz / 2^18 = 381.5 cycles/sec ==> frequency of DIV_CLK[17]
	// 100 MHz / 2^19 = 190.7 cycles/sec ==> frequency of DIV_CLK[18]
	// 100 MHz / 2^20 =  95.4 cycles/sec ==> frequency of DIV_CLK[19]
	
	// 381.5 cycles/sec (2.62 ms per digit) [which means all 4 digits are lit once every 10.5 ms (reciprocal of 95.4 cycles/sec)] works well.
	
	assign ssdscan_clk = DIV_CLK[19:18];
	
	assign An3	= !(~(ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 00
	assign An2	= !(~(ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 01
	assign An1	=  !((ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 10
	assign An0	=  !((ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 11
	
	
	always @ (ssdscan_clk, SSD0, SSD1, SSD2, SSD3)
	begin : SSD_SCAN_OUT
		case (ssdscan_clk) 
				  2'b00: SSD = SSD3;	// ****** TODO  in Part 2 ******
				  2'b01: SSD = SSD2;  	// Complete the four lines
				  2'b10: SSD = SSD1;
				  2'b11: SSD = SSD0;
		endcase 
	end
	
	// and finally convert SSD_num to ssd
	// We convert the output of our 4-bit 4x1 mux

	assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp} = {SSD_CATHODES};

	// Following is Hex-to-SSD conversion
	always @ (SSD) 
	begin : HEX_TO_SSD
		case (SSD) // in this solution file the dot points are made to glow by making Dp = 0
		    //                                                                abcdefg,Dp
			// ****** TODO  in Part 2 ******
			// Revise the code below so that the dot points do not glow for your design.
			4'b0000: SSD_CATHODES = 8'b00000011; // 0
			4'b0001: SSD_CATHODES = 8'b10011111; // 1
			4'b0010: SSD_CATHODES = 8'b00100101; // 2
			4'b0011: SSD_CATHODES = 8'b00001101; // 3
			4'b0100: SSD_CATHODES = 8'b10011001; // 4
			4'b0101: SSD_CATHODES = 8'b01001001; // 5
			4'b0110: SSD_CATHODES = 8'b01000001; // 6
			4'b0111: SSD_CATHODES = 8'b00011111; // 7
			4'b1000: SSD_CATHODES = 8'b00000001; // 8
			4'b1001: SSD_CATHODES = 8'b00001001; // 9
			4'b1010: SSD_CATHODES = 8'b00010001; // A
			4'b1011: SSD_CATHODES = 8'b11000001; // B
			4'b1100: SSD_CATHODES = 8'b01100011; // C
			4'b1101: SSD_CATHODES = 8'b10000101; // D
			4'b1110: SSD_CATHODES = 8'b01100001; // E
			4'b1111: SSD_CATHODES = 8'b01110001; // F    
			default: SSD_CATHODES = 8'bXXXXXXXX; // default is not needed as we covered all cases
		endcase
	end	
	
endmodule
