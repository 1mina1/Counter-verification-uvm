interface Up_Dn_Counter_if ();
  logic [4:0]    IN;
  logic          Load;
  logic          UP;
  logic          DOWN;
  logic [4:0]    Counter;
  logic          clk;
  logic          RST;
  logic          High, Low;
  
endinterface

import uvm_pkg::*;
`include "uvm_macros.svh"
`timescale 1ns/1ps
//////////////////////transactions///////////////////////
class transactions extends uvm_sequence_item;
  rand bit [4:0] IN;
  rand bit       Load;
  rand bit       UP;
  rand bit       DOWN;
  bit      [4:0] Counter;
  bit            High, Low;
  
  
  //constructor
  function new(input string inst ="TRANS");
    super.new(inst);
  endfunction
  
  ///registering the transactions objects to a factory
  `uvm_object_utils_begin(transactions)
  `uvm_field_int(IN,UVM_DEFAULT)
  `uvm_field_int(Load,UVM_DEFAULT)
  `uvm_field_int(UP,UVM_DEFAULT)
  `uvm_field_int(DOWN,UVM_DEFAULT)
  `uvm_field_int(Counter,UVM_DEFAULT)
  `uvm_field_int(High,UVM_DEFAULT)
  `uvm_field_int(Low,UVM_DEFAULT)
  `uvm_object_utils_end
endclass

////////////////////generator////////////////////////
class generator extends uvm_sequence #(transactions);
  //registering to a factory
  `uvm_object_utils(generator);
  transactions t;
  integer i;
  
  
  /////////////coverage/////////////
  covergroup cg;
    c1: coverpoint t.IN {bins low  = {0};
                       bins high = {31};
                         bins normal[] ={[1:30]};}
    c2: coverpoint t.Load {bins low = {0};
                         bins high = {1};}
    c3: coverpoint t.UP   {bins low = {0};
                         bins high = {1};}
    c4: coverpoint t.DOWN {bins low = {0};
                         bins high = {1};}
  endgroup
  
  //constructor
  function new(input string inst ="GEN");
    super.new(inst);
    cg = new();
  endfunction
  
  
  virtual task body();
  t =transactions::type_id::create("TRANS");
  for(i=0;i<200;i++)
  begin
    start_item(t);
    `uvm_info("GEN","Data sent to DRIVER",UVM_NONE)
    assert(t.randomize());
    cg.sample();
    t.print(uvm_default_line_printer);
    finish_item(t);
    #20;
  end
  endtask
endclass

//////////////////driver////////////////////////
class driver extends uvm_driver #(transactions);
  `uvm_component_utils(driver)
  
  transactions t;
  virtual Up_Dn_Counter_if DUTIF;
  
  //constructor
  function new(input string inst ="DRV",uvm_component c);
    super.new(inst,c);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    t =transactions::type_id::create("TRANS");
    if(!(uvm_config_db#(virtual Up_Dn_Counter_if)::get(this,"","DUTIF",DUTIF)))
      `uvm_fatal("DRV","Driver is unable to access interface")
  endfunction
    
      ///////////run phase////////////////
  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(t);
      DUTIF.IN = t.IN;
      DUTIF.Load = t.Load;
      DUTIF.UP = t.UP;
      DUTIF.DOWN = t.DOWN;
      `uvm_info("DRV","Data is send to the driver as following",UVM_NONE)
      t.print(uvm_default_line_printer);
      seq_item_port.item_done();
      @(posedge DUTIF.clk);
      @(negedge DUTIF.clk);
    end
  endtask
endclass
    //////////////////monitor////////////////////////
class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)
  
  uvm_analysis_port #(transactions) send;
  transactions t;
  virtual Up_Dn_Counter_if DUTIF;
  
  //constructor
  function new(input string inst ="MON",uvm_component c);
    super.new(inst,c);
    send =new("WRITE",this);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    t =transactions::type_id::create("TRANS");
    if(!(uvm_config_db#(virtual Up_Dn_Counter_if)::get(this,"","DUTIF",DUTIF)))
      `uvm_fatal("MON","Driver is unable to access interface")
  endfunction
      ///////////run phase////////////////
  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge DUTIF.clk);
      t.IN = DUTIF.IN;
      t.Load = DUTIF.Load;
      t.UP = DUTIF.UP;
      t.DOWN = DUTIF.DOWN;
      @(negedge DUTIF.clk);
      t.Counter = DUTIF.Counter;
      t.High = DUTIF.High;
      t.Low = DUTIF.Low;
      `uvm_info("MON","Data is received by monitor as following",UVM_NONE)
      t.print(uvm_default_line_printer);
      send.write(t);
    end
  endtask
endclass

    //////////////////scoreboard////////////////////////
class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)
  
  uvm_analysis_imp #(transactions,scoreboard) receive;
  
  int prev_count =0;
  
  //constructor
  function new(input string inst ="SCO",uvm_component c);
    super.new(inst,c);
    receive =new("READ",this);
  endfunction
  
  virtual function void write(input transactions data);
    `uvm_info("SCO","Data is received by scoreboard as following",UVM_NONE)
    data.print(uvm_default_line_printer);
      if(data.Load ==1) begin
        if(data.IN == data.Counter) begin
          `uvm_info("SCO","Test case Passed !",UVM_NONE)
        end
        else begin
          `uvm_error("SCO","Test Case Failed")
        end
        prev_count = data.Counter;
      end
      else if(!data.Load &&(data.DOWN)) begin
          if(data.Counter == 5'b0 &&(data.Low)) begin
            `uvm_info("SCO","Test case Passed !",UVM_NONE)
          end
          else if(data.Counter == 5'b0 &&!(data.Low)) begin
            `uvm_error("SCO","Test Case Failed, no low signal is generated")
          end
          else if (data.Counter == prev_count -1) begin
            `uvm_info("SCO","Test case Passed !",UVM_NONE)
          end
          else begin
            `uvm_error("SCO","Test Case Failed, the counter isn't counting down")
          end
           prev_count = data.Counter;
        end 
        else if(!data.Load&&(data.UP)) begin
          if(data.Counter == 5'b11111 &&(data.High)&&!(data.DOWN)) begin
            `uvm_info("SCO","Test case Passed !",UVM_NONE)
          end
          else if(data.Counter == 5'b11111 &&(!data.High)&&!(data.DOWN)) begin
            `uvm_error("SCO","Test Case Failed, no High signal is generated")
          end
          else if ((data.Counter == prev_count +1)&&!(data.DOWN)) begin
            `uvm_info("SCO","Test case Passed !",UVM_NONE)
          end
          else begin
            `uvm_error("SCO","Test Case Failed, the counter isn' counting  up")
          end
           prev_count = data.Counter;
        end
      else if(!data.Load &&!(data.UP || data.DOWN)) begin
      if (data.Counter == prev_count) begin
        `uvm_info("SCO","Test case Passed !",UVM_NONE)
      end
      else begin
        `uvm_error("SCO","Test Case Failed")
      end
    end
  endfunction
endclass
   ////////////////agent///////////////////////
class agent extends uvm_agent;
  `uvm_component_utils(agent)
  
  //constructor
  function new(input string inst ="AGENT",uvm_component c);
    super.new(inst,c);
  endfunction
  
  driver d;
  monitor m;
  uvm_sequencer #(transactions) seq;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    d = driver::type_id::create("DRV",this);
    m = monitor::type_id::create("MON",this);
    seq = uvm_sequencer #(transactions)::type_id::create("SEQ",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    d.seq_item_port.connect(seq.seq_item_export);
  endfunction
endclass
    
    /////////////////enviroment////////////////////
class env extends uvm_env;
  `uvm_component_utils(env)
  
  //constructor
  function new(input string inst ="ENV",uvm_component c);
    super.new(inst,c);
  endfunction
  
  agent a;
  scoreboard s;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a = agent::type_id::create("AGENT",this);
    s = scoreboard::type_id::create("SCO",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    a.m.send.connect(s.receive);
  endfunction
endclass
    
    /////////////////test//////////////////////////
class test extends uvm_test;
  `uvm_component_utils(test)
  
  function new(input string inst ="TEST",uvm_component c);
    super.new(inst,c);
  endfunction
  
  generator gen;
  env e;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    gen = generator::type_id::create("GEN",this);
    e = env::type_id::create("ENV",this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    gen.start(e.a.seq);
    `uvm_info("TEST",$sformatf("coverage is %.2f%%",gen.cg.get_coverage()),UVM_NONE);
    phase.drop_objection(this);
  endtask
endclass
    
module Up_Dn_Counter_tb();
  test t;
  Up_Dn_Counter_if DUTIF();
  
  Up_Dn_Counter DUT(.IN(DUTIF.IN),
                    .Load(DUTIF.Load),
                    .UP(DUTIF.UP),
                    .DOWN(DUTIF.DOWN),
                    .clk(DUTIF.clk),
                    .RST(DUTIF.RST),
                    .Counter(DUTIF.Counter),
                    .High(DUTIF.High),
                    .Low(DUTIF.Low));
  initial begin
    DUTIF.clk = 1'b0;
    DUTIF.RST = 1'b1;
  end
  
   always #10 DUTIF.clk =~DUTIF.clk;

  
  initial begin
    $dumpvars;
    t =new("TEST",null);
    uvm_config_db #(virtual Up_Dn_Counter_if)::set(null,"*","DUTIF",DUTIF);
    run_test();
  end
endmodule
      