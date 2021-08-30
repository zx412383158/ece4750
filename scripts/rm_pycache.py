#! /usr/bin/env python
#========================================================================
# rm_pycache.py
#========================================================================
# Utility script to remove all .pyc files and __pycache__ directories.
# remove .pytest_cache directories ans .ipynb_checkpoints directories.

import os

def main():

  for root, dirs, files in os.walk('.'):
    pycaches = [os.path.join(root, x) for x in dirs if x == '__pycache__']
    for i in pycaches:
      print( 'rm: {}'.format(i) )
      os.system( 'rm -r {}'.format(i) )

  for root, dirs, files in os.walk('.'):
    pycs = [os.path.join(root, x) for x in files if x.endswith('.pyc')]
    for i in pycs:
      print( 'rm: {}'.format(i) )
      os.remove( i )

  for root, dirs, files in os.walk('.'):
    pytest_caches = [os.path.join(root, x) for x in dirs if x == '.pytest_cache']
    for i in pytest_caches:
      print( 'rm: {}'.format(i) )
      os.system( 'rm -r {}'.format(i) )
  
  for root, dirs, files in os.walk('.'):
    ipynb = [os.path.join(root, x) for x in dirs if x == '.ipynb_checkpoints']
    for i in ipynb:
      print( 'rm: {}'.format(i) )
      os.system( 'rm -r {}'.format(i) )

if __name__ == "__main__":
  main()
