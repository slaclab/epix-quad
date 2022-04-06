from setuptools import setup, find_packages

# use softlinks to make the various "board-support-package" submodules
# look like subpackages.  Then __init__.py will modify
# sys.path so that the correct "local" versions of surf etc. are
# picked up.  A better approach would be using relative imports
# in the submodules, but that's more work.  -cpo

setup(
    name = 'epixQuad',
    description = 'LCLS II EPIX Quad package',
    packages = [
        'epixQuad',
        'epixQuad.surf',
        'epixQuad.surf.misc',
        'epixQuad.surf.dsp',
        'epixQuad.surf.dsp.fixed',
        'epixQuad.surf.xilinx',
        'epixQuad.surf.protocols',
        'epixQuad.surf.protocols.ssi',
        'epixQuad.surf.protocols.pgp',
        'epixQuad.surf.protocols.batcher',
        'epixQuad.surf.protocols.ssp',
        'epixQuad.surf.protocols.rssi',
        'epixQuad.surf.protocols.i2c',
        'epixQuad.surf.protocols.jesd204b',
        'epixQuad.surf.protocols.clink',
        'epixQuad.surf.ethernet.udp',
        'epixQuad.surf.ethernet.ten_gig',
        'epixQuad.surf.ethernet.mac',
        'epixQuad.surf.ethernet.gige',
        'epixQuad.surf.ethernet',
        'epixQuad.surf.ethernet.xaui',
        'epixQuad.surf.devices.analog_devices',
        'epixQuad.surf.devices.intel',
        'epixQuad.surf.devices.nxp',
        'epixQuad.surf.devices.cypress',
        'epixQuad.surf.devices.ti',
        'epixQuad.surf.devices',
        'epixQuad.surf.devices.silabs',
        'epixQuad.surf.devices.transceivers',
        'epixQuad.surf.devices.microchip',
        'epixQuad.surf.devices.micron',
        'epixQuad.surf.devices.linear',
        'epixQuad.surf.axi',
        'epixQuad.ePixQuad',
        'epixQuad.ePixViewer',
        'epixQuad.ePixAsics',
        'epixQuad.ePixFpga',
    ],
    package_dir = {
        'epixQuad': 'firmware/python/epix_quad',
        'epixQuad.surf': 'firmware/submodules/surf/python/surf',
        'epixQuad.ePixAsics': 'software/python/ePixAsics',
        'epixQuad.ePixFpga': 'software/python/ePixFpga',
        'epixQuad.ePixQuad': 'software/python/ePixQuad',
        'epixQuad.ePixViewer': 'software/python/ePixViewer',
    }
)
