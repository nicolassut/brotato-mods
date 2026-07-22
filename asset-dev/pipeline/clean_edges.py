#!/usr/bin/env python3
"""Despeckle (remove white border dots) any pngs in place, backing up first.
Usage: clean_edges.py <file.png> [...]"""
import sys, os, shutil
sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
from process_gen import despeckle
from PIL import Image
import numpy as np

BACKUP = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/_pre_despeckle_backup'

def main():
    os.makedirs(BACKUP, exist_ok=True)
    for path in sys.argv[1:]:
        if not os.path.exists(path):
            print(f'MISS {path}'); continue
        im = Image.open(path).convert('RGBA')
        out = despeckle(im)
        a = np.array(im).astype(int); b = np.array(out).astype(int)
        changed = int((np.abs(a - b).sum(2) > 0).sum())
        if changed == 0:
            print(f'clean  {os.path.basename(path)}'); continue
        # backup with a flat unique name; never clobber an existing (true-original) backup
        tag = path.replace('/', '__')[-120:]
        if not os.path.exists(f'{BACKUP}/{tag}'):
            shutil.copy2(path, f'{BACKUP}/{tag}')
        out.save(path)
        print(f'FIXED  {os.path.basename(path):32s} changed={changed}px')

if __name__ == '__main__':
    main()
