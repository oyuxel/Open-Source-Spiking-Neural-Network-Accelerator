library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Pipeline_Adder is
    generic (
        N : integer := 8 
    );
    port (
        CLK    : in  std_logic;
        RST    : in  std_logic;
        INPUT  : in  std_logic_vector(16*N-1 downto 0); 
        OUTPUT : out std_logic_vector(15 downto 0)
    );
end entity Pipeline_Adder;

architecture constant_craving of Pipeline_Adder is

    type integer_array is array (natural range <>) of integer;

    function log2(n : integer) return integer is
        variable result : integer := 0;
        variable value : integer := n;
    begin
        while value > 1 loop
            value := value / 2;
            result := result + 1;
        end loop;
        return result;
    end function;

    function Generate_Stages(N: integer) return integer_array is
        variable stages_count : integer := log2(N) + 1;  
        variable result : integer_array(0 to stages_count - 1); 
        variable current_value : integer := N;
    begin
        for i in 0 to stages_count - 1 loop
            result(i) := current_value;
            current_value := current_value / 2;
        end loop;
        return result;
    end function Generate_Stages;

    constant STAGES : integer_array := Generate_Stages(N);

    type PSTAGES is array (0 to N-1,0 to N-1) of signed(15 downto 0);
    signal PPSTAGES : PSTAGES;

    begin

        INPUT_STAGE : for i in 0 to STAGES(0)-1 generate
    
                    PPSTAGES(0,i) <= signed(INPUT((i+1)*16-1 downto 16*i));
    
        end generate INPUT_STAGE;

        PIPELINE_STAGES : for k in 0 to STAGES'length-1 generate
    
            FIRST_STAGE_0 : if k=0 and STAGES(0) mod 2 = 0 generate
    
                GEN_LAYERS : for m in 0 to STAGES(0)/2-1 generate
    
                    PP_STGS : process(CLK)
                     
                        begin
                                
                            if(rising_edge(CLK)) then
                            
                                if(RST = '1') then
                                                                        
                                    PPSTAGES(1,m)  <= (others=>'0');
                                
                                else
                                                                                                               
                                    PPSTAGES(1,m) <= PPSTAGES(0,2*m+1)+PPSTAGES(0,2*m);
                                                                         
                                end if;
                            
                            end if;
                     
                        end process PP_STGS;
                        
                  end generate GEN_LAYERS;
                     
                end generate FIRST_STAGE_0;

            FIRST_STAGE_1 : if k=0 and STAGES(0) mod 2 = 1 generate
                
                GEN_LAYERS : for m in 0 to STAGES(0)/2-1 generate
                
                    DOUBLE_SUM : if m< STAGES(0)/2-1 generate
    
                        PP_STGS : process(CLK)
                                    
                            begin

                                if(rising_edge(CLK)) then
                                
                                    if(RST = '1') then

                                        PPSTAGES(1,m)  <= (others=>'0');
                                    
                                    else

                                        PPSTAGES(1,m) <= PPSTAGES(0,2*m+1)+PPSTAGES(0,2*m);

                                    end if;
                                    
                                end if;
                                    
                            end process PP_STGS;
                                    
                        end generate DOUBLE_SUM;

                    TRIPLE_SUM : if m= STAGES(0)/2-1 generate
    
                        PP_STGS : process(CLK)
                                    
                            begin
                                    
                                if(rising_edge(CLK)) then
                                
                                    if(RST = '1') then
                                                                            
                                        PPSTAGES(1,(STAGES(0)/2-1))  <= (others=>'0');
                                    
                                    else
                                                                                                                   
                                        PPSTAGES(1,m) <= PPSTAGES(0,2*m+2)+PPSTAGES(0,2*m+1)+PPSTAGES(0,2*m);
                                                                             
                                    end if;
                                    
                                end if;
                                    
                            end process PP_STGS;
                                    
                        end generate TRIPLE_SUM;
                        
                  end generate GEN_LAYERS;
                                       
                end generate FIRST_STAGE_1;
                
        
            NEXT_STAGES_0 : if k>0 and k < STAGES'length-1 and STAGES(k) mod 2 = 0 generate
    
               GEN_LAYERS : for m in 0 to STAGES(k)/2-1 generate

                    PP_STGS : process(CLK)
                     
                        begin
                                
                            if(rising_edge(CLK)) then
                            
                                if(RST = '1') then
                                                                        
                                    PPSTAGES(k+1,m)  <= (others=>'0');
                                
                                else
                                                                                                               
                                    PPSTAGES(k+1,m) <= PPSTAGES(k,2*m+1)+PPSTAGES(k,2*m);
                                                                         
                                end if;
                            
                            end if;
                     
                        end process PP_STGS;
                        
                     end generate GEN_LAYERS;
                     
                end generate NEXT_STAGES_0;
                
         
            NEXT_STAGES_1 : if k>0 and k < STAGES'length-1 and STAGES(k) mod 2 = 1 generate
    
                GEN_LAYERS : for m in 0 to STAGES(k)/2-1 generate
                
                    DOUBLE_SUM : if m< STAGES(k)/2-1 generate
    
                        PP_STGS : process(CLK)
                                    
                            begin

                                if(rising_edge(CLK)) then
                                
                                    if(RST = '1') then

                                        PPSTAGES(k+1,m)  <= (others=>'0');
                                    
                                    else

                                        PPSTAGES(k+1,m) <= PPSTAGES(k,2*m+1)+PPSTAGES(k,2*m);

                                    end if;
                                    
                                end if;
                                    
                            end process PP_STGS;
                                    
                        end generate DOUBLE_SUM;
                        
                     TRIPLE_SUM : if m= STAGES(k)/2-1 generate
    
                        PP_STGS : process(CLK)
                                    
                            begin
                                    
                                if(rising_edge(CLK)) then
                                
                                    if(RST = '1') then
                                                                            
                                        PPSTAGES(k+1,(STAGES(0)/2-1))  <= (others=>'0');
                                    
                                    else
                                                                                                                   
                                        PPSTAGES(k+1,m) <= PPSTAGES(k,2*m+2)+PPSTAGES(k,2*m+1)+PPSTAGES(k,2*m);
                                                                             
                                    end if;
                                    
                                end if;
                                    
                            end process PP_STGS;
                                    
                        end generate TRIPLE_SUM;
                        
                     end generate GEN_LAYERS;
                     
                end generate NEXT_STAGES_1;               

            LAST_STAGE : if k = STAGES'length-1 generate
       
                OUTPUT <= std_logic_vector(PPSTAGES(STAGES'length-1,0));
                      
            end generate LAST_STAGE;
     
        end generate PIPELINE_STAGES;
    
end architecture constant_craving;