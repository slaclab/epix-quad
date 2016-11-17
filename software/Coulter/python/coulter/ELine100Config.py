
import pyrogue as pr


class ELine100Config(pr.Device):

    def __init__(self, name, memBase, offset, hidden):

        super(pr.Device, self).__init__(name, "ELine 100 ASIC Configuration",
                                             0x100, memBase, offset, hidden)

        for i in xrange(96):
            self.add(pr.Variable(name= "Ch" + i + "_somi"
                                 description = "Channel " + i + " Selector Enable"
                                 offset = i/2,
                                 bitSize = 1,
                                 bitOffset = (i%2)*4
                                 base = 'bool'
                                 mode = 'RW'))
            self.add(pr.Variable(name = "Ch" + i + "_sm"
                                 description = "Channel " + i + " Mask"
                                 offset = i/2,
                                 bitSize = 1,
                                 bitOffset = (i%2)*4+1
                                 base = 'bool'
                                 mode = 'RW'))
            self.add(pr.Variable(name = "Ch" + i + "_st"
                                 description = "Enable Test on channel " + i
                                 offset = i/2,
                                 bitSize = 1,
                                 bitOffset = (i%2)*4+2
                                 base = 'bool'
                                 mode = 'RW'))

        self.add(pr.Variable(name = "pbitt",   offset = 0x30, bitOffset = 0 , bitSize = 1,  description = "Test Pulse Polarity (0=pos, 1=neg)"))
        self.add(pr.Variable(name = "cs",      offset = 0x30, bitOffset = 1 , bitSize = 1,  description = "Disable Outputs"))
        self.add(pr.Variable(name = "atest",   offset = 0x30, bitOffset = 2 , bitSize = 1,  description = "Automatic Test Mode Enable"))
        self.add(pr.Variable(name = "vdacm",   offset = 0x30, bitOffset = 3 , bitSize = 1,  description = "Enabled APS monitor AO2"))
        self.add(pr.Variable(name = "hrtest",  offset = 0x30, bitOffset = 4 , bitSize = 1,  description = "High Resolution Test Mode"))
        self.add(pr.Variable(name = "sbm",     offset = 0x30, bitOffset = 5 , bitSize = 1,  description = "Monitor Output Buffer Enable"))
        self.add(pr.Variable(name = "sb",      offset = 0x30, bitOffset = 6 , bitSize = 1,  description = "Output Buffers Enable"))
        self.add(pr.Variable(name = "test",    offset = 0x30, bitOffset = 7 , bitSize = 1,  description = "Test Pulser Enable"))
        self.add(pr.Variable(name = "saux",    offset = 0x30, bitOffset = 8 , bitSize = 1,  description = "Enable Auxilary Output"))
        self.add(pr.Variable(name = "slrb",    offset = 0x30, bitOffset = 9 , bitSize = 2,  description = "Reset Time"))
        self.add(pr.Variable(name = "claen",   offset = 0x30, bitOffset = 11, bitSize = 1,  description = "Manual Pulser DAC"))
        self.add(pr.Variable(name = "pb",      offset = 0x30, bitOffset = 12, bitSize = 10, description = "Pump timout disable"))
        self.add(pr.Variable(name = "tr",      offset = 0x30, bitOffset = 22, bitSize = 3,  description = "Baseline Adjust"))
        self.add(pr.Variable(name = "sse",     offset = 0x30, bitOffset = 25, bitSize = 1,  description = "Disable Multiple Firings Inhibit (1-disabled)"))
        self.add(pr.Variable(name = "disen",   offset = 0x30, bitOffset = 26, bitSize = 1,  description = "Disable Pump"))
        self.add(pr.Variable(name = "pa",      offset = 0x34, bitOffset = 0 , bitSize = 10, description =  "Threshold DAC"))
        self.add(pr.Variable(name = "esm",     offset = 0x34, bitOffset = 10, bitSize = 1,  description = "Enable DAC Monitor"))
        self.add(pr.Variable(name = "t",       offset = 0x34, bitOffset = 11, bitSize = 3,  description = "Filter time to flat top"))
        self.add(pr.Variable(name = "dd",      offset = 0x34, bitOffset = 14, bitSize = 1,  description =  "DAC Monitor Select (0-thr, 1-pulser)"))
        self.add(pr.Variable(name = "sabtest", offset = 0x34, bitOffset = 15, bitSize = 1,  description = "Select CDS test"))
        self.add(pr.Variable(name = "clab",    offset = 0x34, bitOffset = 16, bitSize = 3,  description = "Pump Timeout"))
        self.add(pr.Variable(name = "tres",    offset = 0x34, bitOffset = 19, bitSize = 3,  description = "Reset Tweak OP"))
           
 
        # Now define the readback registers
              for i in xrange(95):
            self.add(pr.Variable(name= "READ_Ch" + i + "_somi"
                                 description = "Channel " + i + " Selector Enable"
                                 offset = (i/2) + 0x40,
                                 bitSize = 1,
                                 bitOffset = (i%2)*4
                                 base = 'bool'
                                 mode = 'RO'))
            self.add(pr.Variable(name = "READ_Ch" + i + "_sm"
                                 description = "Channel " + i + " Mask"
                                 offset = (i/2) + 0x40
                                 bitSize = 1,
                                 bitOffset = (i%2)*4+1
                                 base = 'bool'
                                 mode = 'RO'))
            self.add(pr.Variable(name = "READ_Ch" + i + "_st"
                                 description = "Enable Test on channel " + i
                                 offset = (i/2) + 0x40
                                 bitSize = 1,
                                 bitOffset = (i%2)*4+2
                                 base = 'bool'
                                 mode = 'RO'))

        self.add(pr.Variable(name = "READ_pbitt",   offset = 0x70, bitOffset = 0 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Test Pulse Polarity (0=pos, 1=neg)"))
        self.add(pr.Variable(name = "READ_cs",      offset = 0x70, bitOffset = 1 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Disable Outputs"))
        self.add(pr.Variable(name = "READ_atest",   offset = 0x70, bitOffset = 2 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Automatic Test Mode Enable"))
        self.add(pr.Variable(name = "READ_vdacm",   offset = 0x70, bitOffset = 3 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Enabled APS monitor AO2"))
        self.add(pr.Variable(name = "READ_hrtest",  offset = 0x70, bitOffset = 4 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - High Resolution Test Mode"))
        self.add(pr.Variable(name = "READ_sbm",     offset = 0x70, bitOffset = 5 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Monitor Output Buffer Enable"))
        self.add(pr.Variable(name = "READ_sb",      offset = 0x70, bitOffset = 6 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Output Buffers Enable"))
        self.add(pr.Variable(name = "READ_test",    offset = 0x70, bitOffset = 7 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Test Pulser Enable"))
        self.add(pr.Variable(name = "READ_saux",    offset = 0x70, bitOffset = 8 , bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Enable Auxilary Output"))
        self.add(pr.Variable(name = "READ_slrb",    offset = 0x70, bitOffset = 9 , bitSize = 2,  hidden = True, mode = 'RO', description = "READBACK - Reset Time"))
        self.add(pr.Variable(name = "READ_claen",   offset = 0x70, bitOffset = 11, bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Manual Pulser DAC"))
        self.add(pr.Variable(name = "READ_pb",      offset = 0x70, bitOffset = 12, bitSize = 10, hidden = True, mode = 'RO', description = "READBACK - Pump timout disable"))
        self.add(pr.Variable(name = "READ_tr",      offset = 0x70, bitOffset = 22, bitSize = 3,  hidden = True, mode = 'RO', description = "READBACK - Baseline Adjust"))
        self.add(pr.Variable(name = "READ_sse",     offset = 0x70, bitOffset = 25, bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Disable Multiple Firings Inhibit (1-disabled)"))
        self.add(pr.Variable(name = "READ_disen",   offset = 0x70, bitOffset = 26, bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Disable Pump"))
        self.add(pr.Variable(name = "READ_pa",      offset = 0x74, bitOffset = 0 , bitSize = 10, hidden = True, mode = 'RO', description = "READBACK - Threshold DAC"))
        self.add(pr.Variable(name = "READ_esm",     offset = 0x74, bitOffset = 10, bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Enable DAC Monitor"))
        self.add(pr.Variable(name = "READ_t",       offset = 0x74, bitOffset = 11, bitSize = 3,  hidden = True, mode = 'RO', description = "READBACK - Filter time to flat top"))
        self.add(pr.Variable(name = "READ_dd",      offset = 0x74, bitOffset = 14, bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - DAC Monitor Select (0-thr, 1-pulser)"))
        self.add(pr.Variable(name = "READ_sabtest", offset = 0x74, bitOffset = 15, bitSize = 1,  hidden = True, mode = 'RO', description = "READBACK - Select CDS test"))
        self.add(pr.Variable(name = "READ_clab",    offset = 0x74, bitOffset = 16, bitSize = 3,  hidden = True, mode = 'RO', description = "READBACK - Pump Timeout"))
        self.add(pr.Variable(name = "READ_tres",    offset = 0x74, bitOffset = 19, bitSize = 3,  hidden = True, mode = 'RO', description = "READBACK - Reset Tweak OP"))
        
        self.add(pr.Command(name = "WriteAsic", description = "Write the current configuration registers into the ASIC",
                            offset = 0x80, bitSize = 1, bitOffset = 0))
        self.add(pr.Command(name = "ReadAsic", description = "Read the current configuration registers from the ASIC",
                            offset = 0x80, bitSize = 1, bitOffset = 0, hidden = True))

        def _read(self):
            # First send the ReadAsic command, then procede with normal read
            self.ReadAsic()
            super(pr.Device, self)._read()

        def _verify(self):
            # First verify the shadow registers in the FPGA
            super(pr.Device, self)._verify()

            # Then compare the READ_* variables against the normal ones
            vars = self.getNodes(pr.Variable)
            for key,var in vars:
                if "READ_"+key in vars:
                    if vars[key].get() != vars["READ_"+key].get():
                        raise MemoryException("ELine100Config::_verify()")
