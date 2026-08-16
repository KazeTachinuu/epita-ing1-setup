# EPITA PIE gdbinit - quality of life, no magic
# gdb takes no trailing comments: each note sits above its line
# keep command history across sessions, in a fixed file (default: ./.gdb_history)
set history save on
set history filename ~/.gdb_history
# structs print one indented field per line
set print pretty on
# never pause output at --Type <RET>--
set pagination off
# no y/n prompts (quit while running, bare delete)
set confirm off

# optional GEF (see README extras): inert unless ~/afs/.confs/gef.py exists
python
import os
_gef = os.path.expanduser('~/afs/.confs/gef.py')
if os.path.exists(_gef):
    gdb.execute(f'source {_gef}')
end
