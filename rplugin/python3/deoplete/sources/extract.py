from .base import Base
from deoplete.util import get_simple_buffer_config, error

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'extract'
        self.kind = 'keyword'
        self.mark = '[extract]'
        self.rank = 4

    def gather_candidates(self, context):
        win = self.vim.current.window
        lines = [str(i) for i in self.vim.current.buffer[:]]

        ls = self.vim.eval('extract#all()')
        return [{ 'word': x[0].strip() } for x in ls]