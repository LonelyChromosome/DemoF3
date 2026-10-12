"""One-time consolidation, retaining every old branch tip as an archive tag."""
import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

LEGACY = 'feature/1.2-card-update'
PROBE = 'compat-probe/updater-20261012'
PREFIX = 'archive/2026-10-12/'
REPO = 'LonelyChromosome/DemoF3'


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def refs(kind):
    return {ref.removeprefix(f'refs/{kind}/'): sha
            for line in git('ls-remote', 'origin', f'refs/{kind}/*').splitlines()
            for sha, ref in [line.split()] if not ref.endswith('^{}')}


def raw(ref, name):
    url = f'https://raw.githubusercontent.com/{REPO}/{ref}/updates/{name}'
    last = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(url, timeout=20) as response:
                return response.read()
        except Exception as error:
            last = error
            if attempt < 5:
                time.sleep(5)
    raise last


def main():
    phase = sys.argv[1]
    snapshot = json.loads(Path('tool/branch_consolidation_snapshot.json').read_text())
    heads = refs('heads')
    tags = refs('tags')
    assert 'main' in heads
    assert set(heads) - {'main'} <= set(snapshot), 'Unexpected branch; stop instead of deleting new work'
    for name, sha in heads.items():
        if name != 'main':
            assert sha == snapshot[name] or (name == LEGACY and sha == heads['main']), f'Branch changed: {name}'
    if phase == 'prepare':
        wanted = {PREFIX + name: sha for name, sha in snapshot.items()}
        wanted[LEGACY] = heads[LEGACY]
        wanted[PROBE] = heads[LEGACY]
        git('fetch', '--no-tags', 'origin', '+refs/heads/*:refs/remotes/origin/*')
        pushes = []
        for name, sha in wanted.items():
            if name in tags:
                assert tags[name] == sha, f'Tag already differs: {name}'
                continue
            pushes.append(f'{sha}:refs/tags/{name}')
        if pushes:
            git('push', '--atomic', 'origin', *pushes)
        # The probe has no branch with the same name: prove raw URLs resolve tags.
        for name in ['latest.json', 'latest.json.sig']:
            assert raw(PROBE, name) == raw(LEGACY, name), f'Raw tag lookup failed: {name}'
        print('All branch tips archived; tag-based raw feed matches the existing APK URL.')
        return
    assert phase == 'cleanup'
    main_sha = heads['main']
    assert tags.get(LEGACY) == main_sha, 'Compatibility tag must track the published main feed'
    git('fetch', 'origin', main_sha)
    manifest = json.loads(git('show', f'{main_sha}:updates/latest.json'))
    assert manifest['versionCode'] >= 51, 'Publish main-based migration APK first'
    # Require a successful signed release run on main before removing branches.
    runs = json.loads(subprocess.check_output([
        'gh', 'api', f'repos/{REPO}/actions/workflows/build-apk.yml/runs?branch=main&status=success&per_page=20'
    ], text=True))['workflow_runs']
    tag = manifest['apkUrl'].split('/download/')[1].split('/')[0]
    released_sha = git('ls-remote', 'origin', f'refs/tags/{tag}').split()[0]
    assert any(run['head_sha'] == released_sha for run in runs), 'No successful release run on main'
    for name in ['latest.json', 'latest.json.sig']:
        expected = subprocess.check_output(['git', 'show', f'{main_sha}:updates/{name}'])
        assert raw('main', name) == expected
        assert raw(LEGACY, name) == expected
    pushes = []
    leases = []
    for name, sha in heads.items():
        if name == 'main':
            continue
        assert tags.get(PREFIX + name) == snapshot[name], f'Archive missing: {name}'
        pushes.append(f':refs/heads/{name}')
        leases.append(f'--force-with-lease=refs/heads/{name}:{sha}')
    if pushes:
        git('push', '--atomic', *leases, 'origin', *pushes)
    # Validate the EXACT URL embedded in installed APKs after its branch is gone.
    assert refs('heads') == {'main': main_sha}
    for name in ['latest.json', 'latest.json.sig']:
        expected = subprocess.check_output(['git', 'show', f'{main_sha}:updates/{name}'])
        assert raw(LEGACY, name) == expected, f'Legacy APK feed broke after deletion: {name}'
    print('Only main remains. New and installed APKs read the same signed update feed.')


if __name__ == '__main__':
    main()
