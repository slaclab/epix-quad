from distutils.core import setup, Extension

module1 = Extension('pythonDaq',
                    include_dirs = ['../generic/','/usr/include/libxml2'],
                    libraries = ['xml2','z','m','rt'],
                    sources = ['pythonDaq.cpp','../generic/XmlVariables.cpp'])

setup (name = 'PackageName',
       version = '1.0',
       description = 'This is a demo package',
       ext_modules = [module1])
