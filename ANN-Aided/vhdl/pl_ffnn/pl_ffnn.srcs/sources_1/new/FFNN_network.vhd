----------------------------------------------------------------------------------
-- Module FFNN Network - Version corrigée
-- Implémente un réseau feedforward avec pipeline
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FFNN_network is
    generic (
        DATA_WIDTH : integer := 32;
        FRAC_WIDTH : integer := 30
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- Inputs normalisés
        x1_norm : in signed(DATA_WIDTH-1 downto 0);
        x2_norm : in signed(DATA_WIDTH-1 downto 0);
        x3_norm : in signed(DATA_WIDTH-1 downto 0);
        
        -- Contrôle
        time_idx : in unsigned(9 downto 0);
        state : in std_logic;  -- 0=turn-on, 1=turn-off
        start : in std_logic;
        
        -- Interface BRAM pour chargement des poids
        bram_addr : out std_logic_vector(14 downto 0);
        bram_data : in std_logic_vector(31 downto 0);
        bram_read_enable : out std_logic;
        
        -- Outputs
        y1_norm : out signed(DATA_WIDTH-1 downto 0);
        y2_norm : out signed(DATA_WIDTH-1 downto 0);
        valid : out std_logic
    );
end FFNN_network;

architecture Behavioral of FFNN_network is

    constant HIDDEN_NEURONS : integer := 5;
    constant INPUT_NEURONS : integer := 3;
    constant OUTPUT_NEURONS : integer := 2;
    constant COEFF_PER_FFNN : integer := 32;  -- 15(wh) + 5(bh) + 10(wo) + 2(bo)

    -- Types pour les poids et biais
    type weight_matrix_h is array (0 to HIDDEN_NEURONS-1, 0 to INPUT_NEURONS-1) 
         of signed(DATA_WIDTH-1 downto 0);
    type bias_vector_h is array (0 to HIDDEN_NEURONS-1) 
         of signed(DATA_WIDTH-1 downto 0);
    type weight_matrix_o is array (0 to OUTPUT_NEURONS-1, 0 to HIDDEN_NEURONS-1) 
         of signed(DATA_WIDTH-1 downto 0);
    type bias_vector_o is array (0 to OUTPUT_NEURONS-1) 
         of signed(DATA_WIDTH-1 downto 0);
    
    signal wh : weight_matrix_h;
    signal bh : bias_vector_h;
    signal wo : weight_matrix_o;
    signal bo : bias_vector_o;
    
    type hidden_layer_array is array (0 to HIDDEN_NEURONS-1) 
         of signed(DATA_WIDTH-1 downto 0);
    signal hidden_sum : hidden_layer_array;
    signal hidden_act : hidden_layer_array;
    
    type output_layer_array is array (0 to OUTPUT_NEURONS-1) 
         of signed(DATA_WIDTH-1 downto 0);
    signal output_sum : output_layer_array;
    
    -- Machine à états pour le pipeline
    type state_type is (
        IDLE,
        LOAD_WEIGHTS,
        COMPUTE_HIDDEN,
        COMPUTE_TANH,
        COMPUTE_OUTPUT,
        OUTPUT_VALID
    );
    signal current_state : state_type := IDLE;
    signal next_state : state_type;
    
    -- Compteurs
    signal load_counter : unsigned(5 downto 0) := (others => '0');
    signal compute_counter : unsigned(3 downto 0) := (others => '0');
    
    -- Signaux de contrôle BRAM
    signal bram_base_addr : unsigned(14 downto 0);
    signal bram_offset : unsigned(5 downto 0);
    
    -- LUT tanh
    type tanh_lut_type is array (0 to 255) of signed(DATA_WIDTH-1 downto 0);
    
    function init_tanh_lut return tanh_lut_type is
        variable lut : tanh_lut_type;
    begin
        -- Initialisation simplifiée (à compléter avec MATLAB)
        for i in 0 to 127 loop
            -- Zone négative: approximation linéaire
            lut(i) := to_signed(-1073741824 + i * 16777216, DATA_WIDTH);
        end loop;
        
        lut(128) := to_signed(0, DATA_WIDTH);  -- tanh(0) = 0
        
        for i in 129 to 255 loop
            -- Zone positive
            lut(i) := to_signed(-1073741824 + i * 16777216, DATA_WIDTH);
        end loop;
        
        return lut;
    end function;
    
    constant TANH_LUT : tanh_lut_type := init_tanh_lut;
    
    function tanh_lookup(x : signed) return signed is
        variable lut_index : integer range 0 to 255;
        variable x_shifted : signed(DATA_WIDTH-1 downto 0);
    begin
        -- Mapper [-4, 4] vers [0, 255]
        -- x en Q1.30: -4.0 = -4*2^30, 4.0 = 4*2^30
        x_shifted := x + to_signed(1073741824, DATA_WIDTH);  -- Décalage de 1.0
        
        -- Extraire l'index (bits 30 à 23 pour avoir 8 bits)
        lut_index := to_integer(shift_right(x_shifted, 22)(7 downto 0));
        
        if lut_index > 255 then
            lut_index := 255;
        elsif lut_index < 0 then
            lut_index := 0;
        end if;
        
        return TANH_LUT(lut_index);
    end function;

begin

    -- =========================================================================
    -- Calcul de l'adresse de base BRAM selon time_idx et state
    -- =========================================================================
    process(time_idx, state)
    begin
        if state = '0' then
            -- Turn-on: FFNN 0 à 149
            bram_base_addr <= to_unsigned(to_integer(time_idx) * COEFF_PER_FFNN, 15);
        else
            -- Turn-off: FFNN 150 à 649
            bram_base_addr <= to_unsigned((150 + to_integer(time_idx)) * COEFF_PER_FFNN, 15);
        end if;
    end process;
    
    -- Adresse BRAM = base + offset
    bram_addr <= std_logic_vector(bram_base_addr + bram_offset);

    -- =========================================================================
    -- Machine à états principale
    -- =========================================================================
    
    -- Logique de transition
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= IDLE;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;
    
    -- Logique combinatoire de l'état suivant
    process(current_state, start, load_counter, compute_counter)
    begin
        next_state <= current_state;
        
        case current_state is
            when IDLE =>
                if start = '1' then
                    next_state <= LOAD_WEIGHTS;
                end if;
            
            when LOAD_WEIGHTS =>
                if load_counter >= COEFF_PER_FFNN - 1 then
                    next_state <= COMPUTE_HIDDEN;
                end if;
            
            when COMPUTE_HIDDEN =>
                -- 1 cycle pour calculer tous les neurones cachés
                next_state <= COMPUTE_TANH;
            
            when COMPUTE_TANH =>
                -- 1 cycle pour l'activation
                next_state <= COMPUTE_OUTPUT;
            
            when COMPUTE_OUTPUT =>
                -- 1 cycle pour la couche de sortie
                next_state <= OUTPUT_VALID;
            
            when OUTPUT_VALID =>
                -- Maintenir valid pendant 1 cycle
                next_state <= IDLE;
                
            when others =>
                next_state <= IDLE;
        end case;
    end process;
    
    -- =========================================================================
    -- Logique de sortie et calcul
    -- =========================================================================
    process(clk)
        variable temp_product : signed(2*DATA_WIDTH-1 downto 0);
        variable temp_sum : signed(DATA_WIDTH+3 downto 0);
        variable coeff_idx : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                load_counter <= (others => '0');
                compute_counter <= (others => '0');
                bram_offset <= (others => '0');
                bram_read_enable <= '0';
                valid <= '0';
                y1_norm <= (others => '0');
                y2_norm <= (others => '0');
                
                -- Réinitialiser les poids
                for i in 0 to HIDDEN_NEURONS-1 loop
                    for j in 0 to INPUT_NEURONS-1 loop
                        wh(i, j) <= (others => '0');
                    end loop;
                    bh(i) <= (others => '0');
                end loop;
                
                for i in 0 to OUTPUT_NEURONS-1 loop
                    for j in 0 to HIDDEN_NEURONS-1 loop
                        wo(i, j) <= (others => '0');
                    end loop;
                    bo(i) <= (others => '0');
                end loop;
                
            else
                case current_state is
                    
                    -- =================================================
                    -- IDLE: Attente du signal start
                    -- =================================================
                    when IDLE =>
                        load_counter <= (others => '0');
                        bram_offset <= (others => '0');
                        bram_read_enable <= '0';
                        valid <= '0';
                    
                    -- =================================================
                    -- LOAD_WEIGHTS: Chargement des 32 coefficients
                    -- =================================================
                    when LOAD_WEIGHTS =>
                        bram_read_enable <= '1';
                        bram_offset <= load_counter;
                        
                        -- Charger le coefficient depuis BRAM
                        -- Organisation: wh(15) | bh(5) | wo(10) | bo(2)
                        coeff_idx := to_integer(load_counter);
                        
                        if coeff_idx < 15 then
                            -- wh: indices 0-14
                            wh(coeff_idx / INPUT_NEURONS, coeff_idx mod INPUT_NEURONS) 
                                <= signed(bram_data);
                        elsif coeff_idx < 20 then
                            -- bh: indices 15-19
                            bh(coeff_idx - 15) <= signed(bram_data);
                        elsif coeff_idx < 30 then
                            -- wo: indices 20-29
                            wo((coeff_idx - 20) / HIDDEN_NEURONS, (coeff_idx - 20) mod HIDDEN_NEURONS)
                                <= signed(bram_data);
                        else
                            -- bo: indices 30-31
                            bo(coeff_idx - 30) <= signed(bram_data);
                        end if;
                        
                        if load_counter < COEFF_PER_FFNN - 1 then
                            load_counter <= load_counter + 1;
                        else
                            load_counter <= (others => '0');
                            bram_read_enable <= '0';
                        end if;
                    
                    -- =================================================
                    -- COMPUTE_HIDDEN: Calcul de la couche cachée
                    -- =================================================
                    when COMPUTE_HIDDEN =>
                        for i in 0 to HIDDEN_NEURONS-1 loop
                            temp_sum := resize(bh(i), temp_sum'length);
                            
                            -- w[i,0] * x1
                            temp_product := wh(i, 0) * x1_norm;
                            temp_sum := temp_sum + resize(
                                shift_right(temp_product, FRAC_WIDTH), 
                                temp_sum'length
                            );
                            
                            -- w[i,1] * x2
                            temp_product := wh(i, 1) * x2_norm;
                            temp_sum := temp_sum + resize(
                                shift_right(temp_product, FRAC_WIDTH), 
                                temp_sum'length
                            );
                            
                            -- w[i,2] * x3
                            temp_product := wh(i, 2) * x3_norm;
                            temp_sum := temp_sum + resize(
                                shift_right(temp_product, FRAC_WIDTH), 
                                temp_sum'length
                            );
                            
                            hidden_sum(i) <= resize(temp_sum, DATA_WIDTH);
                        end loop;
                    
                    -- =================================================
                    -- COMPUTE_TANH: Activation tanh
                    -- =================================================
                    when COMPUTE_TANH =>
                        for i in 0 to HIDDEN_NEURONS-1 loop
                            hidden_act(i) <= tanh_lookup(hidden_sum(i));
                        end loop;
                    
                    -- =================================================
                    -- COMPUTE_OUTPUT: Calcul de la couche de sortie
                    -- =================================================
                    when COMPUTE_OUTPUT =>
                        for i in 0 to OUTPUT_NEURONS-1 loop
                            temp_sum := resize(bo(i), temp_sum'length);
                            
                            for j in 0 to HIDDEN_NEURONS-1 loop
                                temp_product := wo(i, j) * hidden_act(j);
                                temp_sum := temp_sum + resize(
                                    shift_right(temp_product, FRAC_WIDTH), 
                                    temp_sum'length
                                );
                            end loop;
                            
                            output_sum(i) <= resize(temp_sum, DATA_WIDTH);
                        end loop;
                    
                    -- =================================================
                    -- OUTPUT_VALID: Sortie des résultats
                    -- =================================================
                    when OUTPUT_VALID =>
                        y1_norm <= output_sum(0);
                        y2_norm <= output_sum(1);
                        valid <= '1';
                    
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

end Behavioral;