from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
parts = sorted((root/'media/kda').glob('firestarter.part*'))
target = root/'assets/kda/firestarter.mp4'
expected = '2d520a097dcbb7dfff112f87b9970e50d5841fe56b913c2010a2709ac49e303d'
if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected:
    print('Approved 207s MV already verified')
else:
    assert len(parts)==3, 'Missing supplied FIRESTARTER video parts'
    with target.open('wb') as f:
        for p in parts:
            f.write(p.read_bytes())
    assert hashlib.sha256(target.read_bytes()).hexdigest()==expected, 'FIRESTARTER media integrity failure'
    print('Approved 207s 1440x2560 MV reassembled byte-for-byte')
