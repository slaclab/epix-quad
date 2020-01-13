-------------------------------------------------------------------------------
-- File       : ELine100Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

package ELine100Pkg is

   constant ELINE_100_CFG_SHIFT_SIZE_C : integer := 342;

   type ELine100ChCfgType is record
      somi : sl;                        -- Channel Selector Enable
      sm   : sl;                        -- Channel Mask
      st   : sl;                        -- Enable Test on Channel
   end record ELine100ChCfgType;

   constant E_LINE_100_CH_CFG_INIT_C : ELine100ChCfgType := (
      somi => '0',
      sm   => '0',
      st   => '0');

   type ELine100ChCfgArray is array (natural range <>) of ELine100ChCfgType;

   type ELine100CfgType is record
      tres    : slv(2 downto 0);        -- Reset Tweak OP
      clab    : slv(2 downto 0);        -- Pump Timeout
      sabtest : sl;                     -- Select CDS test
      dd      : sl;                     -- DAC Monitor Select (0-thr, 1-pulser)
      t       : slv(2 downto 0);        -- Filter time to flat top
      esm     : sl;                     -- Enable DAC Monitor
      pa      : slv(9 downto 0);        -- Threshold DAC
      disen   : sl;                     -- Disable Pump
      sse     : sl;                     -- Disable Multiple Firings Inhibit (1-disabled)
      tr      : slv(2 downto 0);        -- Baseline Adjust
      pb      : slv(9 downto 0);        -- Manual Pulser DAC
      claen   : sl;                     -- Pump timout disable
      slrb    : slv(1 downto 0);        -- Reset Time
      saux    : sl;                     -- Enable Auxilary Output
      test    : sl;                     -- Test Pulser Enable
      sb      : sl;                     -- Output Buffers Enable
      sbm     : sl;                     -- Monitor Output Buffer Enable
      hrtest  : sl;                     -- High Resolution Test Mode
      vdacm   : sl;                     -- Enabled APS monitor AO2
      atest   : sl;                     -- Automatic Test Mode Enable
      cs      : sl;                     -- Disable Outputs
      pbitt   : sl;                     -- Test Pulse Polarity (0=pos, 1=neg)
      somi    : slv(95 downto 0);
      sm      : slv(95 downto 0);
      st      : slv(95 downto 0);
   end record ELine100CfgType;

   constant E_LINE_100_CFG_INIT_C : ELine100CfgType := (
      tres    => (others => '0'),
      clab    => (others => '0'),
      sabtest => '0',
      dd      => '0',
      t       => (others => '0'),
      esm     => '0',
      pa      => (others => '0'),
      disen   => '0',
      sse     => '0',
      tr      => (others => '0'),
      pb      => (others => '0'),
      claen   => '0',
      slrb    => (others => '0'),
      saux    => '0',
      test    => '0',
      sb      => '0',
      sbm     => '0',
      hrtest  => '0',
      vdacm   => '0',
      atest   => '0',
      cs      => '0',
      pbitt   => '0',
      somi    => (others => '0'),
      sm      => (others => '0'),
      st      => (others => '0'));

   function toSlv (cfg : ELine100CfgType) return slv;

   function toELine100Cfg (vec : slv(341 downto 0)) return ELine100CfgType;

end package ELine100Pkg;

package body ELine100Pkg is

   function toSlv (cfg : ELine100CfgType) return slv is
      variable ret : slv(341 downto 0);
      variable i   : integer;
   begin
      ret := (others => '0');
      i   := 0;

      for j in 95 downto 0 loop
         assignSlv(i, ret, cfg.st(j));
         assignSlv(i, ret, cfg.sm(j));
         assignSlv(i, ret, cfg.somi(j));
      end loop;

      assignSlv(i, ret, '0');           -- 288 null
      assignSlv(i, ret, cfg.pbitt);     -- 289
      assignSlv(i, ret, '0');           -- 290 null
      assignSlv(i, ret, cfg.cs);        -- 291
      assignSlv(i, ret, cfg.atest);     -- 292
      assignSlv(i, ret, cfg.vdacm);     -- 293
      assignSlv(i, ret, '0');           -- 294 null
      assignSlv(i, ret, cfg.hrtest);    -- 295
      assignSlv(i, ret, cfg.sbm);       -- 296
      assignSlv(i, ret, cfg.sb);        -- 297
      assignSlv(i, ret, cfg.test);      -- 298
      assignSlv(i, ret, cfg.saux);      -- 299
      assignSlv(i, ret, cfg.pb(9));     -- 300
      assignSlv(i, ret, cfg.slrb(1));   -- 301
      assignSlv(i, ret, cfg.pb(8));     -- 302     
      assignSlv(i, ret, cfg.pb(7));     -- 303
      assignSlv(i, ret, cfg.slrb(0));   -- 304
      assignSlv(i, ret, cfg.pb(6));     -- 305
      assignSlv(i, ret, cfg.pb(5));     -- 306       
      assignSlv(i, ret, cfg.claen);     -- 307
      assignSlv(i, ret, cfg.pb(4));     -- 308
      assignSlv(i, ret, cfg.pb(3));     -- 309
      assignSlv(i, ret, cfg.tr(2));     -- 310       
      assignSlv(i, ret, cfg.pb(2));     -- 311
      assignSlv(i, ret, cfg.pb(1));     -- 312
      assignSlv(i, ret, cfg.tr(1));     -- 313
      assignSlv(i, ret, cfg.pb(0));     -- 314       
      assignSlv(i, ret, cfg.pa(9));     -- 315
      assignSlv(i, ret, cfg.tr(0));     -- 316
      assignSlv(i, ret, cfg.pa(8));     -- 317
      assignSlv(i, ret, cfg.pa(7));     -- 318      
      assignSlv(i, ret, cfg.sse);       -- 319
      assignSlv(i, ret, cfg.pa(6));     -- 320        
      assignSlv(i, ret, cfg.pa(5));     -- 321
      assignSlv(i, ret, cfg.disen);     -- 322       
      assignSlv(i, ret, cfg.pa(4));     -- 323
      assignSlv(i, ret, cfg.pa(3));     -- 324
      assignSlv(i, ret, cfg.t(2));      -- 325
      assignSlv(i, ret, cfg.pa(2));     -- 326
      assignSlv(i, ret, cfg.pa(1));     -- 327
      assignSlv(i, ret, cfg.t(1));      -- 328
      assignSlv(i, ret, cfg.pa(0));     -- 329
      assignSlv(i, ret, cfg.esm);       -- 330
      assignSlv(i, ret, cfg.t(0));      -- 331
      assignSlv(i, ret, cfg.dd);        -- 332
      assignSlv(i, ret, cfg.sabtest);   -- 333
      assignSlv(i, ret, cfg.tres(2));   -- 334
      assignSlv(i, ret, '0');           -- 335 null
      assignSlv(i, ret, cfg.clab(2));   -- 336
      assignSlv(i, ret, cfg.tres(1));   -- 337
      assignSlv(i, ret, cfg.clab(1));   -- 338
      assignSlv(i, ret, cfg.clab(0));   -- 339
      assignSlv(i, ret, cfg.tres(0));   -- 340
      assignSlv(i, ret, '0');           -- 341 null
      return ret;
   end function toSlv;

   function toELine100Cfg (vec : slv(341 downto 0)) return ELine100CfgType is
      variable cfg : ELine100CfgType;
      variable i   : integer;
   begin
      cfg := E_LINE_100_CFG_INIT_C;
      i   := 0;

      for j in 95 downto 0 loop
         assignRecord(i, vec, cfg.st(j));
         assignRecord(i, vec, cfg.sm(j));
         assignRecord(i, vec, cfg.somi(j));
      end loop;

      i := i+1;                           -- 288 null
      assignRecord(i, vec, cfg.pbitt);    -- 289
      i := i+1;                           -- 290 null
      assignRecord(i, vec, cfg.cs);       -- 291
      assignRecord(i, vec, cfg.atest);    -- 292
      assignRecord(i, vec, cfg.vdacm);    -- 293
      i := i+1;                           -- 294 null
      assignRecord(i, vec, cfg.hrtest);   -- 295
      assignRecord(i, vec, cfg.sbm);      -- 296
      assignRecord(i, vec, cfg.sb);       -- 297
      assignRecord(i, vec, cfg.test);     -- 298
      assignRecord(i, vec, cfg.saux);     -- 299
      assignRecord(i, vec, cfg.pb(9));    -- 300
      assignRecord(i, vec, cfg.slrb(1));  -- 301
      assignRecord(i, vec, cfg.pb(8));    -- 302     
      assignRecord(i, vec, cfg.pb(7));    -- 303
      assignRecord(i, vec, cfg.slrb(0));  -- 304
      assignRecord(i, vec, cfg.pb(6));    -- 305
      assignRecord(i, vec, cfg.pb(5));    -- 306       
      assignRecord(i, vec, cfg.claen);    -- 307
      assignRecord(i, vec, cfg.pb(4));    -- 308
      assignRecord(i, vec, cfg.pb(3));    -- 309
      assignRecord(i, vec, cfg.tr(2));    -- 310       
      assignRecord(i, vec, cfg.pb(2));    -- 311
      assignRecord(i, vec, cfg.pb(1));    -- 312
      assignRecord(i, vec, cfg.tr(1));    -- 313
      assignRecord(i, vec, cfg.pb(0));    -- 314       
      assignRecord(i, vec, cfg.pa(9));    -- 315
      assignRecord(i, vec, cfg.tr(0));    -- 316
      assignRecord(i, vec, cfg.pa(8));    -- 317
      assignRecord(i, vec, cfg.pa(7));    -- 318      
      assignRecord(i, vec, cfg.sse);      -- 319
      assignRecord(i, vec, cfg.pa(6));    -- 320        
      assignRecord(i, vec, cfg.pa(5));    -- 321
      assignRecord(i, vec, cfg.disen);    -- 322       
      assignRecord(i, vec, cfg.pa(4));    -- 323
      assignRecord(i, vec, cfg.pa(3));    -- 324
      assignRecord(i, vec, cfg.t(2));     -- 325
      assignRecord(i, vec, cfg.pa(2));    -- 326
      assignRecord(i, vec, cfg.pa(1));    -- 327
      assignRecord(i, vec, cfg.t(1));     -- 328
      assignRecord(i, vec, cfg.pa(0));    -- 329
      assignRecord(i, vec, cfg.esm);      -- 330
      assignRecord(i, vec, cfg.t(0));     -- 331
      assignRecord(i, vec, cfg.dd);       -- 332
      assignRecord(i, vec, cfg.sabtest);  -- 333
      assignRecord(i, vec, cfg.tres(2));  -- 334
      i := i+1;                           -- 335 null
      assignRecord(i, vec, cfg.clab(2));  -- 336
      assignRecord(i, vec, cfg.tres(1));  -- 337
      assignRecord(i, vec, cfg.clab(1));  -- 338
      assignRecord(i, vec, cfg.clab(0));  -- 339
      assignRecord(i, vec, cfg.tres(0));  -- 340
      i := i+1;                           -- 341 null

      return cfg;
   end function toELine100Cfg;

end package body ELine100Pkg;
