-------------------------------------------------------------------------------
-- File       : AxiPciePgpCardG3Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-03-06
-- Last update: 2018-02-12
-------------------------------------------------------------------------------
-- Description: AXI PCIe Core for the PgpCardG3 board
-- https://confluence.slac.stanford.edu/display/AIRTRACK/PC_260_101_03_C03
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
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiPciePgpCardG3Core is
   generic (
      TPD_G             : time                   := 1 ns;
      BUILD_INFO_G      : BuildInfoType;
      DRIVER_TYPE_ID_G  : slv(31 downto 0)       := x"00000000";
      DMA_SIZE_G        : positive range 1 to 16 := 1;
      INT_PIPE_STAGES_G : natural range 0 to 1   := 0;
      PIPE_STAGES_G     : natural range 0 to 1   := 0);
   port (
      ------------------------      
      --  Top Level Interfaces
      ------------------------    
      -- System Clock and Reset
      sysClk         : out   sl;        -- 125 MHz
      sysRst         : out   sl;
      -- DMA Interfaces (sysClk domain)
      dmaObMasters   : out   AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves    : in    AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaIbMasters   : in    AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves    : out   AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- Application AXI-Lite Interfaces [0x00800000:0x00FFFFFF] (appClk domain)
      appClk         : in    sl;
      appRst         : in    sl;
      appReadMaster  : out   AxiLiteReadMasterType;
      appReadSlave   : in    AxiLiteReadSlaveType;
      appWriteMaster : out   AxiLiteWriteMasterType;
      appWriteSlave  : in    AxiLiteWriteSlaveType;
      -------------------
      --  Top Level Ports
      -------------------
      -- Boot Memory Ports 
      flashAddr      : out   slv(28 downto 0);
      flashData      : inout slv(15 downto 0);
      flashAdv       : out   sl;
      flashClk       : out   sl;
      flashRstL      : out   sl;
      flashCeL       : out   sl;
      flashOeL       : out   sl;
      flashWeL       : out   sl;
      -- PCIe Ports 
      pciRstL        : in    sl;
      pciRefClkP     : in    sl;
      pciRefClkN     : in    sl;
      pciRxP         : in    slv(3 downto 0);
      pciRxN         : in    slv(3 downto 0);
      pciTxP         : out   slv(3 downto 0);
      pciTxN         : out   slv(3 downto 0));
end AxiPciePgpCardG3Core;

architecture mapping of AxiPciePgpCardG3Core is

   signal dmaReadMaster  : AxiReadMasterType;
   signal dmaReadSlave   : AxiReadSlaveType;
   signal dmaWriteMaster : AxiWriteMasterType;
   signal dmaWriteSlave  : AxiWriteSlaveType;

   signal regReadMaster  : AxiReadMasterType;
   signal regReadSlave   : AxiReadSlaveType;
   signal regWriteMaster : AxiWriteMasterType;
   signal regWriteSlave  : AxiWriteSlaveType;

   signal dmaCtrlReadMasters  : AxiLiteReadMasterArray(2 downto 0);
   signal dmaCtrlReadSlaves   : AxiLiteReadSlaveArray(2 downto 0);
   signal dmaCtrlWriteMasters : AxiLiteWriteMasterArray(2 downto 0);
   signal dmaCtrlWriteSlaves  : AxiLiteWriteSlaveArray(2 downto 0);

   signal phyReadMaster  : AxiLiteReadMasterType;
   signal phyReadSlave   : AxiLiteReadSlaveType;
   signal phyWriteMaster : AxiLiteWriteMasterType;
   signal phyWriteSlave  : AxiLiteWriteSlaveType;

   signal flashDin  : slv(15 downto 0);
   signal flashDout : slv(15 downto 0);
   signal flashTri  : sl;

   signal sysClock    : sl;
   signal sysReset    : sl;
   signal systemReset : sl;
   signal cardReset   : sl;
   signal dmaIrq      : sl;

begin

   sysClk <= sysClock;

   systemReset <= sysReset or cardReset;

   U_Rst : entity work.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => sysClock,
         rstIn  => systemReset,
         rstOut => sysRst);

   ---------------
   -- AXI PCIe PHY
   ---------------   
   U_AxiPciePhy : entity work.AxiPgpCardG3PciePhyWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- AXI4 Interfaces
         axiClk         => sysClock,
         axiRst         => sysReset,
         dmaReadMaster  => dmaReadMaster,
         dmaReadSlave   => dmaReadSlave,
         dmaWriteMaster => dmaWriteMaster,
         dmaWriteSlave  => dmaWriteSlave,
         regReadMaster  => regReadMaster,
         regReadSlave   => regReadSlave,
         regWriteMaster => regWriteMaster,
         regWriteSlave  => regWriteSlave,
         phyReadMaster  => phyReadMaster,
         phyReadSlave   => phyReadSlave,
         phyWriteMaster => phyWriteMaster,
         phyWriteSlave  => phyWriteSlave,
         -- Interrupt Interface
         dmaIrq         => dmaIrq,
         -- PCIe Ports 
         pciRstL        => pciRstL,
         pciRefClkP     => pciRefClkP,
         pciRefClkN     => pciRefClkN,
         pciRxP         => pciRxP,
         pciRxN         => pciRxN,
         pciTxP         => pciTxP,
         pciTxN         => pciTxN);

   ---------------
   -- AXI PCIe REG
   --------------- 
   U_REG : entity work.AxiPcieReg
      generic map (
         TPD_G            => TPD_G,
         BUILD_INFO_G     => BUILD_INFO_G,
         XIL_DEVICE_G     => "7SERIES",
         BOOT_PROM_G      => "BPI",
         DRIVER_TYPE_ID_G => DRIVER_TYPE_ID_G,
         DMA_SIZE_G       => DMA_SIZE_G)
      port map (
         -- AXI4 Interfaces
         axiClk              => sysClock,
         axiRst              => sysReset,
         regReadMaster       => regReadMaster,
         regReadSlave        => regReadSlave,
         regWriteMaster      => regWriteMaster,
         regWriteSlave       => regWriteSlave,
         -- DMA AXI-Lite Interfaces
         dmaCtrlReadMasters  => dmaCtrlReadMasters,
         dmaCtrlReadSlaves   => dmaCtrlReadSlaves,
         dmaCtrlWriteMasters => dmaCtrlWriteMasters,
         dmaCtrlWriteSlaves  => dmaCtrlWriteSlaves,
         -- PHY AXI-Lite Interfaces
         phyReadMaster       => phyReadMaster,
         phyReadSlave        => phyReadSlave,
         phyWriteMaster      => phyWriteMaster,
         phyWriteSlave       => phyWriteSlave,
         -- (Optional) Application AXI-Lite Interfaces      
         appClk              => appClk,
         appRst              => appRst,
         appReadMaster       => appReadMaster,
         appReadSlave        => appReadSlave,
         appWriteMaster      => appWriteMaster,
         appWriteSlave       => appWriteSlave,
         -- Application Force reset
         cardResetOut        => cardReset,
         cardResetIn         => systemReset,
         -- Boot Memory Ports 
         bpiAddr             => flashAddr,
         bpiAdv              => flashAdv,
         bpiClk              => flashClk,
         bpiRstL             => flashRstL,
         bpiCeL              => flashCeL,
         bpiOeL              => flashOeL,
         bpiWeL              => flashWeL,
         bpiDin              => flashDin,
         bpiDout             => flashDout,
         bpiTri              => flashTri);

   GEN_IOBUF :
   for i in 15 downto 0 generate
      IOBUF_inst : IOBUF
         port map (
            O  => flashDout(i),         -- Buffer output
            IO => flashData(i),  -- Buffer inout port (connect directly to top-level port)
            I  => flashDin(i),          -- Buffer input
            T  => flashTri);  -- 3-state enable input, high=input, low=output     
   end generate GEN_IOBUF;

   ---------------
   -- AXI PCIe DMA
   ---------------   
   U_AxiPcieDma : entity work.AxiPcieDma
      generic map (
         TPD_G             => TPD_G,
         DMA_SIZE_G        => DMA_SIZE_G,
         INT_PIPE_STAGES_G => INT_PIPE_STAGES_G,
         PIPE_STAGES_G     => PIPE_STAGES_G)
      port map (
         -- Clock and reset
         axiClk           => sysClock,
         axiRst           => sysReset,
         -- AXI4 Interfaces
         axiReadMaster    => dmaReadMaster,
         axiReadSlave     => dmaReadSlave,
         axiWriteMaster   => dmaWriteMaster,
         axiWriteSlave    => dmaWriteSlave,
         -- AXI4-Lite Interfaces
         axilReadMasters  => dmaCtrlReadMasters,
         axilReadSlaves   => dmaCtrlReadSlaves,
         axilWriteMasters => dmaCtrlWriteMasters,
         axilWriteSlaves  => dmaCtrlWriteSlaves,
         -- Interrupts
         dmaIrq           => dmaIrq,
         -- DMA Interfaces
         dmaObMasters     => dmaObMasters,
         dmaObSlaves      => dmaObSlaves,
         dmaIbMasters     => dmaIbMasters,
         dmaIbSlaves      => dmaIbSlaves);

end mapping;
