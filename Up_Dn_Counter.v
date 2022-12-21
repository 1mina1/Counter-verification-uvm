module Up_Dn_Counter ( 
  input   wire  [4:0]     IN,
  input   wire            Load, UP, DOWN,
  input   wire            clk,
  input   wire            RST,
  output  reg   [4:0]     Counter,
  output  wire            High, Low 
  );
  
  
// Internal Signals
  reg [4:0]   Counter_comb ;
  
  
  
// Assign Counter Comb logic to Counter register  
  always @ (posedge clk or negedge RST)
    begin
      if(!RST)
        begin
          Counter <= 5'b0;
        end
      else begin
        Counter <= Counter_comb ;  
      end
    end
  
// Counter behaviour function   
  always @ (*)
   begin
     if (Load)
       begin
         Counter_comb = IN ;
       end
     else if (DOWN && !Low)
       begin
         Counter_comb = Counter - 5'b1;
       end
     else if (UP && High && !DOWN)
       begin
         Counter_comb = Counter + 5'b1;
       end
     else 
       begin
         Counter_comb = Counter ;          // to avoid latch
       end
   end
  
// Down flag
  assign Low = (Counter == 5'b0);
  
// Up flag
  assign High = (Counter == 5'b11111);
  
  initial begin
    Counter =5'b0;
  end
endmodule

