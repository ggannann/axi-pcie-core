-------------------------------------------------------------------------------
-- File       : AppPgp2bLane.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-03-22
-- Last update: 2017-10-10
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'axi-pcie-core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'axi-pcie-core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPkg.all;
use work.AxiPciePkg.all;
use work.Pgp2bPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AppPgp2bLane is
   generic (
      TPD_G             : time             := 1 ns;
      PGP_RX_ENABLE_G   : boolean          := true;
      PGP_TX_ENABLE_G   : boolean          := true;
      AXIL_CLK_FREQ_C   : real             := 156.25e6;
      AXIL_BASE_ADDR_G  : slv(31 downto 0) := (others => '0');
      AXIL_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_DECERR_C);
   port (
      -- AXI-Lite Interface      
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- DMA Interface  (sysClk domain)
      dmaClk          : in  sl;
      dmaRst          : in  sl;
      dmaObMaster     : in  AxiStreamMasterType;
      dmaObSlave      : out AxiStreamSlaveType;
      dmaIbMaster     : out AxiStreamMasterType;
      dmaIbSlave      : in  AxiStreamSlaveType;
      -- PGP Interface
      gtRefClk        : in  sl;
      gtRxP           : in  sl;
      gtRxN           : in  sl;
      gtTxP           : out sl;
      gtTxN           : out sl);
end AppPgp2bLane;

architecture mapping of AppPgp2bLane is

   constant NUM_AXIL_MASTERS_C : integer := 2;
   constant PGP_AXIL_INDEX_C   : integer := 0;
   constant DRP_AXIL_INDEX_C   : integer := 1;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := (
      PGP_AXIL_INDEX_C => (
         baseAddr      => AXIL_BASE_ADDR_G,
         addrBits      => 8,
         connectivity  => X"FFFF"),
      DRP_AXIL_INDEX_C => (
         baseAddr      => AXIL_BASE_ADDR_G + X"800",
         addrBits      => 11,
         connectivity  => X"FFFF"));

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal dmaObMasters : AxiStreamMasterArray(3 downto 0);
   signal dmaObSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal dmaIbMasters : AxiStreamMasterArray(3 downto 0);
   signal dmaIbSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal pgpTxClk  : sl;
   signal pgpTxRst  : sl;
   signal pgpTxIn   : Pgp2bTxInType;
   signal pgpTxOut  : Pgp2bTxOutType;
   signal txMasters : AxiStreamMasterArray(3 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal pgpRxClk  : sl;
   signal pgpRxRst  : sl;
   signal pgpRxIn   : Pgp2bRxInType;
   signal pgpRxOut  : Pgp2bRxOutType;
   signal rxMasters : AxiStreamMasterArray(3 downto 0);
   signal rxCtrl    : AxiStreamCtrlArray(3 downto 0);


begin

   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_Rst : entity work.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => dmaClk,
         rstIn  => dmaRst,
         rstOut => dmaRstPipe);

   U_DeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         NUM_MASTERS_G => 4)
      port map (
         -- Clock and reset
         axisClk      => dmaClk,
         axisRst      => dmaRstPipe,
         -- Slave         
         sAxisMaster  => dmaObMaster,
         sAxisSlave   => dmaObSlave,
         -- Masters
         mAxisMasters => dmaObMasters,
         mAxisSlaves  => dmaObSlaves);

   U_Mux : entity work.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         NUM_SLAVES_G  => 4)
      port map (
         -- Clock and reset
         axisClk      => dmaClk,
         axisRst      => dmaRstPipe,
         -- Slave
         sAxisMasters => dmaIbMasters,
         sAxisSlaves  => dmaIbSlaves,
         -- Masters
         mAxisMaster  => dmaIbMaster,
         mAxisSlave   => dmaIbSlave);

   GEN_VEC : for i in 3 downto 0 generate

      U_TxFifo : entity work.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 1,
            INT_WIDTH_SELECT_G  => "NARROW",
            -- FIFO configurations
            BRAM_EN_G           => true,
            GEN_SYNC_FIFO_G     => false,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 10,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => dmaClk,
            sAxisRst    => dmaRstPipe,
            sAxisMaster => dmaObMasters(i),
            sAxisSlave  => dmaObSlaves(i),
            -- Master Port
            mAxisClk    => pgpTxClk,
            mAxisRst    => pgpTxRst,
            mAxisMaster => txMasters(i),
            mAxisSlave  => txSlaves(i));

      U_RxFifo : entity work.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => false,
            VALID_THOLD_G       => 1,
            INT_WIDTH_SELECT_G  => "NARROW",
            -- FIFO configurations
            BRAM_EN_G           => true,
            GEN_SYNC_FIFO_G     => false,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 10,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 128,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
            MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => pgpRxClk,
            sAxisRst    => pgpRxRst,
            sAxisMaster => rxMasters(i),
            sAxisCtrl   => rxCtrl(i),
            -- Master Port
            mAxisClk    => dmaClk,
            mAxisRst    => dmaRstPipe,
            mAxisMaster => dmaIbMasters(i),
            mAxisSlave  => dmaIbSlaves(i));

   end generate;



   U_PGP : entity work.Pgp2bGthUltra
      generic map (
         TPD_G             => TPD_G,
         PGP_RX_ENABLE_G   => PGP_RX_ENABLE_G,
         PGP_TX_ENABLE_G   => PGP_TX_ENABLE_G,
         PAYLOAD_CNT_TOP_G => 7,
         VC_INTERLEAVE_G   => 0,
         NUM_VC_EN_G       => 4)
      port map (
         stableClk       => stableClk,
         stableRst       => stableRst,
         gtRefClk        => gtRefClk,
         pgpGtTxP        => gtTxP,
         pgpGtTxN        => gtTxN,
         pgpGtRxP        => gtRxP,
         pgpGtRxN        => gtRxN,
         pgpTxReset      => pgpTxRst,
         pgpTxClk        => pgpTxClk,
         pgpRxReset      => pgpRxRst,
         pgpRxClk        => pgpRxClk,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         pgpTxMasters    => txMasters,
         pgpTxSlaves     => txSlaves,
         pgpRxMasters    => rxMasters,
         pgpRxCtrl       => rxCtrl,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(DRP_AXIL_INDEX_C),
         axilReadSlave   => axilReadSlaves(DRP_AXIL_INDEX_C),
         axilWriteMaster => axilWriteMasters(DRP_AXIL_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(DRP_AXIL_INDEX_C));

   );

   U_MON : entity work.Pgp2bAxi
      generic map (
         TPD_G              => TPD_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         COMMON_TX_CLK_G    => false,
         COMMON_RX_CLK_G    => false,
         WRITE_EN_G         => true,
         AXI_CLK_FREQ_G     => AXIL_CLK_FREQ_G,
         STATUS_CNT_WIDTH_G => 32,
         ERROR_CNT_WIDTH_G  => 16)
      port map (
         -- TX PGP Interface 
         pgpTxClk        => pgpTxClk,
         pgpTxClkRst     => pgpTxRst
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         -- RX PGP Interface 
         pgpRxClk        => pgpRxClk,
         pgpRxClkRst     => pgpRxRst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         -- AXI-Lite Register Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(PGP_AXIL_INDEX_C),
         axilReadSlave   => axilReadSlaves(PGP_AXIL_INDEX_C),
         axilWriteMaster => axilWriteMasters(PGP_AXIL_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(PGP_AXIL_INDEX_C));

end mapping;