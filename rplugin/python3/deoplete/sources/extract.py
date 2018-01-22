from .base import Base
from deoplete.util import get_simple_buffer_config, error

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'extract'
        self.kind = 'keyword'
        self.mark = '[extract]'
        self.rank = 4
        self.doit = self.vim.eval("g:extract_loadDeoplete")

    def gather_candidates(self, context):
        if self.doit:
            ls = self.vim.eval('extract#all()')
            return [{ 'word': x[0].strip() } for x in ls]
        else:
            return []
