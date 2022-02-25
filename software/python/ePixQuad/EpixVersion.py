#!/usr/bin/env python
# -----------------------------------------------------------------------------
# Title      : PyRogue AXI Version Module
# -----------------------------------------------------------------------------
# File       :
# Author     : Maciej Kwiatkowski
# Created    : 2016-09-29
# Last update: 2017-01-31
# -----------------------------------------------------------------------------
# Description:
# -----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# -----------------------------------------------------------------------------
import pyrogue as pr
import collections
import surf.axi as axi
from enum import Enum


class EpixVersion(axi.AxiVersion):
    def __init__(self, **kwargs):
        """Create EpixVersion"""
        super().__init__(description='Epix Specific AxiVersion', numUserConstants=3, **kwargs)

        self.add(pr.LinkVariable(
            name='BoardVersion',
            mode='RO',
            dependencies=[self.UserConstants[0], self.UserConstants[1]],
            linkedGet=lambda: str('PC-%3.3d-%3.3d-%2.2d-C%2.2d' % (
                (self.UserConstants[0].value() >> 17) & 0x3FF,
                (self.UserConstants[0].value() >> 7) & 0x3FF,
                self.UserConstants[0].value() & 0x7F,
                self.UserConstants[1].value() & 0x7F))
        ))

        self.add(pr.LinkVariable(
            name='AsicName',
            mode='RO',
            dependencies=[self.UserConstants[2]],
            linkedGet=lambda: str(EpixAsicNames(self.UserConstants[2].value()).name)
        ))


class EpixAsicNames(Enum):
    NONE = 0
    EPIX100A = 1
    EPIX10KA = 2
    EPIX250S = 3
    EPIX10KT = 4
    EPIX10KINV = 5
    EPIX10KHIZ = 6

    @classmethod
    def _missing_(cls, name):
        return cls._member_map_['NONE']
