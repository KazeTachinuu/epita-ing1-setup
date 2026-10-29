# EPITA PIE gdbinit - quality of life, no magic
# gdb takes no trailing comments: each note sits above its line
# keep command history across sessions, in one fixed file
# (the default is ./.gdb_history, one per directory)
set history save on
set history filename ~/.gdb_history
# structs print one indented field per line
set print pretty on
# never pause output at --Type <RET>--
set pagination off
# no y/n prompts (quit while running, bare delete)
set confirm off

# optional GEF (see README extras): inert unless installed by setup.sh
python
import os
_afs = os.environ.get('AFS_DIR', '~/afs')
# KIT_DIR (the kit home off the PIE) is unset on the PIE: skipped there
_dirs = (os.environ.get('KIT_DIR'), '~/.pie', _afs + '/.confs')
for _d in filter(None, _dirs):
    _gef = os.path.expanduser(_d + '/gef.py')
    if os.path.exists(_gef):
        gdb.execute(f'source {_gef}')
        break
end
