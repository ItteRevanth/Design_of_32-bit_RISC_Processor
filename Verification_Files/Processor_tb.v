//Directed TestBench for the functional verification of RISC processor in Verilog

module RISC_test;
	reg clk1,clk2;      //Two clocks for alternate stages of pipeline
	integer k;
  RISC_32 risc(clk1,clk2);   //Instantiating DUT

//Generating the clock signals
	initial
		begin
			clk1=0; clk2=0;
          repeat(20)
				begin
					#5 clk1=1; #5 clk1=0;
					#5 clk2=1; #5 clk2=0;
				end
		end
	
	initial
		begin
      for(k=0;k<31;k=k+1)       //Initiating registers
				mips.Reg[k]=k;

  //Loading 32-bit Instructions into the program memory
			risc.Mem[0]=32'h2801000a;      // ADDI R1,R0,10
			risc.Mem[1]=32'h28020014;      // ADDI R2,R0,20
			risc.Mem[2]=32'h28030019;      // ADDI R3,R0,25
			risc.Mem[3]=32'h0ce77800;      // OR R7,R7,R7 ---> Dummy insruction
      risc.mem[4]=32'h20000008;      //LW R0,0,8;
      risc.Mem[5]=32'h0ce77800;      // OR R7,R7,R7 ---> Dummy insruction
      risc.Mem[6]=32'h00222000;      // ADD R4,R1,R2
      risc.Mem[7]=32'h0ce77800;      // OR R7,R7,R7 ---> Dummy insruction
      risc.Mem[8]=32'h00832800;      // ADD R5,R3,R4
      risc.Mem[9]=32'hfc000000;      //HALT

  //Initiating flag registers and counter to zero
			risc.HALTED=0;
			risc.TAKEN_BRANCH=0;
			risc.PC=0;
			

  //Displaing results after processor executed instructions
      #280 for(k=0;k<6;k+=1) 
	      $display("R%1d - %2d",k,risc.Reg[k]);
		end

  //Creating a VCD file for waveform of all signals
	initial
		begin
			$dumpfile("RISC32_Processor.vcd");
			$dumpvars(0,RISC_test);
			#300 $finish;
		end
endmodule

