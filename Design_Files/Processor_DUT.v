// Code for design of RISC Processor in Verilog HDL
//Contains 5-stages : Instruction Fetch, Instruction Decoding, Execution, Memory Accessing and Write Back
//Used different clocks for alternate stages to avoid data corruption errors
//Contains 2-flag registers, 32 - General Purpose Registers of which 1st register is default to zero
//Each instruction is 32-bit wide and 1k such instructions can be stored in program memory

module RISC_32(clk1,clk2);
	input clk1,clk2;
	
  //Signals for each stage associated with latches between them
	reg [31:0] IF_ID_IR,PC,IF_ID_NPC;
	reg [31:0] ID_EX_A,ID_EX_B,ID_EX_NPC,ID_EX_IR,ID_EX_Imm;
	reg [2:0] ID_EX_type,EX_MEM_type,MEM_WB_type;
	reg [31:0] EX_MEM_IR,EX_MEM_ALUout,EX_MEM_B,EX_MEM_cond;
	reg [31:0] MEM_WB_ALUout,MEM_WB_IR,MEM_WB_LMD;
	
  reg [31:0] Reg [0:31];         //Register Bank
  reg [31:0] Mem [0:1023];       //Program Memory
	
   //R-type instructions
	parameter ADD=6'b000000, SUB=6'b000001, AND=6'b000010, OR=6'b000011, SLT=6'b000100, MUL=6'b000101, HLT=6'b111111;
  
  //S-type,I-type and B-type instructions
	parameter LW=6'b001000, SW=6'b001001, ADDI=6'b001010, SUBI=6'b001011, SLTI=6'b001100, BNEQZ=6'b001101, BEQZ=6'b001110;
	
  //parameter to define the type of instruction
	parameter RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010, STORE=3'b011, BRANCH=3'b100, HALT=3'b101;
	
	reg HALTED, TAKEN_BRANCH;   //Flag registrs for halt and branch
	
    always@(posedge clk1)           // IF-Intruction Fetch Stage
		begin
            if(HALTED==0)            //Check if halt flag is not active
				begin
					if(((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_cond==1)) || ((EX_MEM_IR[31:26]==BNEQZ) && (EX_MEM_cond==0))) //Check if branch is taken
						begin
              IF_ID_IR <= #2 Mem[EX_MEM_ALUout];  //Load branch address
							TAKEN_BRANCH <= #2 1'b1;            //Activate branch flag high
							IF_ID_NPC <= #2 EX_MEM_ALUout+1;   //Update program counter
							PC <= #2 EX_MEM_ALUout+1;
						end
					else
						begin
              IF_ID_IR <= #2 Mem[PC];   //Load next instruction address
							IF_ID_NPC <= #2 PC+1;    //Update program counter
							PC <= #2 PC+1;
						end
				end
		end
	
    always@(posedge clk2)           //ID-Instruction Decoding Stage
		begin
      if(HALTED==0)         //Check if halt flag is inactive
				begin
					ID_EX_IR <= #2 IF_ID_IR;
					ID_EX_NPC <= #2 IF_ID_NPC;
          if(IF_ID_IR[25:21]==5'b00000) ID_EX_A <= 0;        //Decoding source register1 
					else ID_EX_A <= #2 Reg[IF_ID_IR[25:21]];
					
          if(IF_ID_IR[20:16]==5'b00000) ID_EX_B <= 0;       //Decoding source register2
					else ID_EX_B <= #2 Reg[IF_ID_IR[20:16]];
					
          ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};   //Decoding Immediate Value
			
          case(IF_ID_IR[31:26])                                 //Decoding type of instruction for ALU
						ADD,SUB,AND,OR,SLT,MUL: ID_EX_type <= #2 RR_ALU;
						ADDI,SUBI,SLTI: ID_EX_type <= #2 RM_ALU;
						BEQZ,BNEQZ: ID_EX_type <= #2 BRANCH;
						LW: ID_EX_type <= #2 LOAD;
						SW: ID_EX_type <= #2 STORE;
						HLT: ID_EX_type <= #2 HALT;
						default: ID_EX_type <= #2 HALT;
					endcase
				end
		end
	
    always@(posedge clk1)           //EX-Execution Stage
      if(HALTED==0)        //Check if halt flag is inactive
			begin
				EX_MEM_type <= #2 ID_EX_type;
				EX_MEM_IR <= #2 ID_EX_IR;
				TAKEN_BRANCH <= #2 1'b0;  //Deactivating Branch taken flag
				
        case(ID_EX_type)                        //Implementing ALU operation on operands
					  RR_ALU:begin            //Register-Register Type
						case(ID_EX_IR[31:26])
							ADD:EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_B; 
							SUB:EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_B;
							OR:EX_MEM_ALUout <= #2 ID_EX_A | ID_EX_B;
							AND:EX_MEM_ALUout <= #2 ID_EX_A & ID_EX_B;
							MUL:EX_MEM_ALUout <= #2 ID_EX_A * ID_EX_B;
							SLT:EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_B;
							default:EX_MEM_ALUout <= #2 32'hxxxxxxxx;
						endcase
					end
					RM_ALU:begin            //Register-Immediate type
						case(ID_EX_IR[31:26])
							ADDI:EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_Imm;
							SUBI:EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_Imm;
							SLTI:EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_Imm;
							default:EX_MEM_ALUout <= #2 32'hxxxxxxxx;
						endcase
					end
					BRANCH:begin            //Branch Type
							EX_MEM_ALUout <= #2 ID_EX_NPC + ID_EX_Imm;
							EX_MEM_cond <= #2 (ID_EX_A==0);
						end
					LOAD,STORE:begin       //Load or Store
							EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_Imm;
							EX_MEM_B <= #2 ID_EX_B;
						end
				endcase
			end
			
  always@(posedge clk2)             //MEM - Memory accesing Stage
    if(HALTED==0)     //Check if halt flag is inactive
			begin
				MEM_WB_IR <= #2 EX_MEM_IR;
				MEM_WB_type <= #2 EX_MEM_type;
				case(EX_MEM_type)
					RR_ALU,RM_ALU: MEM_WB_ALUout <= #2 EX_MEM_ALUout;  
          LOAD: MEM_WB_LMD <= #2 Mem[EX_MEM_ALUout];                    //Loading from memory
          STORE:if(TAKEN_BRANCH==0) Mem[EX_MEM_ALUout] <= #2 EX_MEM_B;  //Storing into memory
				endcase
			end
	
  always@(posedge clk1)             //WB-Write Back Stage
    if(TAKEN_BRANCH==0)       //Check if halt flag is inactive
			begin
				case(MEM_WB_type)
          RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUout;      //Stroing ALU results into destination registers
					RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUout;
					LOAD: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD;
					HALT: HALTED <= #2 1'b1;
				endcase
			end
endmodule






