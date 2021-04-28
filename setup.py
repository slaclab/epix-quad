from setuptools import setup, find_packages

# use softlinks to make the various "board-support-package" submodules
# look like subpackages.  Then __init__.py will modify
# sys.path so that the correct "local" versions of surf etc. are
# picked up.  A better approach would be using relative imports
# in the submodules, but that's more work.  -cpo

setup(
    name = 'epix',
    description = 'LCLS II Epix package',
    packages = [
        'epix',
        'epix.surf',
        'epix.surf.misc',
        'epix.surf.dsp',
        'epix.surf.dsp.fixed',
        'epix.surf.xilinx',
        'epix.surf.protocols',
        'epix.surf.protocols.ssi',
        'epix.surf.protocols.pgp',
        'epix.surf.protocols.batcher',
        'epix.surf.protocols.ssp',
        'epix.surf.protocols.rssi',
        'epix.surf.protocols.i2c',
        'epix.surf.protocols.jesd204b',
        'epix.surf.protocols.clink',
        'epix.surf.ethernet.udp',
        'epix.surf.ethernet.ten_gig',
        'epix.surf.ethernet.mac',
        'epix.surf.ethernet.gige',
        'epix.surf.ethernet',
        'epix.surf.ethernet.xaui',
        'epix.surf.devices.analog_devices',
        'epix.surf.devices.intel',
        'epix.surf.devices.nxp',
        'epix.surf.devices.cypress',
        'epix.surf.devices.ti',
        'epix.surf.devices',
        'epix.surf.devices.silabs',
        'epix.surf.devices.transceivers',
        'epix.surf.devices.microchip',
        'epix.surf.devices.micron',
        'epix.surf.devices.linear',
        'epix.surf.axi',
        'epix.ePixQuad',
        'epix.ePixViewer',
        'epix.ePixAsics',
        'epix.ePixFpga',
    ],
    package_dir = {
        'epix': 'firmware/python/epix',
        'epix.surf': 'firmware/submodules/surf/python/surf',
        'epix.ePixAsics': 'software/Epix/python/ePixAsics',
        'epix.ePixFpga': 'software/Epix/python/ePixFpga',
        'epix.ePixQuad': 'software/Epix/python/ePixQuad',
        'epix.ePixViewer': 'software/Epix/python/ePixViewer',
    }
)
