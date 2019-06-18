#!/usr/bin/env python
#-----------------------------------------------------------------------------
# This file is part of the 'axi-pcie-core'. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the 'axi-pcie-core', including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue              as pr
        
class AxiPipCore(pr.Device):
    def __init__(self,       
                 numLane     = 1,
                 description = 'Container for the PIP core registers',
                 **kwargs):
        super().__init__(description=description, **kwargs)

        for i in range(numLane):
            self.add(pr.RemoteVariable(
                name         = 'REMOTE_BAR0_BASE_ADDRESS',
                offset       = 8*i,
                bitSize      = 64,
                mode         = 'RW',
            )) 
            
        self.add(pr.RemoteVariable(
            name         = 'EnableTx',
            offset       = 0x80,
            bitSize      = numLane,
            mode         = 'RW',
        ))  

        self.add(pr.RemoteVariable(
            name         = 'NUM_AXIS_G',
            offset       = 0xFC,
            bitSize      = 5,
            mode         = 'RW',
        ))
        