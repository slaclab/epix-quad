from setuptools import setup, find_packages

# use softlinks to make the various "board-support-package" submodules
# look like subpackages.  Then __init__.py will modify
# sys.path so that the correct "local" versions of surf etc. are
# picked up.  A better approach would be using relative imports
# in the submodules, but that's more work.  -cpo

subpackages = ['firmware/submodules/surf/python/surf', 'software/Epix/python/ePixAsics', 'software/Epix/python/ePixFpga', 'software/Epix/python/ePixQuad','software/Epix/python/ePixViewer']

import os
print(os.path.dirname(os.path.realpath(__file__)))

for pkgpath in subpackages:
    pkgname = pkgpath.split('/')[-1]
    linkname = os.path.join('epix_l2sidaq',pkgname)
    if os.path.islink(linkname): os.remove(linkname)
    os.symlink(os.path.join('../../../',pkgpath),linkname)

setup(
    name = 'epix-l2sidaq',
    description = 'LCLS II Epix 2lsi package',
    packages = find_packages(),
)
