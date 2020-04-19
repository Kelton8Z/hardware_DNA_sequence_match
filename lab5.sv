`default_nettype none

module Counter 
  #(parameter WIDTH=4) 
  (input  logic             clk, en, clear, load, up, 
   input  logic [WIDTH-1:0] D, 
   output logic [WIDTH-1:0] Q); 
 
  // Clear takes priority over load, which takes priority over counting.    
  always_ff @(posedge clk) 
    if (clear) 
      Q <= 'd0; 
    else if (load) 
      Q <= D; 
    else if (en & up) 
      Q <= Q + 'd1; 
    else if (en & ~up) 
      Q <= Q - 'd1; 
       
endmodule : Counter 

module regLoad
  #(parameter W = 3)
  (input  logic [W-1:0]  D,
   input  logic          ld_L, cl_L,
   input  logic          clock, reset_L,
   output logic [W-1:0]  Q);
  always_ff @(posedge clock,
              negedge reset_L)
    if (~reset_L)
      Q <= 0;
    else  if (~cl_L)
      Q <= 0;
    else if (~ld_L)
      Q <= D;
endmodule: regLoad

module memory_init_nucleo
    #(parameter DW = 2,
                W  = 2<<15,
                AW = $clog2(W))
    (input logic re, we, clock,
     input logic[AW-1:0] Addr,
     inout tri   [DW-1:0] Data);

    logic[DW-1:0] M1[W];
    logic [DW-1:0] out;
    assign Data = (re) ? out: 'bz;

    /*
    always_ff @(posedge clock)
    if (we)
      M1[Addr] <= Data;
    */
    always_comb
        out = M1[Addr];

    initial begin
        string file = "task2nuc.mem"; // "task1checkoffnuc.mem";
        $readmemb(file, M1); //M is the name of your memory array
    end

endmodule:memory_init_nucleo

module memory_init_pattern
    #(parameter DW = 8,
                W  = 2<<11,
                AW = $clog2(W))
    (input logic re, we, clock,
     input logic[AW-1:0] Addr,
     inout tri   [DW-1:0] Data);

    logic [DW-1:0] M2[W];
    logic [DW-1:0] out;
    assign Data = (re) ? out: 'bz;

    /*
    always_ff @(posedge clock)
    if (we)
      M2[Addr] <= Data;
    */
    always_comb
        out = M2[Addr];

    initial begin
        string file = "task2patts.mem";
        $readmemh(file, M2); //M is the name of your memory array
    end

endmodule:memory_init_pattern

module fsm
  (input  logic clock, reset_L,ready,done,isPos,isNeg,isDash,isLetter,isBar,isSlash,pattern_end, mismatch,
   input logic [5:0] count,
    input logic isRep,
   output logic workingNeg,eval,counter_en,counter_ld,counter_up,symbol_ld,cnt_ld,bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L,nucleo_ld_L, pattern_ld_l, found_it,error);
  
  enum logic [3:0] {getting_ready = 4'b0000, slash3=4'b0100, main=4'b0010,bar1=4'b0011,bar2=4'b0101,
        slash1=4'b0110,slash2=4'b0111, Done=4'b0001,pos=4'b1001,neg=4'b1000,pos_lookahead=4'b1111,neg_lookahead=4'b1011} ns, cs;
 
  always_comb begin
    error = isRep;
    eval = 1;
    workingNeg = 0;
    cnt_ld = 0;
    {bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L} = 5'b11111;
    symbol_ld = 0;
    nucleo_ld_L = 0;
    pattern_ld_l =  0;
    found_it = (pattern_end && ! mismatch && !error) ? 1 : 0;
    counter_en = 0;
    counter_ld = 0;
    unique case (cs)
      getting_ready: begin
            {bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L} = 5'b11111;
            eval = 0;
            pattern_ld_l = 1;
            if (ready) begin
                ns = main;
                pattern_ld_l = 0;
            end
            else
                ns = getting_ready;
      end
        main: begin
            eval = 1;
            pattern_ld_l = 0;
            {bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L} = 5'b11111;
            $display("main");
            if (error)
                ns = Done;
            else if (pattern_end) begin
                ns = Done;
            end
            else if (isDash || isLetter) begin
                    $display("isLetter");
                    ns = main;
                    nucleo_ld_L = 0;
                end
            else if (isBar) begin
                    $display("isBar");
                    ns = bar1;
                    nucleo_ld_L = 1;
                end
            else if (isSlash) begin
                    $display("isSlash");
                    ns = slash1;
                    nucleo_ld_L = 1;
                end
            else if (isPos) begin
                    $display("isPos");
                    ns = pos;
                    counter_ld = 1;
                    nucleo_ld_L = 1;
                end
            else if (isNeg) begin
                    $display("isNeg");
                    ns = neg;
                    eval = 0;
                    counter_ld = 1;
                    nucleo_ld_L = 1;
                end
            else begin
                error = 1;
                ns = Done;
            end 
        end
        bar1: begin
            {bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L} = 4'b1111;
            eval = 0;
            bar1_ld_L = 0;
            if (isLetter) begin
                ns = bar2;
                nucleo_ld_L = 1;
            end
            else begin
                ns = Done;
                error = 1;
                found_it = 0;
            end
        end
        bar2: begin
            {bar1_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L} = 4'b1111;
            eval = 0;
            bar2_ld_L = 0;
            if (isLetter) begin
                if (mismatch)
                    ns = Done;
                else begin
                    eval = 1;
                    ns = main;
                end
                nucleo_ld_L = 0;
            end
            else begin
                ns = Done;
                error = 1;
                found_it = 0;
            end
        end
        slash1: begin
            {bar1_ld_L,bar2_ld_L,slash2_ld_L,slash3_ld_L} = 4'b1111;
            eval = 0;
            slash1_ld_L = 0;
            if (isLetter) begin
                ns = slash2;
                nucleo_ld_L = 1;
            end
            else begin
                ns = Done;
                error = 1;
                found_it = 0;
            end
        end
        slash2: begin
            {bar1_ld_L,bar2_ld_L,slash3_ld_L} = 3'b111;
            eval = 0;
            slash2_ld_L = 0;
            if (isLetter) begin
                ns = slash3;
                nucleo_ld_L = 1;
            end
            else begin
                ns = Done;
                error = 1;
                found_it = 0;
            end
        end
        slash3: begin
            {bar1_ld_L,bar2_ld_L} = 2'b11;
            eval = 0;
            slash3_ld_L = 0;
            $display("slash3 state");
            if (isRep) begin
                ns = Done;
                found_it = 0;
                error = 1;
            end
            else if (isLetter) begin
                ns = main;
                nucleo_ld_L = 0;
            end
            else begin
                ns = Done;
                error = 1;
                found_it = 0;
            end
        end
        pos: begin
            {bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L} = 5'b11111;
            counter_en = 1;
            counter_up = 0;
            eval = 1;
            cnt_ld = 1;
            if (isLetter || isDash) begin
                if (count > 1) begin
                    ns = pos;
                    nucleo_ld_L = 0;
                    pattern_ld_l = 1;
                end
                else begin
                    nucleo_ld_L = 0;
                    pattern_ld_l = 0;
                    ns = main;
                end
            end
            else begin
                ns = Done;
                error = 1;
            end
        end
        neg: begin
            {bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L} = 5'b11111;
            counter_en = 1;
            counter_up = 0;
            workingNeg = 1;
            eval = 1;//(count==2);
            cnt_ld = 1;
            if (isLetter || isDash) begin
                if (count > 1 && !mismatch) begin
                    ns = neg;
                    nucleo_ld_L = 0;
                    pattern_ld_l = 1;
                end
                else begin
                    ns = main;
                    nucleo_ld_L = 0;
                    pattern_ld_l = 0;
                end
            end
            else begin
                ns = Done;
                error = 1;
                found_it = 0;
            end
        end
        Done: begin
            eval = 1;
            nucleo_ld_L = 1;
            if (done && pattern_end && !error) found_it = mismatch ? 0 : 1;
                ns = main;
         end
        
        default : begin
            {bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L,eval} = 6'b111111; 
            ns = Done;
        end
    endcase
 end

  always_ff @(posedge clock, negedge reset_L)
    if (~reset_L) cs <= getting_ready;
    else cs <= ns;
endmodule: fsm

module task1(input  logic ready,
            input  logic[15:0] dna_start,dna_length,
            input  logic[11:0] pattern_start,
            output logic done, found_it, error, mismatch,
            output logic[23:0] duration,
            output logic[5:0] count,
            input  logic clock, reset_L);

    logic workingNeg,counter_ld,counter_en,counter_up, symbol_ld,cnt_ld,pattern_end,isRep,eval,isPos,isNeg,isDash,isLetter,isBar,isSlash,
        bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L, nucleo_ld_L, pattern_ld_l;
    logic [11:0] Addr_pattern;
    logic [15:0] Addr_nucleo;

    tri [7:0] pattern_data;
    tri [1:0] nucleo_data; 

    logic [7:0] barOne, barTwo, slashOne, slashTwo, slashThree;

    // clk, en, clear, load, up
    logic counter_en,counter_ld,counter_up;
    logic [5:0] cnt_data;
    Counter #(6) c9 (clock,counter_en,0,counter_ld, counter_up,cnt_data,count);
    
    memory_init_pattern m1(1'b1,1'b0,clock,Addr_pattern,pattern_data);
    memory_init_nucleo m2(1'b1,1'b0,clock,Addr_nucleo,nucleo_data);

    fsm f(clock, reset_L,ready,done,isPos,isNeg,isDash,isLetter,isBar,isSlash,pattern_end,mismatch,count,isRep,
        workingNeg,eval,counter_en,counter_ld,counter_up,symbol_ld,cnt_ld,bar1_ld_L,bar2_ld_L,slash1_ld_L,slash2_ld_L,slash3_ld_L,nucleo_ld_L, pattern_ld_l, found_it, error);
    
    logic [11:0] tmpp; 
    logic [15:0] tmppp;
    logic [11:0] Addr_patternnn;
    assign Addr_patternnn = ready ? pattern_start : Addr_pattern+1;
    assign tmpp = ready ? pattern_start : 12'b1;
    assign tmppp = ready ? dna_start : 16'b1;
    regLoad #(12) r1 (Addr_patternnn/*Addr_pattern+ tmpp*/, pattern_ld_l, 1, clock,
                   reset_L, Addr_pattern);
    regLoad #(16) r2 (Addr_nucleo+ tmppp, nucleo_ld_L, 1, clock,
                   reset_L,Addr_nucleo);

    regLoad #(8) r7 (pattern_data, bar1_ld_L, 1, clock,
                   reset_L,barOne);
    regLoad #(8) r6 (pattern_data, bar2_ld_L, 1, clock,
                   reset_L,barTwo);
    regLoad #(8) r3 (pattern_data, slash1_ld_L, 1, clock,
                   reset_L,slashOne);
    regLoad #(8) r4 (pattern_data, slash2_ld_L, 1, clock,
                   reset_L,slashTwo);
    regLoad #(8) r5 (pattern_data, slash3_ld_L, 1, clock,
                   reset_L,slashThree);
    logic [23:0] tmp;
    // should be cleared when ready is asserted, count each clock edge until done 
    // and then keep the same value until a new ready comes in
    assign tmp = ready ? 24'b0 : done ? duration : duration + 24'b1;

    regLoad #(24) r8 (tmp, 0, 1, clock,
                   reset_L,duration);
    
    logic [5:0] symbol;
    regLoad #(6) r17 (pattern_data,symbol_ld,1,clock,reset_L,symbol);

    logic [7:0] mapped_nucleo_data;
    map m(nucleo_data,mapped_nucleo_data);   

    always_comb begin
        $display("datapath");
        pattern_end = 0;
        isDash = 0;
        isRep = 0;
        if (pattern_data == 6'h0) begin
             if ((barOne == barTwo && barOne != 0 && !bar1_ld_L&&!bar2_ld_L )
                || (slashOne== slashTwo && !slash3_ld_L) //slashOne != 0 && pattern_data != 0 && !slash1_ld_L && !slash2_ld_L)
                || (slashTwo == pattern_data && !slash3_ld_L )
                || (slashOne == pattern_data && !slash3_ld_L)) isRep = 1;
            done = 1;
            isLetter = 0;
            //if (error) mismatch = 1;
            pattern_end = 1;
        end
        else begin
                 if ((barOne == barTwo && barOne != 0 && !bar1_ld_L&&!bar2_ld_L )
                || (slashOne== slashTwo && !slash3_ld_L) //slashOne != 0 && pattern_data != 0 && !slash1_ld_L && !slash2_ld_L)
                || (slashTwo == pattern_data && !slash3_ld_L )
                || (slashOne == pattern_data && !slash3_ld_L)) isRep = 1; 
            mismatch = 0;
            pattern_end = 0;
            // case invalid symbol
            if ( pattern_data != 0 && pattern_data[5] == 0 && pattern_data <= 6'hF) begin // positive numbers
                cnt_data = pattern_data;
                isPos = 1;
                isLetter = 0;
                isNeg = 0;
                isDash = 0;
                isBar = 0;
                isSlash = 0;
                done = 0;
            end
            else if (pattern_data[5] == 1'b1 && pattern_data >= 6'h31) begin // negative numbers
                cnt_data = ~pattern_data + 1'b1;
                isNeg = 1;
                isLetter = 0;
                isPos = 0;
                isDash = 0;
                isBar = 0;
                isSlash = 0;
                done = 0;
            end
            else if (pattern_data == 6'h20) begin
                isDash = 1;
                isPos = 0;
                isNeg = 0;
                isBar = 0;
                 isSlash = 0;
                 isLetter = 0;
            end
            else if (pattern_data == 6'h21) begin
                 isBar = 1;
                 isPos = 0;
                 isNeg = 0;
                 isDash = 0;
                 isSlash = 0;
                 isLetter = 0;
                 done = 0; // new
            end
            else if (pattern_data == 6'h22) begin 
                isSlash = 1;
                isPos = 0;
                isNeg = 0;
                isDash = 0;
                isBar = 0;
                isLetter = 0;
               done = 0; // new
            end
            else if (pattern_data == 6'h10 || pattern_data == 6'h11 || pattern_data == 6'h12 || pattern_data == 6'h13) begin 
                isLetter = 1;
                isPos = 0;
                isNeg = 0;
                isDash = 0;
                isBar = 0;
                isSlash = 0;
                done = 0; // new
                // case mismatch
                if (error) begin
                    mismatch = 1;
                    done = 1;
                end
                if (eval) begin
                    if (pattern_data != mapped_nucleo_data && barOne != mapped_nucleo_data && barTwo != mapped_nucleo_data && 
                             slashOne != mapped_nucleo_data && slashTwo != mapped_nucleo_data && slashThree != mapped_nucleo_data) begin 
                        mismatch = 1;
                        if (!workingNeg) done = 1;
                    end
                end
            end
            else begin // invalid
                isDash = 0;
                isPos = 0;
                isNeg = 0; 
                isLetter = 0;
                isBar = 0;
                isSlash = 0;
                done = 1;
            end
       end
    end
endmodule:task1


// 6'h10 C Matches Cytosine (2'b00 in MemDNA)
// 6'h11 T Matches Thymine (2'b01 in MemDNA)
// 6'h12 A Matches Adenine (2'b10 in MemDNA)
// 6'h13 G Matches Guanine (2'b11 in MemDNA)
module map(
    input logic[1:0] nucleo,
    output logic[7:0] pattern);

    always_comb begin
        if (nucleo==2'b00) pattern = 8'h10;
        if (nucleo==2'b01) pattern = 8'h11;
        if (nucleo==2'b10) pattern = 8'h12;
        if (nucleo==2'b11) pattern = 8'h13;
    end
endmodule:map

module mapLetter(
    input logic[7:0] code,
    output byte letter);

    always_comb begin
        if (code==8'h10) letter = "C";
        if (code==8'h11) letter = "T";
        if (code==8'h12) letter = "A";
        if (code==8'h13) letter = "G";
        if (code==8'h3E) letter = "-2";
        if (code==8'h3D) letter = "-3";
        if (code==8'h37) letter = "-9";
        if (code==8'h4) letter = "4";
    end
endmodule:mapLetter

module task1_test;

    logic [5:0] count;
    logic[15:0] dna_start;
    logic[11:0] pattern_start;
    logic[15:0] dna_length;
    logic[23:0] duration;
    logic mismatch, clock, reset_L, ready, done, error, found_it, pattern_end, isRep;

    task1 dut(.*);

    byte nucleoLetter;
    mapLetter ml1 (dut.mapped_nucleo_data,nucleoLetter);
    byte patternLetter;
    mapLetter ml2 (dut.pattern_data,patternLetter);
 
    initial begin //  manage  your  reset  and  clock  here
        clock = 0;
        reset_L = 0;
        reset_L <= 1;
        forever #5 clock = ~clock;
    end

    initial begin
        $monitor($time,,"state = %s, slashOne = %h, slashTwo = %h, slashThree = %h, barOne = %h, barTwo = %h,pattern load low = %b,pattern mem addr = %h, pattern data = %s, nucleo mem addr = %h, nucleo data = %s, dna_start= %h, pattern_start= %h, dna_length = %b, duration = %b, ready = %b, done = %b, error = %b, found_it = %b, pattern_end = %b, mismatch = %b, isRep = %b, isPos = %d, isNeg = %d, isLetter = %d, count = %d", 
        dut.f.cs.name, dut.slashOne, dut.slashTwo, dut.slashThree, dut.barOne, dut.barTwo, dut.pattern_ld_l,dut.Addr_pattern,patternLetter,dut.Addr_nucleo,nucleoLetter, dut.dna_start, dut.pattern_start, dna_length, duration, ready, done, error, found_it, dut.pattern_end,mismatch,dut.isRep,dut.isPos,dut.isNeg, dut.isLetter, dut.count);
         
        pattern_start <= 12'h0;
        dna_start <= 16'd0;   
        ready <= 1; @(posedge clock); 
        ready <= 0;
        while (!done) begin
            @(posedge clock);
        end
        #20
        $finish;
    end
endmodule:task1_test

