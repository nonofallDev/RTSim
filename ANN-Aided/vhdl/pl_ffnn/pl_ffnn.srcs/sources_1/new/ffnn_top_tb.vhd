-- ffnn_top_tb_advanced.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity ffnn_top_tb is
end ffnn_top_tb;

architecture Behavioral of ffnn_top_tb is
    
    constant CLK_PERIOD : time := 5 ns;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal gate_signal : std_logic := '0';
    signal temp : signed(31 downto 0);
    signal vce_steady : signed(31 downto 0);
    signal ic_steady : signed(31 downto 0);
    signal ic_transient : signed(31 downto 0);
    signal vce_transient : signed(31 downto 0);
    signal transient_valid : std_logic;
    
    -- Fichiers
    file input_file : text;
    file output_file : text;
    
begin

    DUT: entity work.ffnn_top
        port map (
            clk_200mhz => clk,
            rst => rst,
            temp => temp,
            vce_steady => vce_steady,
            ic_steady => ic_steady,
            gate_signal => gate_signal,
            ic_transient => ic_transient,
            vce_transient => vce_transient,
            transient_valid => transient_valid
        );
    
    clk <= not clk after CLK_PERIOD/2;
    
    -- Lecture des vecteurs de test
    process
        variable input_line : line;
        variable output_line : line;
        variable time_val : integer;
        variable gate_val : integer;
        variable temp_val : integer;
        variable vce_val : integer;
        variable ic_val : integer;
        variable comment_char : character;
    begin
        file_open(input_file, "test_vectors.txt", read_mode);
        file_open(output_file, "simulation_results.txt", write_mode);
        
        -- Header
        write(output_line, string'("-- Résultats de simulation FPGA"));
        writeline(output_file, output_line);
        write(output_line, string'("-- Format: Temps(ns) | Ic | Vce | Valid"));
        writeline(output_file, output_line);
        
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        
        while not endfile(input_file) loop
            readline(input_file, input_line);
            
            -- Ignorer les commentaires
            if input_line'length > 0 then
                read(input_line, comment_char);
                if comment_char /= '-' then
                    -- Lire les valeurs
                    -- Format: temps gate temp vce ic
                    -- Repositionner
                    readline(input_file, input_line);
                    read(input_line, time_val);
                    read(input_line, gate_val);
                    read(input_line, temp_val);
                    read(input_line, vce_val);
                    read(input_line, ic_val);
                    
                    -- Appliquer les stimuli
                    if gate_val = 1 then
                        gate_signal <= '1';
                    else
                        gate_signal <= '0';
                    end if;
                    
                    temp <= to_signed(temp_val, 32);
                    vce_steady <= to_signed(vce_val, 32);
                    ic_steady <= to_signed(ic_val, 32);
                    
                    wait for CLK_PERIOD;
                    
                    -- Enregistrer les résultats
                    write(output_line, time_val);
                    write(output_line, string'(" "));
                    write(output_line, to_integer(ic_transient));
                    write(output_line, string'(" "));
                    write(output_line, to_integer(vce_transient));
                    write(output_line, string'(" "));
                    if transient_valid = '1' then
                        write(output_line, string'("1"));
                    else
                        write(output_line, string'("0"));
                    end if;
                    writeline(output_file, output_line);
                end if;
            end if;
        end loop;
        
        file_close(input_file);
        file_close(output_file);
        
        report "Simulation terminée - Résultats dans simulation_results.txt" severity note;
        std.env.finish;
    end process;

end Behavioral;