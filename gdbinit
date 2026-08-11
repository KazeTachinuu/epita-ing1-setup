# EPITA PIE gdbinit - quality of life, no magic
set history save on
set history filename ~/.gdb_history
set print pretty on
set pagination off
set confirm off

# optional GEF (see README extras): inert unless ~/afs/.confs/gef.py exists
python
import os
_gef = os.path.expanduser('~/afs/.confs/gef.py')
if os.path.exists(_gef):
    gdb.execute(f'source {_gef}')
end
